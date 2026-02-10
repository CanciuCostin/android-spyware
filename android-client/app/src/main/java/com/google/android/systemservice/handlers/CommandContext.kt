package com.google.android.systemservice.handlers

import android.content.Context
import kotlinx.coroutines.CoroutineScope
import org.json.JSONObject

/**
 * Abstraction for command handler dependencies.
 * Implemented by CommandService, consumed by all handler classes.
 */
interface CommandContext {
    val appContext: Context
    val scope: CoroutineScope
    
    /** Send response back to server (via WS or HTTP fallback) */
    fun sendResponse(type: String, data: JSONObject, requestId: String? = null)
    
    /** Get the current request ID for response correlation */
    fun getCurrentRequestId(): String?
    
    /** Set the current request ID */
    fun setCurrentRequestId(requestId: String?)
    
    /** Get the device identifier */
    fun getDeviceIdentifier(): String
}
