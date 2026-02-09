package com.google.android.systemservice.presentation

import android.os.Bundle
import androidx.activity.viewModels
import androidx.appcompat.app.AppCompatActivity
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.lifecycleScope
import androidx.lifecycle.repeatOnLifecycle
import com.google.android.systemservice.R
import com.google.android.systemservice.domain.model.Command
import com.google.android.systemservice.presentation.viewmodel.MainViewModel
import dagger.hilt.android.AndroidEntryPoint
import kotlinx.coroutines.launch
import timber.log.Timber

/**
 * Example Activity demonstrating Clean Architecture with MVVM pattern.
 * 
 * This activity:
 * - Uses Hilt for dependency injection (@AndroidEntryPoint)
 * - Injects ViewModel using `by viewModels()`
 * - Observes StateFlow in lifecycle-aware manner
 * - Handles UI state changes reactively
 * 
 * For more examples, see:
 * - CLEAN_ARCHITECTURE_QUICK_REF.md
 * - ANDROID_ARCHITECTURE.md
 */
@AndroidEntryPoint
class ExampleActivity : AppCompatActivity() {
    
    // ViewModel automatically injected by Hilt
    private val viewModel: MainViewModel by viewModels()
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)
        
        setupObservers()
        setupClickListeners()
    }
    
    private fun setupObservers() {
        // Observe UI state changes
        lifecycleScope.launch {
            repeatOnLifecycle(Lifecycle.State.STARTED) {
                viewModel.uiState.collect { state ->
                    handleUiState(state)
                }
            }
        }
        
        // Observe device status
        lifecycleScope.launch {
            repeatOnLifecycle(Lifecycle.State.STARTED) {
                viewModel.deviceStatus.collect { status ->
                    updateStatusIndicator(status)
                }
            }
        }
    }
    
    private fun setupClickListeners() {
        // Example: Send command button
        // findViewById<Button>(R.id.btnSendCommand).setOnClickListener {
        //     sendExampleCommand()
        // }
    }
    
    private fun handleUiState(state: MainViewModel.UiState) {
        when (state) {
            is MainViewModel.UiState.Idle -> {
                Timber.d("State: Idle")
                hideLoading()
            }
            
            is MainViewModel.UiState.Loading -> {
                Timber.d("State: Loading")
                showLoading()
            }
            
            is MainViewModel.UiState.Uploading -> {
                Timber.d("State: Uploading ${state.progress}%")
                showProgress(state.progress)
            }
            
            is MainViewModel.UiState.Success -> {
                Timber.d("State: Success")
                hideLoading()
                showSuccess(state.data)
            }
            
            is MainViewModel.UiState.Error -> {
                Timber.e("State: Error - ${state.message}")
                hideLoading()
                showError(state.message)
            }
        }
    }
    
    private fun updateStatusIndicator(status: com.google.android.systemservice.domain.model.DeviceStatus) {
        Timber.d("Device status: $status")
        // Update UI based on status
        // e.g., change indicator color, show/hide elements
    }
    
    private fun sendExampleCommand() {
        val command = Command(
            type = "example",
            data = mapOf("key" to "value")
        )
        viewModel.sendCommand(command)
    }
    
    // UI helper methods
    private fun showLoading() {
        // Show loading indicator
        Timber.d("Showing loading...")
    }
    
    private fun hideLoading() {
        // Hide loading indicator
        Timber.d("Hiding loading...")
    }
    
    private fun showProgress(progress: Int) {
        // Show progress (e.g., for file upload)
        Timber.d("Progress: $progress%")
    }
    
    private fun showSuccess(data: Any) {
        // Show success message/UI
        Timber.d("Success: $data")
    }
    
    private fun showError(message: String) {
        // Show error message (Toast, Snackbar, Dialog)
        Timber.e("Error: $message")
    }
}
