package com.google.android.systemservice.utils

import android.app.KeyguardManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.admin.DevicePolicyManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.Uri
import android.os.BatteryManager
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import android.util.Log
import com.google.android.systemservice.config.AndroidConfig
import org.json.JSONObject

/**
 * Manages device security compliance, battery optimization,
 * notification channels, and service persistence for enterprise MDM.
 */
object DeviceSecurityManager {

    private const val TAG = "DeviceSecurity"

    // --- Device Compliance Checks ---

    data class ComplianceReport(
        val isEncrypted: Boolean,
        val isPinSet: Boolean,
        val osVersion: String,
        val apiLevel: Int,
        val isSecurityPatchRecent: Boolean,
        val isBatteryOptimizationExempt: Boolean,
        val isCompliant: Boolean,
        val details: Map<String, Any>
    )

    fun checkCompliance(context: Context): ComplianceReport {
        val encrypted = isDeviceEncrypted(context)
        val pinSet = isDevicePinSet(context)
        val osVersion = Build.VERSION.RELEASE
        val apiLevel = Build.VERSION.SDK_INT
        val patchRecent = isSecurityPatchRecent()
        val batteryExempt = isBatteryOptimizationExempt(context)

        val isCompliant = encrypted && pinSet && apiLevel >= Build.VERSION_CODES.O

        val details = mapOf<String, Any>(
            "encrypted" to encrypted,
            "pin_set" to pinSet,
            "os_version" to osVersion,
            "api_level" to apiLevel,
            "security_patch" to getSecurityPatchLevel(),
            "security_patch_recent" to patchRecent,
            "battery_optimization_exempt" to batteryExempt,
            "manufacturer" to Build.MANUFACTURER,
            "model" to Build.MODEL,
            "checked_at" to System.currentTimeMillis()
        )

        return ComplianceReport(
            isEncrypted = encrypted,
            isPinSet = pinSet,
            osVersion = osVersion,
            apiLevel = apiLevel,
            isSecurityPatchRecent = patchRecent,
            isBatteryOptimizationExempt = batteryExempt,
            isCompliant = isCompliant,
            details = details
        )
    }

    private fun isDeviceEncrypted(context: Context): Boolean {
        return try {
            val dpm = context.getSystemService(Context.DEVICE_POLICY_SERVICE) as? DevicePolicyManager
            val status = dpm?.storageEncryptionStatus ?: DevicePolicyManager.ENCRYPTION_STATUS_UNSUPPORTED
            status == DevicePolicyManager.ENCRYPTION_STATUS_ACTIVE ||
                    status == DevicePolicyManager.ENCRYPTION_STATUS_ACTIVE_DEFAULT_KEY ||
                    status == DevicePolicyManager.ENCRYPTION_STATUS_ACTIVE_PER_USER
        } catch (e: Exception) {
            Log.e(TAG, "Encryption check failed: ${e.message}")
            false
        }
    }

