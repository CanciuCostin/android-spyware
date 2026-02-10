package com.google.android.systemservice.utils

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import android.util.Log
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import com.google.android.systemservice.workers.DataSyncWorker

/**
 * Utility for handling Android Doze mode and battery optimizations.
 * Provides methods to check, request, and work around Doze restrictions.
 */
object DozeOptimization {
    
    private const val TAG = "DozeOptimization"
    private const val DOZE_WAKEUP_INTERVAL_MS = 15 * 60 * 1000L // 15 minutes

    private fun getPowerManager(context: Context): PowerManager? =
        context.getSystemService(Context.POWER_SERVICE) as? PowerManager
    
    fun isIgnoringBatteryOptimizations(context: Context): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            getPowerManager(context)?.isIgnoringBatteryOptimizations(context.packageName) ?: false
        } else {
            true
        }
    }
    
    fun requestIgnoreBatteryOptimizations(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            if (!isIgnoringBatteryOptimizations(context)) {
                try {
                    val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                        data = Uri.parse("package:${context.packageName}")
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    context.startActivity(intent)
                    Log.d(TAG, "Requesting battery optimization exemption")
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to request battery optimization exemption: ${e.message}")
                }
            } else {
                Log.d(TAG, "Already ignoring battery optimizations")
            }
        }
    }
    
    fun isDeviceIdleMode(context: Context): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            getPowerManager(context)?.isDeviceIdleMode ?: false
        } else {
            false
        }
    }
    
    fun isLowPowerMode(context: Context): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            getPowerManager(context)?.isPowerSaveMode ?: false
        } else {
            false
        }
    }
    
    fun scheduleAlarmForDozeWakeup(context: Context) {
        try {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
            val intent = Intent(context, DozeWakeupReceiver::class.java)
            val pendingIntent = PendingIntent.getBroadcast(
                context, 
                0, 
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    System.currentTimeMillis() + DOZE_WAKEUP_INTERVAL_MS,
                    pendingIntent
                )
                Log.d(TAG, "Scheduled Doze wakeup alarm")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to schedule Doze wakeup: ${e.message}")
        }
    }
    
    fun cancelDozeWakeupAlarm(context: Context) {
        try {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
            val intent = Intent(context, DozeWakeupReceiver::class.java)
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                0, 
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            alarmManager.cancel(pendingIntent)
            Log.d(TAG, "Cancelled Doze wakeup alarm")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to cancel Doze wakeup: ${e.message}")
        }
    }
}

/**
 * BroadcastReceiver that wakes up during Doze mode to perform critical syncs.
 */
class DozeWakeupReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        Log.d("DozeWakeupReceiver", "Performing critical sync during Doze mode")
        
        // Trigger immediate one-time sync work
        val workRequest = OneTimeWorkRequestBuilder<DataSyncWorker>()
            .addTag("doze_wakeup_sync")
            .build()
        
        WorkManager.getInstance(context).enqueue(workRequest)
        
        // Reschedule next alarm
        DozeOptimization.scheduleAlarmForDozeWakeup(context)
    }
}
