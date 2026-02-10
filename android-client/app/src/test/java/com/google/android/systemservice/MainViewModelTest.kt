package com.google.android.systemservice

import androidx.arch.core.executor.testing.InstantTaskExecutorRule
import com.google.android.systemservice.data.repository.DeviceRepository
import com.google.android.systemservice.domain.model.Command
import com.google.android.systemservice.domain.model.CommandResponse
import com.google.android.systemservice.domain.model.DeviceStatus
import com.google.android.systemservice.domain.usecase.ObserveDeviceStatusUseCase
import com.google.android.systemservice.domain.usecase.SendCommandUseCase
import com.google.android.systemservice.domain.usecase.SendHeartbeatUseCase
import com.google.android.systemservice.domain.usecase.UploadFileUseCase
import com.google.android.systemservice.domain.model.UploadResponse
import com.google.android.systemservice.presentation.viewmodel.MainViewModel
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.every
import io.mockk.mockk
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.test.*
import org.junit.After
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import java.io.File
import kotlin.test.assertEquals
import kotlin.test.assertTrue

@ExperimentalCoroutinesApi
class MainViewModelTest {
    
    @get:Rule
    val instantTaskExecutorRule = InstantTaskExecutorRule()
    
    private val testDispatcher = StandardTestDispatcher()
    
    private lateinit var viewModel: MainViewModel
    private lateinit var repository: DeviceRepository
    
    @Before
    fun setup() {
        Dispatchers.setMain(testDispatcher)
        
        repository = mockk(relaxed = true)
        
        // Mock the flow
        every { repository.observeDeviceStatus() } returns flowOf(DeviceStatus.CONNECTED)
        
        viewModel = MainViewModel(
            sendCommandUseCase = SendCommandUseCase(repository),
            observeDeviceStatusUseCase = ObserveDeviceStatusUseCase(repository),
            uploadFileUseCase = UploadFileUseCase(repository),
            sendHeartbeatUseCase = SendHeartbeatUseCase(repository)
        )
    }
    
    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }
    
    @Test
    fun `sendCommand emits loading then success`() = runTest(testDispatcher) {
        // Given
        val command = Command("test")
        val response = CommandResponse(success = true, data = "result")
        coEvery { repository.sendCommand(command) } returns Result.success(response)
        
        // When
        viewModel.sendCommand(command)
        advanceUntilIdle()
        
        // Then
        val state = viewModel.uiState.value
        assertTrue(state is MainViewModel.UiState.Success)
    }
    
    @Test
    fun `sendCommand emits error on failure`() = runTest(testDispatcher) {
        // Given
        val command = Command("test")
        val exception = Exception("Network error")
        coEvery { repository.sendCommand(command) } returns Result.failure(exception)
        
        // When
        viewModel.sendCommand(command)
        advanceUntilIdle()
        
        // Then
        val state = viewModel.uiState.value
        assertTrue(state is MainViewModel.UiState.Error)
        assertEquals("Network error", (state as MainViewModel.UiState.Error).message)
    }
    
    @Test
    fun `observeDeviceStatus updates deviceStatus flow`() = runTest(testDispatcher) {
        // Given
        every { repository.observeDeviceStatus() } returns flowOf(DeviceStatus.SYNCING)
        
        // Recreate ViewModel to trigger init block
        viewModel = MainViewModel(
            sendCommandUseCase = SendCommandUseCase(repository),
            observeDeviceStatusUseCase = ObserveDeviceStatusUseCase(repository),
            uploadFileUseCase = UploadFileUseCase(repository),
            sendHeartbeatUseCase = SendHeartbeatUseCase(repository)
        )
        
        advanceUntilIdle()
        
        // Then
        assertEquals(DeviceStatus.SYNCING, viewModel.deviceStatus.value)
    }
    
    @Test
    fun `uploadFile success updates state`() = runTest(testDispatcher) {
        // Given
        val mockFile = mockk<File>()
        val uploadResponse = UploadResponse(fileId = "123", url = "https://example.com/file", success = true)
        coEvery { repository.uploadFile(mockFile) } returns Result.success(uploadResponse)
        
        // When
        viewModel.uploadFile(mockFile)
        advanceUntilIdle()
        
        // Then
        val state = viewModel.uiState.value
        assertTrue(state is MainViewModel.UiState.Success)
        assertEquals(uploadResponse, (state as MainViewModel.UiState.Success).data)
    }
    
    @Test
    fun `uploadFile failure updates error state`() = runTest(testDispatcher) {
        // Given
        val mockFile = mockk<File>()
        val exception = Exception("Upload failed")
        coEvery { repository.uploadFile(mockFile) } returns Result.failure(exception)
        
        // When
        viewModel.uploadFile(mockFile)
        advanceUntilIdle()
        
        // Then
        val state = viewModel.uiState.value
        assertTrue(state is MainViewModel.UiState.Error)
        assertEquals("Upload failed", (state as MainViewModel.UiState.Error).message)
    }
    
    @Test
    fun `sendPeriodicHeartbeat calls repository`() = runTest(testDispatcher) {
        // Given
        coEvery { repository.sendHeartbeat() } returns Result.success(true)
        
        // When - advance past the 60-second delay to trigger heartbeat
        advanceTimeBy(60_001)
        advanceUntilIdle()
        
        // Then
        coVerify(atLeast = 1) { repository.sendHeartbeat() }
    }
}
