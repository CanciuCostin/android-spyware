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
        
        fun schedule(context: Context, intervalMinutes: Long = 15) {
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
            val batteryManager = context.getSystemService(Context.BATTERY_SERVICE) as? BatteryManager ?: return 15
            val batteryLevel = batteryManager.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
            val isCharging = batteryManager.isCharging
            
            return when {
                isCharging -> 5 // 5 minutes when charging
                batteryLevel > 50 -> 15 // 15 minutes when battery healthy
                batteryLevel > 20 -> 30 // 30 minutes when battery medium
                else -> 60 // 60 minutes when battery low
            }
        }
        
        fun cancel(context: Context) {
            WorkManager.getInstance(context).cancelUniqueWork(WORK_NAME)
            Timber.d("DataSyncWorker cancelled")
        }
    }

    private val dataSyncManager = DataSyncManager(applicationContext)

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
            
            // Sync offline queued data (legacy)
            if (dataSyncManager.hasQueuedData()) {
                val uploadedCount = dataSyncManager.flushAllSuspend()
                Timber.d("Uploaded $uploadedCount queued items")
            }
            
            // Persist queue to disk
            dataSyncManager.persistQueue()
            
            Timber.d("Sync completed successfully")
            Result.success()
        } catch (e: Exception) {
            Timber.e(e, "Sync failed")
            if (runAttemptCount < 3) {
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
            
            batteryLevel > 20 || isCharging
        } catch (e: Exception) {
            Timber.e(e, "Failed to check battery health")
            true // Assume healthy on error
        }
    }
}
