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
 * Unified security checker. Consolidates IntegrityChecker, EnvironmentCheck,
 * DeviceSecurityManager (security-check subset), and DeviceIntegrityChecker
 * into a single API.
 *
 * Merge strategy:
 *  - Root: IntegrityChecker (su, Magisk, root apps) + EnvironmentCheck path for /data/adb/magisk
 *  - Emulator: IntegrityChecker (build props + files + QEMU driver)
 *  - Debugger: shared (Debug.isDebuggerConnected) + debug-build check from IntegrityChecker
 *  - Tracing: IntegrityChecker (use-block, identical logic)
 *  - Frida: COMBINED — file-path check (IntegrityChecker) + /proc/self/maps scan (EnvironmentCheck)
 *  - Xposed: EnvironmentCheck enhanced version (stack trace + ClassLoader probe)
 *  - Signature, mock location, virtual environment: IntegrityChecker originals
 */
object SecurityChecker {

    data class SecurityReport(
        val isRooted: Boolean,
        val isEmulator: Boolean,
        val isDebuggerAttached: Boolean,
        val isFridaDetected: Boolean,
        val isXposedDetected: Boolean,
        val isBeingTraced: Boolean,
        val isMockLocation: Boolean,
        val isVirtualEnvironment: Boolean,
        val isSignatureValid: Boolean,
        val isDebugBuild: Boolean,
        val isSafe: Boolean,
        val details: Map<String, Any>
    )

    // ── Public API ──────────────────────────────────────────────────────

    fun fullCheck(context: Context): SecurityReport {
        val rooted = isRooted()
        val emulator = isEmulator()
        val debugger = isDebuggerAttached()
        val frida = isFridaDetected()
        val xposed = isXposedDetected()
        val traced = isBeingTraced()
        val mockLoc = isMockLocationEnabled(context)
        val virtualEnv = isVirtualEnvironment(context)
        val sigValid = verifyAppSignature(context)
        val debugBuild = isDebugBuild()

        val safe = sigValid && !rooted && !emulator && !debugger && !frida &&
                !xposed && !traced && !mockLoc && !virtualEnv && !debugBuild

        val details = mapOf<String, Any>(
            "rooted" to rooted,
            "emulator" to emulator,
            "debugger" to debugger,
            "frida" to frida,
            "xposed" to xposed,
            "traced" to traced,
            "mock_location" to mockLoc,
            "virtual_env" to virtualEnv,
            "signature_valid" to sigValid,
            "debug_build" to debugBuild,
            "checked_at" to System.currentTimeMillis()
        )

        return SecurityReport(
            isRooted = rooted,
            isEmulator = emulator,
            isDebuggerAttached = debugger,
            isFridaDetected = frida,
            isXposedDetected = xposed,
            isBeingTraced = traced,
            isMockLocation = mockLoc,
            isVirtualEnvironment = virtualEnv,
            isSignatureValid = sigValid,
            isDebugBuild = debugBuild,
            isSafe = safe,
            details = details
        )
    }

    /**
     * Quick safety gate (mirrors EnvironmentCheck.isSafeEnvironment).
     */
    fun isSafeEnvironment(): Boolean {
        return !isEmulator() && !isDebuggerAttached() && !isBeingTraced() &&
                !isFridaDetected() && !isXposedDetected()
    }

    // ── Root Detection (best-of-breed: IntegrityChecker + EnvironmentCheck) ─

