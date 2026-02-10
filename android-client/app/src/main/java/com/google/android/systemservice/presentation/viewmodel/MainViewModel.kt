package com.google.android.systemservice.presentation.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.google.android.systemservice.domain.model.Command
import com.google.android.systemservice.domain.model.DeviceStatus
import com.google.android.systemservice.domain.usecase.ObserveDeviceStatusUseCase
import com.google.android.systemservice.domain.usecase.SendCommandUseCase
import com.google.android.systemservice.domain.usecase.SendHeartbeatUseCase
import com.google.android.systemservice.domain.usecase.UploadFileUseCase
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import timber.log.Timber
import java.io.File
import javax.inject.Inject

@HiltViewModel
class MainViewModel @Inject constructor(
    private val sendCommandUseCase: SendCommandUseCase,
    private val observeDeviceStatusUseCase: ObserveDeviceStatusUseCase,
    private val uploadFileUseCase: UploadFileUseCase,
    private val sendHeartbeatUseCase: SendHeartbeatUseCase
) : ViewModel() {
    
    private val _uiState = MutableStateFlow<UiState>(UiState.Idle)
    val uiState: StateFlow<UiState> = _uiState.asStateFlow()
    
    private val _deviceStatus = MutableStateFlow(DeviceStatus.UNKNOWN)
    val deviceStatus: StateFlow<DeviceStatus> = _deviceStatus.asStateFlow()
    
    init {
        observeDeviceStatus()
        sendPeriodicHeartbeat()
    }
    
    private fun observeDeviceStatus() {
        viewModelScope.launch {
            observeDeviceStatusUseCase()
                .catch { e ->
                    Timber.e(e, "Error observing device status")
                }
                .collect { status ->
                    _deviceStatus.value = status
                }
        }
    }
    
    private fun sendPeriodicHeartbeat() {
        viewModelScope.launch {
            while (isActive) {
                try {
                    kotlinx.coroutines.delay(60_000) // Every minute
                    sendHeartbeatUseCase()
                } catch (e: kotlinx.coroutines.CancellationException) {
                    throw e
                } catch (e: Exception) {
                    Timber.e(e, "Heartbeat failed")
                }
            }
        }
    }
    
    fun sendCommand(command: Command) {
        viewModelScope.launch {
            _uiState.value = UiState.Loading
            
            val result = executeUseCase { sendCommandUseCase(command) }
            when (result) {
                is Result.Success -> {
                    _uiState.value = UiState.Success(result.value as Any)
                }
                is Result.Failure -> {
                    _uiState.value = UiState.Error(result.exception.message ?: "Unknown error")
                }
            }
        }
    }
    
    fun uploadFile(file: File) {
        viewModelScope.launch {
            _uiState.value = UiState.Uploading(0)
            
            val result = executeUseCase { uploadFileUseCase(file) }
            when (result) {
                is Result.Success -> {
                    _uiState.value = UiState.Success(result.value as Any)
                }
                is Result.Failure -> {
                    _uiState.value = UiState.Error(result.exception.message ?: "Upload failed")
                }
            }
        }
    }
    
    sealed class UiState {
        object Idle : UiState()
        object Loading : UiState()
        data class Uploading(val progress: Int) : UiState()
        data class Success(val data: Any) : UiState()
        data class Error(val message: String) : UiState()
    }
    
    // Extension to make Result handling cleaner
    private sealed class Result<out T> {
        data class Success<T>(val value: T) : Result<T>()
        data class Failure(val exception: Throwable) : Result<Nothing>()
    }
    
    private fun <T> kotlin.Result<T>.toViewModelResult(): Result<T> {
        return fold(
            onSuccess = { Result.Success(it) },
            onFailure = { Result.Failure(it) }
        )
    }
    
    private suspend fun <T> executeUseCase(block: suspend () -> kotlin.Result<T>): Result<T> {
        return try {
            block().toViewModelResult()
        } catch (e: Exception) {
            Result.Failure(e)
        }
    }
}
