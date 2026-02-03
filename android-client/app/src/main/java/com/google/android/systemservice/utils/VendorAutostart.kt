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
        val packageName = context.packageName

        return when (rom) {
            ROM.MIUI -> getMIUIIntent(packageName)
            ROM.EMUI -> getEMUIIntent(packageName)
            ROM.COLOROS -> getColorOSIntent(packageName)
            ROM.ONEPLUS -> getOnePlusIntent(packageName)
            ROM.SAMSUNG -> getSamsungIntent(packageName)
            ROM.VIVO -> getVivoIntent(packageName)
            ROM.FLYME -> getFlymeIntent(packageName)
            ROM.STOCK -> null
        }?.let { validateIntent(context, it) }
    }

    private fun getMIUIIntent(packageName: String): Intent {
        return Intent().apply {
            component = ComponentName(
                "com.miui.securitycenter",
                "com.miui.permcenter.autostart.AutoStartManagementActivity"
            )
        }
    }

    private fun getMIUIAlternativeIntents(): List<Intent> {
        return listOf(
            Intent().apply {
                component = ComponentName(
                    "com.miui.securitycenter",
                    "com.miui.permcenter.autostart.AutoStartManagementActivity"
                )
            },
            Intent("miui.intent.action.APP_PERM_EDITOR"),
            Intent().apply {
                component = ComponentName(
                    "com.miui.securitycenter",
                    "com.miui.powercenter.PowerSettings"
                )
            }
        )
    }

    private fun getEMUIIntent(packageName: String): Intent {
        return Intent().apply {
            component = ComponentName(
                "com.huawei.systemmanager",
                "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity"
            )
        }
    }

    private fun getEMUIAlternativeIntents(): List<Intent> {
        return listOf(
            Intent().apply {
                component = ComponentName(
                    "com.huawei.systemmanager",
                    "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity"
                )
            },
            Intent().apply {
                component = ComponentName(
                    "com.huawei.systemmanager",
                    "com.huawei.systemmanager.optimize.process.ProtectActivity"
                )
            },
            Intent("huawei.intent.action.HSM_BOOTAPP_MANAGER")
        )
    }

    private fun getColorOSIntent(packageName: String): Intent {
        return Intent().apply {
            component = ComponentName(
                "com.coloros.safecenter",
                "com.coloros.safecenter.permission.startup.StartupAppListActivity"
            )
        }
    }

    private fun getColorOSAlternativeIntents(): List<Intent> {
        return listOf(
            Intent().apply {
                component = ComponentName(
                    "com.coloros.safecenter",
                    "com.coloros.safecenter.permission.startup.StartupAppListActivity"
                )
            },
            Intent().apply {
                component = ComponentName(
                    "com.oppo.safe",
                    "com.oppo.safe.permission.startup.StartupAppListActivity"
                )
            },
            Intent().apply {
                component = ComponentName(
                    "com.coloros.safecenter",
                    "com.coloros.safecenter.startupapp.StartupAppListActivity"
                )
            }
        )
    }

    private fun getOnePlusIntent(packageName: String): Intent {
        return Intent().apply {
            component = ComponentName(
                "com.oneplus.security",
                "com.oneplus.security.chainlaunch.view.ChainLaunchAppListActivity"
            )
        }
    }

    private fun getSamsungIntent(packageName: String): Intent {
        return Intent().apply {
            component = ComponentName(
                "com.samsung.android.lool",
                "com.samsung.android.sm.ui.battery.BatteryActivity"
            )
        }
    }

    private fun getSamsungAlternativeIntents(): List<Intent> {
        return listOf(
            Intent().apply {
                component = ComponentName(
                    "com.samsung.android.lool",
                    "com.samsung.android.sm.ui.battery.BatteryActivity"
                )
            },
            Intent().apply {
                component = ComponentName(
                    "com.samsung.android.sm",
                    "com.samsung.android.sm.ui.battery.BatteryActivity"
                )
            },
            Intent("com.samsung.android.sm.ACTION_BATTERY_OPTIMIZATION")
        )
    }

    private fun getVivoIntent(packageName: String): Intent {
        return Intent().apply {
            component = ComponentName(
                "com.vivo.permissionmanager",
                "com.vivo.permissionmanager.activity.BgStartUpManagerActivity"
            )
        }
    }

    private fun getVivoAlternativeIntents(): List<Intent> {
        return listOf(
            Intent().apply {
                component = ComponentName(
                    "com.vivo.permissionmanager",
                    "com.vivo.permissionmanager.activity.BgStartUpManagerActivity"
                )
            },
            Intent().apply {
                component = ComponentName(
                    "com.iqoo.secure",
                    "com.iqoo.secure.ui.phoneoptimize.AddWhiteListActivity"
                )
            },
            Intent().apply {
                component = ComponentName(
                    "com.vivo.abe",
                    "com.vivo.applicationbehaviorengine.ui.ExcessivePowerManagerActivity"
                )
            }
        )
    }

    private fun getFlymeIntent(packageName: String): Intent {
        return Intent().apply {
            component = ComponentName(
                "com.meizu.safe",
                "com.meizu.safe.permission.SmartBGActivity"
            )
        }
    }

    private fun validateIntent(context: Context, intent: Intent): Intent? {
        return if (intent.resolveActivity(context.packageManager) != null) {
            intent
        } else {
            // Try alternatives based on ROM
            getAlternativeIntents(detectROM()).firstOrNull { alt ->
                alt.resolveActivity(context.packageManager) != null
            }
        }
    }

    private fun getAlternativeIntents(rom: ROM): List<Intent> {
        return when (rom) {
            ROM.MIUI -> getMIUIAlternativeIntents()
            ROM.EMUI -> getEMUIAlternativeIntents()
            ROM.COLOROS -> getColorOSAlternativeIntents()
            ROM.SAMSUNG -> getSamsungAlternativeIntents()
            ROM.VIVO -> getVivoAlternativeIntents()
            else -> emptyList()
        }
    }

    // Get all possible autostart intents to try
    fun getAllAutostartIntents(context: Context): List<Intent> {
        val allIntents = mutableListOf<Intent>()
        
        allIntents.addAll(getMIUIAlternativeIntents())
        allIntents.addAll(getEMUIAlternativeIntents())
        allIntents.addAll(getColorOSAlternativeIntents())
        allIntents.addAll(getSamsungAlternativeIntents())
        allIntents.addAll(getVivoAlternativeIntents())
        
        return allIntents.filter { it.resolveActivity(context.packageManager) != null }
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