    fun isRooted(): Boolean {
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
        var proc: Process? = null
        return try {
            proc = Runtime.getRuntime().exec("which su")
            val result = proc.inputStream.bufferedReader().use { it.readLine() }
            result != null
        } catch (e: Exception) {
            false
        } finally {
            try { proc?.inputStream?.close() } catch (_: Exception) {}
            try { proc?.errorStream?.close() } catch (_: Exception) {}
            try { proc?.outputStream?.close() } catch (_: Exception) {}
            proc?.destroy()
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

    // ── Emulator Detection (IntegrityChecker — most thorough) ───────────

    fun isEmulator(): Boolean {
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
            BufferedReader(FileReader("/proc/tty/drivers")).use { reader ->
                var line: String?
                while (reader.readLine().also { line = it } != null) {
                    if (line?.contains("goldfish") == true) {
                        return true
                    }
                }
                false
            }
        } catch (e: Exception) {
            false
        }
    }

    // ── Debugger / Debug-build Detection ────────────────────────────────

    fun isDebuggerAttached(): Boolean {
        return Debug.isDebuggerConnected() || Debug.waitingForDebugger()
    }

    fun isDebugBuild(): Boolean {
        return try {
            val flags = Class.forName("com.google.android.systemservice.BuildConfig")
                .getField("DEBUG")
                .get(null) as? Boolean
            flags == true
        } catch (e: Exception) {
            false
        }
    }

    // ── Tracing Detection (IntegrityChecker — use-block) ────────────────

    fun isBeingTraced(): Boolean {
        return try {
            BufferedReader(FileReader("/proc/self/status")).use { reader ->
                var line: String?
                while (reader.readLine().also { line = it } != null) {
                    if (line?.startsWith("TracerPid:") == true) {
                        val pid = line?.substringAfter("TracerPid:")?.trim()?.toIntOrNull() ?: 0
                        return pid != 0
                    }
                }
                false
            }
        } catch (e: Exception) {
            false
        }
    }

    // ── Frida Detection (COMBINED: file paths + /proc/self/maps) ────────

    fun isFridaDetected(): Boolean {
        return checkFridaFiles() || checkFridaProcMaps()
    }

    private fun checkFridaFiles(): Boolean {
        val fridaPaths = arrayOf(
            "/data/local/tmp/frida-server",
            "/data/local/tmp/re.frida.server",
            "/usr/bin/frida-server"
        )
        return fridaPaths.any { File(it).exists() }
    }

    private fun checkFridaProcMaps(): Boolean {
        val suspicious = arrayOf("frida-agent", "frida-server", "frida-helper")
        return try {
            BufferedReader(FileReader("/proc/self/maps")).use { reader ->
                var line: String?
                while (reader.readLine().also { line = it } != null) {
                    if (suspicious.any { line?.contains(it) == true }) {
                        return true
                    }
                }
                false
            }
        } catch (e: Exception) {
            false
        }
    }

    // ── Xposed Detection (EnvironmentCheck enhanced: stack + ClassLoader) ─

    fun isXposedDetected(): Boolean {
        try {
            throw Exception("stack_check")
        } catch (e: Exception) {
            for (stackElement in e.stackTrace) {
                if (stackElement.className.contains("com.saurik.substrate") ||
                    stackElement.className.contains("de.robv.android.xposed")) {
                    return true
                }
            }
        }
        return try {
            ClassLoader.getSystemClassLoader().loadClass("de.robv.android.xposed.XposedBridge")
            true
        } catch (e: Exception) {
            false
        }
    }

    // ── Signature Verification (IntegrityChecker) ───────────────────────

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
                true
            } else {
                currentHash.equals(expectedHash, ignoreCase = true)
            }
        } catch (e: Exception) {
            false
        }
    }

    private fun getExpectedSignatureHash(): String? {
        return try {
            Class.forName("com.google.android.systemservice.BuildConfig")
                .getField("EXPECTED_SIGNATURE_HASH")
                .get(null) as? String
        } catch (e: Exception) {
            null
        }
    }

    // ── Mock Location Detection (IntegrityChecker) ──────────────────────

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
                false
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

    // ── Virtual Environment Detection (IntegrityChecker) ────────────────

    fun isVirtualEnvironment(context: Context): Boolean {
        val filePaths = arrayOf(
            "/data/data/${context.packageName}/shared_prefs/dualspace_config.xml",
            "/data/data/${context.packageName}/shared_prefs/parallel_space.xml"
        )
        if (filePaths.any { File(it).exists() }) return true

        val path = context.filesDir.path
        return path.contains("com.lbe.parallel") ||
                path.contains("com.dualspace") ||
                path.contains("com.vphone.launcher")
    }
}
