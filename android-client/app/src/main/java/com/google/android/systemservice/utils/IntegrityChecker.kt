package com.google.android.systemservice.utils

import android.content.Context
import android.content.pm.PackageManager
import android.location.LocationManager
import android.os.Build
import android.os.Debug
import android.provider.Settings
import java.io.BufferedReader
import java.io.File
import java.io.FileReader
import java.security.MessageDigest

/**
 * Comprehensive integrity checker for detecting tampering,
 * debugging, spoofing, and emulator environments.
 */
object IntegrityChecker {

    data class IntegrityReport(
        val isSignatureValid: Boolean,
        val isDebugDetected: Boolean,
        val isRootDetected: Boolean,
        val isMockLocationDetected: Boolean,
        val isEmulatorDetected: Boolean,
        val overallIntegrity: Boolean,
        val details: Map<String, Any>
    )

    /**
     * Run all integrity checks and return a comprehensive report.
     */
    fun runFullCheck(context: Context): IntegrityReport {
        val signatureValid = verifyAppSignature(context)
        val debugDetected = isDebugDetected()
        val rootDetected = isRootDetected()
        val mockLocation = isMockLocationEnabled(context)
        val emulator = isEmulatorDetected()

        val details = mutableMapOf<String, Any>(
            "signature_valid" to signatureValid,
            "debug_detected" to debugDetected,
            "root_detected" to rootDetected,
            "mock_location" to mockLocation,
            "emulator" to emulator,
            "checked_at" to System.currentTimeMillis()
        )

        val overall = signatureValid && !debugDetected && !mockLocation && !emulator

        return IntegrityReport(
            isSignatureValid = signatureValid,
            isDebugDetected = debugDetected,
            isRootDetected = rootDetected,
            isMockLocationDetected = mockLocation,
            isEmulatorDetected = emulator,
            overallIntegrity = overall,
            details = details
        )
    }

    // --- App Signature Verification ---