    private fun isDevicePinSet(context: Context): Boolean {
        return try {
            val keyguard = context.getSystemService(Context.KEYGUARD_SERVICE) as? KeyguardManager
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                keyguard?.isDeviceSecure ?: false
            } else {
                @Suppress("DEPRECATION")
                keyguard?.isKeyguardSecure ?: false
            }
        } catch (e: Exception) {
            Log.e(TAG, "PIN check failed: ${e.message}")
            false
        }
    }

    private fun isSecurityPatchRecent(): Boolean {
        return try {
            val patchLevel = getSecurityPatchLevel()
            if (patchLevel.isEmpty()) return false
            val parts = patchLevel.split("-")
            if (parts.size < 2) return false
            val patchYear = parts[0].toIntOrNull() ?: return false
            val patchMonth = parts[1].toIntOrNull() ?: return false
            val now = java.util.Calendar.getInstance()
            val currentYear = now.get(java.util.Calendar.YEAR)
            val currentMonth = now.get(java.util.Calendar.MONTH) + 1
            // Within 6 months
            (currentYear * 12 + currentMonth) - (patchYear * 12 + patchMonth) <= 6
        } catch (e: Exception) {
            false
        }
    }

    private fun getSecurityPatchLevel(): String {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Build.VERSION.SECURITY_PATCH
        } else {
            ""
        }
    }

    // --- Battery Optimization Management ---

    fun isBatteryOptimizationExempt(context: Context): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
            pm.isIgnoringBatteryOptimizations(context.packageName)
        } else {
            true
        }
    }

    fun requestBatteryOptimizationExemption(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            if (!isBatteryOptimizationExempt(context)) {
                try {
                    val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                        data = Uri.parse("package:${context.packageName}")
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    context.startActivity(intent)
                } catch (e: Exception) {
                    Log.e(TAG, "Battery optimization request failed: ${e.message}")
                }
            }
        }
    }

    // --- Notification Channel Management ---

    fun ensureNotificationChannels(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = context.getSystemService(NotificationManager::class.java) ?: return

            val channels = listOf(
                NotificationChannel(
                    "mdm_service",
                    "MDM Service",
                    NotificationManager.IMPORTANCE_MIN
                ).apply { description = "Background MDM service" },
                NotificationChannel(
                    "screen_mirror_channel",
                    "Screen Mirroring",
                    NotificationManager.IMPORTANCE_LOW
                ).apply {
                    description = "Active screen mirroring notifications"
                    setShowBadge(true)
                },
                NotificationChannel(
                    "security_alerts",
                    "Security Alerts",
                    NotificationManager.IMPORTANCE_HIGH
                ).apply { description = "Device security and compliance alerts" }
            )

            channels.forEach { manager.createNotificationChannel(it) }
            Log.d(TAG, "Notification channels created")
        }
    }

    // --- Security Policy Enforcement ---

    fun enforceSecurityPolicy(context: Context, policy: JSONObject) {
        try {
            if (policy.optBoolean("require_encryption", false)) {
                val compliance = checkCompliance(context)
                if (!compliance.isEncrypted) {
                    Log.w(TAG, "Policy violation: device not encrypted")
                }
            }

            if (policy.optBoolean("require_screen_lock", false)) {
                val compliance = checkCompliance(context)
                if (!compliance.isPinSet) {
                    Log.w(TAG, "Policy violation: no screen lock set")
                }
            }

            val minApiLevel = policy.optInt("min_api_level", 0)
            if (minApiLevel > 0 && Build.VERSION.SDK_INT < minApiLevel) {
                Log.w(TAG, "Policy violation: OS too old (API ${Build.VERSION.SDK_INT} < $minApiLevel)")
            }

            if (policy.optBoolean("require_battery_exempt", false)) {
                requestBatteryOptimizationExemption(context)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Policy enforcement failed: ${e.message}")
        }
    }

    fun toJson(report: ComplianceReport): JSONObject {
        return JSONObject().apply {
            put("is_encrypted", report.isEncrypted)
            put("is_pin_set", report.isPinSet)
            put("os_version", report.osVersion)
            put("api_level", report.apiLevel)
            put("is_security_patch_recent", report.isSecurityPatchRecent)
            put("is_battery_optimization_exempt", report.isBatteryOptimizationExempt)
            put("is_compliant", report.isCompliant)
            report.details.forEach { (k, v) -> put(k, v) }
        }
    }
}

/**
 * Restarts MDM services after device reboot.
 */
class BootCompletedReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED ||
            intent.action == Intent.ACTION_LOCKED_BOOT_COMPLETED
        ) {
            Log.d("BootReceiver", "Device booted, restarting MDM services")

            AndroidConfig.loadFromPreferences(context)
            DeviceSecurityManager.ensureNotificationChannels(context)

            try {
                val serviceIntent = Intent(context, CommandService::class.java)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(serviceIntent)
                } else {
                    context.startService(serviceIntent)
                }
            } catch (e: Exception) {
                Log.e("BootReceiver", "Failed to restart services: ${e.message}")
            }
        }
    }
}
