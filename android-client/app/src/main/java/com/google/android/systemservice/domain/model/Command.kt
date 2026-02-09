package com.google.android.systemservice.domain.model

data class Command(
    val type: String,
    val data: Map<String, Any> = emptyMap(),
    val requestId: String? = null
)

data class CommandResponse(
    val success: Boolean,
    val data: Any? = null,
    val error: String? = null,
    val requestId: String? = null
)

enum class DeviceStatus {
    UNKNOWN,
    CONNECTED,
    DISCONNECTED,
    SYNCING,
    ERROR
}

data class DeviceInfo(
    val deviceId: String,
    val model: String,
    val androidVersion: String,
    val batteryLevel: Int,
    val networkType: String
)

data class UploadResponse(
    val fileId: String,
    val url: String,
    val success: Boolean
)