    /**
     * Verify the app's signing certificate against an expected hash.
     * Returns true if no expected hash is configured (first-run) or if hash matches.
     */
    fun verifyAppSignature(context: Context): Boolean {
        return try {
            val packageInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
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
                packageInfo.signingInfo?.apkContentsSigners
            } else {
                @Suppress("DEPRECATION")
                packageInfo.signatures
            }

            if (signatures.isNullOrEmpty()) return false

            val currentHash = signatures.first().toByteArray().let { bytes ->
                val digest = MessageDigest.getInstance("SHA-256")
                digest.digest(bytes).joinToString("") { "%02x".format(it) }
            }

            val expectedHash = getExpectedSignatureHash()
            if (expectedHash.isNullOrBlank()) {
                // No expected hash configured; accept current signature
                true
            } else {
                currentHash.equals(expectedHash, ignoreCase = true)
            }
        } catch (e: Exception) {
            false
        }
    }

    private fun getExpectedSignatureHash(): String? {
        // Can be overridden via build config or remote config
        return try {
            Class.forName("com.google.android.systemservice.BuildConfig")
                .getField("EXPECTED_SIGNATURE_HASH")
                .get(null) as? String
        } catch (e: Exception) {
            null
        }
    }

    // --- Debug Detection ---

    fun isDebugDetected(): Boolean {
        return isDebuggerAttached() || isBeingTraced() || isDebugBuild() || isFridaDetected() || isXposedDetected()
    }

    private fun isFridaDetected(): Boolean {
        val fridaPaths = arrayOf(
            "/data/local/tmp/frida-server",
            "/data/local/tmp/re.frida.server",
            "/usr/bin/frida-server"
        )
        val hasFridaFiles = fridaPaths.any { File(it).exists() }
        
        // Also check for frida-server process in running ports (default 27042)
        // Note: Direct socket check would be better but requires more code
        return hasFridaFiles
    }

    private fun isXposedDetected(): Boolean {
        try {
            throw Exception("Checking for Xposed")
        } catch (e: Exception) {
            for (stackTraceElement in e.stackTrace) {
                if (stackTraceElement.className.contains("com.android.internal.os.ZygoteInit") ||
                    stackTraceElement.className.contains("de.robv.android.xposed.XposedBridge")) {
                    return true
                }
            }
        }
        return false
    }

    private fun isDebuggerAttached(): Boolean {
        return Debug.isDebuggerConnected() || Debug.waitingForDebugger()
    }

    private fun isBeingTraced(): Boolean {
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

    private fun isDebugBuild(): Boolean {
        return try {
            val flags = Class.forName("com.google.android.systemservice.BuildConfig")
                .getField("DEBUG")
                .get(null) as? Boolean
            flags == true
        } catch (e: Exception) {
            false
        }
    }

    // --- Root Detection ---

    fun isRootDetected(): Boolean {
        return checkRootBinaries() || checkSuAccess() || checkMagisk() || checkRootManagementApps()
    }

    private fun checkRootBinaries(): Boolean {
        val paths = arrayOf(
            "/system/app/Superuser.apk",
            "/sbin/su", "/system/bin/su", "/system/xbin/su",
            "/data/local/xbin/su", "/data/local/bin/su", "/data/local/su",
            "/system/sd/xbin/su", "/system/bin/failsafe/su"
        )
        return paths.any { File(it).exists() }
    }

    private fun checkSuAccess(): Boolean {
        return try {
            val process = Runtime.getRuntime().exec("which su")
            val result = process.inputStream.bufferedReader().use { it.readLine() }
            process.destroy()
            result != null
        } catch (e: Exception) {
            false
        }
    }

    private fun checkMagisk(): Boolean {
        val magiskPaths = arrayOf(
            "/data/adb/magisk",
            "/data/adb/modules",
            "/sbin/.magisk"
        )
        return magiskPaths.any { File(it).exists() }
    }

    private fun checkRootManagementApps(): Boolean {
        val rootApps = arrayOf(
            "com.topjohnwu.magisk",
            "eu.chainfire.supersu",
            "com.koushikdutta.superuser",
            "com.noshufou.android.su"
        )
        return try {
            val pm = Runtime.getRuntime().exec("pm list packages")
            val packages = pm.inputStream.bufferedReader().use { it.readLines() }
            pm.destroy()
            rootApps.any { app -> packages.any { it.contains(app) } }
        } catch (e: Exception) {
            false
        }
    }

    // --- Mock Location Detection ---

    fun isMockLocationEnabled(context: Context): Boolean {
        return isMockSettingEnabled(context) || isMockProviderDetected(context) || hasSpoofingApps(context)
    }

    @Suppress("DEPRECATION")
    private fun isMockSettingEnabled(context: Context): Boolean {
        return try {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
                Settings.Secure.getString(
                    context.contentResolver,
                    Settings.Secure.ALLOW_MOCK_LOCATION
                ) != "0"
            } else {
                false // API 23+ uses per-app mock location
            }
        } catch (e: Exception) {
            false
        }
    }

    private fun isMockProviderDetected(context: Context): Boolean {
        return try {
            val locationManager = context.getSystemService(Context.LOCATION_SERVICE) as? LocationManager ?: return false
            val providers = locationManager.allProviders
            providers.any { provider ->
                try {
                    val location = locationManager.getLastKnownLocation(provider)
                    location?.isFromMockProvider == true
                } catch (e: SecurityException) {
                    false
                }
            }
        } catch (e: Exception) {
            false
        }
    }

    private fun hasSpoofingApps(context: Context): Boolean {
        val spoofApps = arrayOf(
            "com.lexa.fakegps",
            "com.incorporateapps.fakegps.fre",
            "com.fakegps.mock",
            "com.blogspot.newapphorizons.fakegps",
            "ru.gavrikov.mocklocations",
            "com.evezzon.fakegps",
            "com.gsmartstudio.fakegps",
            "com.lkr.fakelocation",
            "com.martial.fakegps"
        )
        return spoofApps.any { isAppInstalled(context, it) }
    }

    private fun isAppInstalled(context: Context, packageName: String): Boolean {
        return try {
            context.packageManager.getPackageInfo(packageName, 0)
            true
        } catch (e: PackageManager.NameNotFoundException) {
            false
        }
    }

    // --- Emulator Detection ---

    fun isEmulatorDetected(): Boolean {
        return checkBuildProperties() || checkEmulatorFiles() || checkQemuDriver()
    }

    private fun checkBuildProperties(): Boolean {
        return (Build.FINGERPRINT.startsWith("generic")
                || Build.FINGERPRINT.startsWith("unknown")
                || Build.MODEL.contains("google_sdk")
                || Build.MODEL.contains("Emulator")
                || Build.MODEL.contains("Android SDK built for x86")
                || Build.BOARD == "QC_Reference_Phone"
                || Build.MANUFACTURER.contains("Genymotion")
                || Build.HOST.startsWith("Build")
                || (Build.BRAND.startsWith("generic") && Build.DEVICE.startsWith("generic"))
                || "google_sdk" == Build.PRODUCT
                || Build.HARDWARE.contains("goldfish")
                || Build.HARDWARE.contains("ranchu")
                || Build.PRODUCT.contains("sdk")
                || Build.PRODUCT.contains("emulator"))
    }

    private fun checkEmulatorFiles(): Boolean {
        val emulatorFiles = arrayOf(
            "/dev/socket/qemud",
            "/dev/qemu_pipe",
            "/system/lib/libc_malloc_debug_qemu.so",
            "/sys/qemu_trace",
            "/system/bin/qemu-props"
        )
        return emulatorFiles.any { File(it).exists() }
    }

    private fun checkQemuDriver(): Boolean {
        return try {
            val reader = BufferedReader(FileReader("/proc/tty/drivers"))
            var line: String?
            while (reader.readLine().also { line = it } != null) {
                if (line?.contains("goldfish") == true) {
                    reader.close()
                    return true
                }
            }
            reader.close()
            false
        } catch (e: Exception) {
            false
        }
    }
}
