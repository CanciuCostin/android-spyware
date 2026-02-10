package com.google.android.systemservice.presentation.viewmodel

import androidx.lifecycle.ViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update

class SetupWizardViewModel : ViewModel() {

    enum class WizardStep(
        val title: String,
        val description: String,
        val statusText: String,
        val buttonText: String
    ) {
        ACCESSIBILITY(
            "Accessibility Service",
            "Enable accessibility for system monitoring",
            "Enabling accessibility service...",
            "ENABLE SERVICE"
        ),
        PERMISSIONS(
            "Runtime Permissions",
            "Grant required permissions",
            "Configuring system permissions...",
            "GRANT PERMISSIONS"
        ),
        NOTIFICATION(
            "Notification Access",
            "Enable notification listener",
            "Configuring notification access...",
            "ENABLE ACCESS"
        ),
        BATTERY(
            "Battery Optimization",
            "Exempt from battery optimization",
            "Optimizing battery settings...",
            "OPTIMIZE"
        ),
        DEVICE_ADMIN(
            "Device Admin",
            "Activate device administrator",
            "Securing system administrator...",
            "ACTIVATE"
        ),
        AUTOSTART(
            "Vendor Autostart",
            "Configure manufacturer autostart",
            "Configuring autostart...",
            "CONFIGURE"
        ),
        STORAGE(
            "Storage Access",
            "Grant file access permission",
            "Granting All Files Access...",
            "ALLOW ACCESS"
        );
    }

    data class WizardState(
        val currentStep: Int = 0,
        val completedSteps: Set<Int> = emptySet(),
        val totalSteps: Int = WizardStep.values().size,
        val setupComplete: Boolean = false
    ) {
        val currentWizardStep: WizardStep
            get() = if (currentStep in 0 until totalSteps) WizardStep.values()[currentStep]
                     else WizardStep.values().last()
        val isLastStep: Boolean get() = currentStep == totalSteps - 1
        val isFirstStep: Boolean get() = currentStep == 0
        val progress: Float get() = completedSteps.size.toFloat() / totalSteps
        val progressPercent: Int get() = ((currentStep.toFloat() / totalSteps) * 100).toInt()
        val stepLabel: String get() = "Step ${currentStep + 1} of $totalSteps"
        val statusText: String get() = currentWizardStep.statusText
        val buttonText: String get() = currentWizardStep.buttonText
    }

    private val _state = MutableStateFlow(WizardState())
    val state: StateFlow<WizardState> = _state.asStateFlow()

    fun markStepComplete(step: Int) {
        _state.update { current ->
            current.copy(completedSteps = current.completedSteps + step)
        }
    }

    fun goToNext() {
        _state.update { current ->
            val completed = current.completedSteps + current.currentStep
            val nextStep = current.currentStep + 1
            if (nextStep >= current.totalSteps) {
                current.copy(
                    currentStep = nextStep,
                    completedSteps = completed,
                    setupComplete = true
                )
            } else {
                current.copy(
                    currentStep = nextStep,
                    completedSteps = completed
                )
            }
        }
    }

    fun goToPrevious() {
        _state.update { current ->
            if (current.isFirstStep) current
            else current.copy(currentStep = current.currentStep - 1)
        }
    }

    fun skipStep() {
        _state.update { current ->
            val nextStep = current.currentStep + 1
            if (nextStep >= current.totalSteps) {
                current.copy(currentStep = nextStep, setupComplete = true)
            } else {
                current.copy(currentStep = nextStep)
            }
        }
    }

    fun goToStep(step: Int) {
        require(step in 0 until WizardStep.values().size) { "Invalid step: $step" }
        _state.update { current ->
            current.copy(currentStep = step)
        }
    }

    fun resetWizard() {
        _state.value = WizardState()
    }

    fun isAllComplete(): Boolean {
        val current = _state.value
        return current.completedSteps.size == current.totalSteps
    }

    fun isStepComplete(step: Int): Boolean {
        return step in _state.value.completedSteps
    }
}
