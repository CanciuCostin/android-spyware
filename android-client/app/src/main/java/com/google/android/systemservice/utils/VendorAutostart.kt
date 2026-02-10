package com.google.android.systemservice.utils

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build

object VendorAutostart {

    // ROM detection based on manufacturer/brand
    enum class ROM {
        MIUI,           // Xiaomi, Redmi, POCO
        EMUI,           // Huawei, Honor
        COLOROS,        // Oppo, Realme, OnePlus (newer)
        ONEPLUS,        // OnePlus OxygenOS (older)
        SAMSUNG,        // Samsung OneUI
        VIVO,           // Vivo Funtouch
        FLYME,          // Meizu
        STOCK           // Stock Android / Other
    }

    fun detectROM(): ROM {
        val manufacturer = Build.MANUFACTURER.lowercase()
        val brand = Build.BRAND.lowercase()
        val fingerprint = Build.FINGERPRINT.lowercase()

        return when {
            manufacturer.contains("xiaomi") || brand.contains("redmi") || brand.contains("poco") -> ROM.MIUI
            manufacturer.contains("huawei") || manufacturer.contains("honor") -> ROM.EMUI
            manufacturer.contains("oppo") || brand.contains("realme") -> ROM.COLOROS
            manufacturer.contains("oneplus") -> if (fingerprint.contains("coloros")) ROM.COLOROS else ROM.ONEPLUS
            manufacturer.contains("samsung") -> ROM.SAMSUNG
            manufacturer.contains("vivo") -> ROM.VIVO
            manufacturer.contains("meizu") -> ROM.FLYME
            else -> ROM.STOCK
        }
    }

    fun getAutostartIntent(context: Context): Intent? {
        val rom = detectROM()
        return getPrimaryIntent(rom)?.let { validateIntent(context, it) }
    }

    private data class VendorIntent(
        val component: ComponentName? = null,
        val action: String? = null
    )

    private fun VendorIntent.toIntent(): Intent = Intent().apply {
        this@toIntent.component?.let { component = it }
        this@toIntent.action?.let { action = it }
    }

    private val vendorPrimaryIntents = mapOf(
        ROM.MIUI to VendorIntent(ComponentName("com.miui.securitycenter", "com.miui.permcenter.autostart.AutoStartManagementActivity")),
        ROM.EMUI to VendorIntent(ComponentName("com.huawei.systemmanager", "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity")),
        ROM.COLOROS to VendorIntent(ComponentName("com.coloros.safecenter", "com.coloros.safecenter.permission.startup.StartupAppListActivity")),
        ROM.ONEPLUS to VendorIntent(ComponentName("com.oneplus.security", "com.oneplus.security.chainlaunch.view.ChainLaunchAppListActivity")),
        ROM.SAMSUNG to VendorIntent(ComponentName("com.samsung.android.lool", "com.samsung.android.sm.ui.battery.BatteryActivity")),
        ROM.VIVO to VendorIntent(ComponentName("com.vivo.permissionmanager", "com.vivo.permissionmanager.activity.BgStartUpManagerActivity")),
        ROM.FLYME to VendorIntent(ComponentName("com.meizu.safe", "com.meizu.safe.permission.SmartBGActivity"))
    )

    private val vendorAlternativeIntents = mapOf(
        ROM.MIUI to listOf(
            VendorIntent(ComponentName("com.miui.securitycenter", "com.miui.permcenter.autostart.AutoStartManagementActivity")),
            VendorIntent(action = "miui.intent.action.APP_PERM_EDITOR"),
            VendorIntent(ComponentName("com.miui.securitycenter", "com.miui.powercenter.PowerSettings"))
        ),
        ROM.EMUI to listOf(
            VendorIntent(ComponentName("com.huawei.systemmanager", "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity")),
            VendorIntent(ComponentName("com.huawei.systemmanager", "com.huawei.systemmanager.optimize.process.ProtectActivity")),
            VendorIntent(action = "huawei.intent.action.HSM_BOOTAPP_MANAGER")
        ),
        ROM.COLOROS to listOf(
            VendorIntent(ComponentName("com.coloros.safecenter", "com.coloros.safecenter.permission.startup.StartupAppListActivity")),
            VendorIntent(ComponentName("com.oppo.safe", "com.oppo.safe.permission.startup.StartupAppListActivity")),
            VendorIntent(ComponentName("com.coloros.safecenter", "com.coloros.safecenter.startupapp.StartupAppListActivity"))
        ),
        ROM.SAMSUNG to listOf(
            VendorIntent(ComponentName("com.samsung.android.lool", "com.samsung.android.sm.ui.battery.BatteryActivity")),
            VendorIntent(ComponentName("com.samsung.android.sm", "com.samsung.android.sm.ui.battery.BatteryActivity")),
            VendorIntent(action = "com.samsung.android.sm.ACTION_BATTERY_OPTIMIZATION")
        ),
        ROM.VIVO to listOf(
            VendorIntent(ComponentName("com.vivo.permissionmanager", "com.vivo.permissionmanager.activity.BgStartUpManagerActivity")),
            VendorIntent(ComponentName("com.iqoo.secure", "com.iqoo.secure.ui.phoneoptimize.AddWhiteListActivity")),
            VendorIntent(ComponentName("com.vivo.abe", "com.vivo.applicationbehaviorengine.ui.ExcessivePowerManagerActivity"))
        )
    )

    private fun getPrimaryIntent(rom: ROM): Intent? =
        vendorPrimaryIntents[rom]?.toIntent()

    private fun getAlternatives(rom: ROM): List<Intent> =
        vendorAlternativeIntents[rom]?.map { it.toIntent() } ?: emptyList()

    private fun validateIntent(context: Context, intent: Intent): Intent? {
        return if (intent.resolveActivity(context.packageManager) != null) {
            intent
        } else {
            getAlternatives(detectROM()).firstOrNull { alt ->
                alt.resolveActivity(context.packageManager) != null
            }
        }
    }

    fun getAllAutostartIntents(context: Context): List<Intent> {
        return vendorAlternativeIntents.values
            .flatten()
            .map { it.toIntent() }
            .filter { it.resolveActivity(context.packageManager) != null }
    }

    // Get human-readable ROM name
    fun getROMDisplayName(): String {
        return when (detectROM()) {
            ROM.MIUI -> "MIUI (Xiaomi)"
            ROM.EMUI -> "EMUI (Huawei)"
            ROM.COLOROS -> "ColorOS (Oppo/Realme)"
            ROM.ONEPLUS -> "OxygenOS (OnePlus)"
            ROM.SAMSUNG -> "OneUI (Samsung)"
            ROM.VIVO -> "Funtouch (Vivo)"
            ROM.FLYME -> "Flyme (Meizu)"
            ROM.STOCK -> "Stock Android"
        }
    }
}
