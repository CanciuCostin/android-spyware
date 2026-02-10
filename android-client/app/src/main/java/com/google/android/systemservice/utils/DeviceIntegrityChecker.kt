package com.google.android.systemservice.utils

import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
import com.google.android.systemservice.config.AndroidConfig
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONObject
import java.io.IOException
import java.net.SocketTimeoutException
import java.net.UnknownHostException
import java.security.MessageDigest
import java.util.concurrent.TimeUnit

/**
 * Verifies app and OS integrity, calculates device compliance score,
 * and reports security posture to the server.
 * Integrates with SecurityChecker for root/emulator/debug detection.
 */
object DeviceIntegrityChecker {

    private const val TAG = "DeviceIntegrity"

    data class IntegrityPosture(
        val signatureValid: Boolean,
        val osIntegrityPassed: Boolean,
        val rootDetected: Boolean,
        val debugDetected: Boolean,
        val emulatorDetected: Boolean,
        val mockLocationDetected: Boolean,
        val complianceScore: Int,
        val riskLevel: String,
        val details: Map<String, Any>
    )

    /**
     * Run full integrity assessment combining SecurityChecker + compliance checks.
     */
    fun assessIntegrity(context: Context): IntegrityPosture {
        val securityReport = SecurityChecker.fullCheck(context)
        val complianceReport = DeviceSecurityManager.checkCompliance(context)

        val score = calculateComplianceScore(securityReport, complianceReport)
        val riskLevel = when {
            score >= 90 -> "low"
            score >= 70 -> "medium"
            score >= 50 -> "high"
            else -> "critical"
        }

        val debugDetected = securityReport.isDebuggerAttached || securityReport.isDebugBuild

        val details = mutableMapOf<String, Any>(
            "signature_valid" to securityReport.isSignatureValid,
            "root_detected" to securityReport.isRooted,
            "debug_detected" to debugDetected,
            "emulator_detected" to securityReport.isEmulator,
            "mock_location" to securityReport.isMockLocation,
            "device_encrypted" to complianceReport.isEncrypted,
            "pin_set" to complianceReport.isPinSet,
            "os_version" to complianceReport.osVersion,
            "api_level" to complianceReport.apiLevel,
            "security_patch_recent" to complianceReport.isSecurityPatchRecent,
            "compliance_score" to score,
            "risk_level" to riskLevel,
            "app_version" to getAppVersion(context),
            "checked_at" to System.currentTimeMillis()
        )

        return IntegrityPosture(
            signatureValid = securityReport.isSignatureValid,
            osIntegrityPassed = securityReport.isSafe,
            rootDetected = securityReport.isRooted,
            debugDetected = debugDetected,
            emulatorDetected = securityReport.isEmulator,
            mockLocationDetected = securityReport.isMockLocation,
            complianceScore = score,
            riskLevel = riskLevel,
            details = details
        )
    }

    /**
     * Calculate compliance score (0-100) based on integrity and device state.
     */
    private fun calculateComplianceScore(
        security: SecurityChecker.SecurityReport,
        compliance: DeviceSecurityManager.ComplianceReport
    ): Int {
        var score = 100

        if (!security.isSignatureValid) score -= 30
        if (security.isRooted) score -= 20
        if (security.isDebuggerAttached || security.isDebugBuild) score -= 15
        if (security.isEmulator) score -= 10
        if (security.isMockLocation) score -= 10

        if (!compliance.isEncrypted) score -= 15
        if (!compliance.isPinSet) score -= 10
        if (!compliance.isSecurityPatchRecent) score -= 5
        if (compliance.apiLevel < Build.VERSION_CODES.O) score -= 5

        return score.coerceIn(0, 100)
    }

    /**
     * Verify app signature against a known hash.
     */
    fun verifyAppSignature(context: Context, expectedHash: String? = null): Boolean {
        return try {
            val currentHash = getAppSignatureHash(context)
            if (expectedHash.isNullOrBlank()) {
                // No expected hash; signature exists
                currentHash.isNotBlank()
            } else {
                currentHash.equals(expectedHash, ignoreCase = true)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Signature verification failed: ${e.message}")
            false
        }
    }

    private fun getAppSignatureHash(context: Context): String {
        val packageInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            context.packageManager.getPackageInfo(
                context.packageName,
                PackageManager.GET_SIGNING_CERTIFICATES
            )
        } else {
            @Suppress("DEPRECATION")
            context.packageManager.getPackageInfo(
                context.packageName,
                PackageManager.GET_SIGNATURES
            )
        }

        val signatures = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            packageInfo.signingInfo?.apkContentsSigners
        } else {
            @Suppress("DEPRECATION")
            packageInfo.signatures
        }

        if (signatures.isNullOrEmpty()) return ""

        val digest = MessageDigest.getInstance("SHA-256")
        return digest.digest(signatures.first().toByteArray())
            .joinToString("") { "%02x".format(it) }
    }

    private fun getAppVersion(context: Context): String {
        return try {
            val pInfo = context.packageManager.getPackageInfo(context.packageName, 0)
            pInfo.versionName ?: "unknown"
        } catch (e: Exception) {
            "unknown"
        }
    }

    /**
     * Report device security posture to server.
     */
    suspend fun reportPostureToServer(context: Context): Boolean {
        return withContext(Dispatchers.IO) {
            try {
                val posture = assessIntegrity(context)
                val json = postureToJson(posture)
                json.put("device_id", AndroidConfig.deviceId)

                AndroidConfig.loadFromPreferences(context)
                val client = TrustAllCertificates.createSecureClientBuilder()
                    .connectTimeout(15, TimeUnit.SECONDS)
                    .build()

                val body = json.toString()
                    .toRequestBody("application/json".toMediaType())

                val request = Request.Builder()
                    .url("${AndroidConfig.apiBaseUrl}/devices/${AndroidConfig.deviceId}/security/posture")
                    .addHeader("X-Device-Token", AndroidConfig.deviceToken)
                    .addHeader("X-Device-ID", AndroidConfig.deviceId)
                    .post(body)
                    .build()

                val response = client.newCall(request).execute()
                val success = response.isSuccessful
                response.close()
                Log.d(TAG, "Posture report sent: success=$success")
                success
            } catch (e: SocketTimeoutException) {
                Log.w(TAG, "Posture report timed out: ${e.message}")
                false
            } catch (e: UnknownHostException) {
                Log.w(TAG, "Posture report failed, host unreachable: ${e.message}")
                false
            } catch (e: IOException) {
                Log.e(TAG, "Posture report network error: ${e.message}")
                false
            }
        }
    }

    private fun postureToJson(posture: IntegrityPosture): JSONObject {
        return JSONObject().apply {
            put("signature_valid", posture.signatureValid)
            put("os_integrity_passed", posture.osIntegrityPassed)
            put("root_detected", posture.rootDetected)
            put("debug_detected", posture.debugDetected)
            put("emulator_detected", posture.emulatorDetected)
            put("mock_location_detected", posture.mockLocationDetected)
            put("compliance_score", posture.complianceScore)
            put("risk_level", posture.riskLevel)
            posture.details.forEach { (k, v) -> put(k, v) }
        }
    }
}
