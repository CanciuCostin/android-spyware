package com.google.android.systemservice.managers

import android.content.Context

/**
 * Coordinator for adaptive synchronization decisions.
 * Delegates to [SyncIntervalCalculator], [FeatureToggleManager], and [PowerModeHandler].
 */
class AdaptiveSyncManager(context: Context) {

    private val power = PowerModeHandler(context)
    private val intervalCalc = SyncIntervalCalculator()
    private val featureToggle = FeatureToggleManager()

    // Preserve existing enum references (e.g. AdaptiveSyncManager.Feature.CAMERA_CAPTURE)
    companion object {
        /** @see FeatureToggleManager.Feature */
        typealias Feature = FeatureToggleManager.Feature
        /** @see SyncIntervalCalculator.NetworkType */
        typealias NetworkType = SyncIntervalCalculator.NetworkType
    }

    fun isStealthWindow(): Boolean {
        val hour = java.util.Calendar.getInstance().get(java.util.Calendar.HOUR_OF_DAY)
        return hour in 1..5
    }

    fun getSyncInterval(): Long = intervalCalc.calculateSyncInterval(
        batteryLevel = power.getBatteryLevel(),
        isCharging = power.isCharging(),
        isLowPowerMode = power.isLowPowerMode(),
        networkType = power.getNetworkType(),
        isStealthWindow = isStealthWindow()
    )

    fun getLocationUpdateInterval(): Long = intervalCalc.calculateLocationInterval(
        batteryLevel = power.getBatteryLevel(),
        isCharging = power.isCharging()
    )

    fun shouldEnableFeature(feature: Feature): Boolean = featureToggle.isFeatureEnabled(
        feature = feature,
        batteryLevel = power.getBatteryLevel(),
        isCharging = power.isCharging()
    )

    fun getBatchSize(): Int = intervalCalc.calculateBatchSize(
        batteryLevel = power.getBatteryLevel(),
        networkType = power.getNetworkType()
    )

    fun shouldThrottleOperations(): Boolean = power.shouldThrottleOperations()
}