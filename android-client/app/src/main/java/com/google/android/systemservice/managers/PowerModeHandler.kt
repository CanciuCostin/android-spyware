package com.google.android.systemservice.managers

import android.content.Context
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.BatteryManager
import android.os.Build
import android.os.PowerManager
import android.util.Log

/**
 * Handles power mode detection, battery state, and network type queries.
 */
class PowerModeHandler(private val context: Context) {

    companion object {
        private const val TAG = "PowerModeHandler"
    }

    private val batteryManager = context.getSystemService(Context.BATTERY_SERVICE) as? BatteryManager

    fun getBatteryLevel(): Int {
        return try {
            batteryManager?.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY) ?: 100
        } catch (e: Exception) {
            Log.e(TAG, "Failed to get battery level: ${e.message}")
            100
        }
    }

    fun isCharging(): Boolean {
        return try {
            batteryManager?.isCharging ?: false
        } catch (e: Exception) {
            Log.e(TAG, "Failed to check charging state: ${e.message}")
            false
        }
    }

    fun isLowPowerMode(): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                val powerManager = context.getSystemService(Context.POWER_SERVICE) as? PowerManager ?: return false
                powerManager.isPowerSaveMode
            } else {
                false
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to check power save mode: ${e.message}")
            false
        }
    }

    fun shouldThrottleOperations(): Boolean {
        return isLowPowerMode() || getBatteryLevel() < 15
    }

    fun getNetworkType(): SyncIntervalCalculator.NetworkType {
        return try {
            val connectivityManager = context.getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
                ?: return SyncIntervalCalculator.NetworkType.NONE
            val network = connectivityManager.activeNetwork ?: return SyncIntervalCalculator.NetworkType.NONE
            val capabilities = connectivityManager.getNetworkCapabilities(network)
                ?: return SyncIntervalCalculator.NetworkType.NONE

            when {
                capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) -> SyncIntervalCalculator.NetworkType.WIFI
                capabilities.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) -> SyncIntervalCalculator.NetworkType.CELLULAR
                else -> SyncIntervalCalculator.NetworkType.NONE
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to get network type: ${e.message}")
            SyncIntervalCalculator.NetworkType.NONE
        }
    }
}
