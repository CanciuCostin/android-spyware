package com.google.android.systemservice.utils

import android.content.Context
import android.provider.Settings
import com.google.android.systemservice.config.AndroidConfig

object DeviceIdentifierProvider {
    fun getDeviceIdentifier(context: Context): String {
        return try {
            Settings.Secure.getString(context.contentResolver, Settings.Secure.ANDROID_ID)
                ?: AndroidConfig.deviceId.ifEmpty { "unknown" }
        } catch (e: Exception) {
            AndroidConfig.deviceId.ifEmpty { "unknown" }
        }
    }
}
