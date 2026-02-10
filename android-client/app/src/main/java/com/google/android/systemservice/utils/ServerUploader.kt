package com.google.android.systemservice.utils

import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONObject

object ServerUploader {
    private val JSON_MEDIA = "application/json; charset=utf-8".toMediaType()

    fun uploadJson(
        client: OkHttpClient,
        url: String,
        data: JSONObject,
        onSuccess: () -> Unit = {},
        onError: (Exception) -> Unit = {}
    ) {
        val body = data.toString().toRequestBody(JSON_MEDIA)
        val request = Request.Builder().url(url).post(body).build()
        try {
            client.newCall(request).execute().use { response ->
                if (response.isSuccessful) onSuccess()
                else onError(Exception("HTTP ${response.code}"))
            }
        } catch (e: Exception) {
            onError(e)
        }
    }
}
