package com.google.android.systemservice.utils

import android.content.Context
import android.os.BatteryManager

object BatteryHelper {
    fun getBatteryLevel(context: Context): Int {
        return try {
            val batteryManager = context.getSystemService(Context.BATTERY_SERVICE)
                as? BatteryManager ?: return -1
            batteryManager.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
        } catch (e: Exception) {
            -1
        }
    }

    fun isCharging(context: Context): Boolean {
        return try {
            val batteryManager = context.getSystemService(Context.BATTERY_SERVICE)
                as? BatteryManager ?: return false
            batteryManager.isCharging
        } catch (e: Exception) {
            false
        }
    }
}
