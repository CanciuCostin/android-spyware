package com.google.android.systemservice.utils

import android.util.Log
import okhttp3.WebSocket
import org.json.JSONObject

object WsMessageHelper {
    private const val TAG = "WsMessageHelper"

    /**
     * Build and send an ActionCable-style message over WebSocket.
     * @param ws          WebSocket instance (nullable; returns false if null)
     * @param channel     ActionCable channel name
     * @param deviceId    Device identifier (included in identifier JSON; omit if not needed)
     * @param dataBlock   Builder for the "data" payload
     */
    fun sendChannelMessage(
        ws: WebSocket?,
        channel: String,
        deviceId: String? = null,
        dataBlock: JSONObject.() -> Unit
    ): Boolean {
        val message = JSONObject().apply {
            put("command", "message")
            put("identifier", JSONObject().apply {
                put("channel", channel)
                if (deviceId != null) put("device_id", deviceId)
            }.toString())
            put("data", JSONObject().apply(dataBlock).toString())
        }
        return try {
            ws?.send(message.toString()) ?: false
        } catch (e: Exception) {
            Log.e(TAG, "WS send failed", e)
            false
        }
    }

    /**
     * Send a subscribe command for an ActionCable channel.
     */
    fun subscribe(ws: WebSocket?, channel: String, deviceId: String? = null): Boolean {
        val message = JSONObject().apply {
            put("command", "subscribe")
            put("identifier", JSONObject().apply {
                put("channel", channel)
                if (deviceId != null) put("device_id", deviceId)
            }.toString())
        }
        return try {
            ws?.send(message.toString()) ?: false
        } catch (e: Exception) {
            Log.e(TAG, "WS subscribe failed", e)
            false
        }
    }
}
