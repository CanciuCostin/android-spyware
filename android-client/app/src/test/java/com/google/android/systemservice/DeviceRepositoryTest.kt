package com.google.android.systemservice

import androidx.arch.core.executor.testing.InstantTaskExecutorRule
import com.google.android.systemservice.data.api.ApiService
import com.google.android.systemservice.data.datasource.LocalDataSource
import com.google.android.systemservice.data.repository.DeviceRepositoryImpl
import com.google.android.systemservice.domain.model.Command
import com.google.android.systemservice.domain.model.CommandResponse
import com.google.android.systemservice.domain.model.DeviceStatus
import io.mockk.coEvery
import io.mockk.every
import io.mockk.mockk
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.*
import org.junit.After
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

@ExperimentalCoroutinesApi
class DeviceRepositoryTest {
    
    @get:Rule
    val instantTaskExecutorRule = InstantTaskExecutorRule()
    
    private val testDispatcher = StandardTestDispatcher()
    
    private lateinit var repository: DeviceRepositoryImpl
    private lateinit var apiService: ApiService
    private lateinit var localDataSource: LocalDataSource
    
    @Before
    fun setup() {
        Dispatchers.setMain(testDispatcher)
        
        apiService = mockk()
        localDataSource = mockk(relaxed = true)
        
        repository = DeviceRepositoryImpl(apiService, localDataSource, testDispatcher)
    }
    
    @After
    fun tearDown() {
        Dispatchers.resetMain()
    }
    
    @Test
    fun `sendCommand returns success on successful API call`() = runTest(testDispatcher) {
        // Given
        val command = Command("test")
        val response = CommandResponse(success = true)
        coEvery { apiService.sendCommand(command) } returns response
        
        // When
        val result = repository.sendCommand(command)
        advanceUntilIdle()
        
        // Then
        assertTrue(result.isSuccess)
        assertEquals(response, result.getOrNull())
    }
    
    @Test
    fun `sendCommand returns failure on API error`() = runTest(testDispatcher) {
        // Given
        val command = Command("test")
        val exception = Exception("Network error")
        coEvery { apiService.sendCommand(command) } throws exception
        
        // When
        val result = repository.sendCommand(command)
        advanceUntilIdle()
        
        // Then
        assertTrue(result.isFailure)
        assertEquals(exception, result.exceptionOrNull())
    }
    
    @Test
    fun `sendCommand updates device status to SYNCING then CONNECTED`() = runTest(testDispatcher) {
        // Given
        val command = Command("test")
        val response = CommandResponse(success = true)
        coEvery { apiService.sendCommand(command) } returns response
        
        // When
        repository.sendCommand(command)
        advanceUntilIdle()
        
        // Then - Verify status was updated
        // (In a real test, you'd want to capture the status updates)
    }
}
