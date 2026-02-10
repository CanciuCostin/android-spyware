package com.google.android.systemservice.utils

import android.content.Context
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.Build

/**
 * Centralises device-info collection that was previously duplicated
 * in LocalDataSource and DeviceInfoHandlers.
 */
object DeviceInfoProvider {

    fun getManufacturer(): String = Build.MANUFACTURER
    fun getModel(): String = Build.MODEL
    fun getBrand(): String = Build.BRAND
    fun getDevice(): String = Build.DEVICE
    fun getProduct(): String = Build.PRODUCT
    fun getAndroidVersion(): String = Build.VERSION.RELEASE
    fun getSdkVersion(): Int = Build.VERSION.SDK_INT
    fun getFormattedModel(): String = "${Build.MANUFACTURER} ${Build.MODEL}"

    fun getBatteryLevel(context: Context): Int = BatteryHelper.getBatteryLevel(context)

    fun isCharging(context: Context): Boolean = BatteryHelper.isCharging(context)

    fun getNetworkType(context: Context): String {
        return try {
            val cm = context.getSystemService(Context.CONNECTIVITY_SERVICE)
                as ConnectivityManager
            val network = cm.activeNetwork
            val capabilities = cm.getNetworkCapabilities(network)

            when {
                capabilities?.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) == true -> "WiFi"
                capabilities?.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) == true -> "Cellular"
                capabilities?.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) == true -> "Ethernet"
                else -> "Unknown"
            }
        } catch (e: Exception) {
            "Unknown"
        }
    }

    fun isRooted(): Boolean {
        return try {
            val paths = arrayOf(
                "/system/xbin/su", "/system/bin/su",
                "/sbin/su", "/data/local/xbin/su"
            )
            paths.any { java.io.File(it).exists() }
        } catch (e: Exception) {
            false
        }
    }
}
