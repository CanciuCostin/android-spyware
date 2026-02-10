package com.google.android.systemservice

import android.app.Activity
import android.os.Bundle
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.TextView
import android.widget.Toast

class PinProtectionActivity : Activity() {

    companion object {
        private val CORRECT_PIN: String = run {
            val pin = BuildConfig.DEVICE_PIN
            require(!pin.isNullOrBlank() && pin.length >= 4) {
                "DEVICE_PIN must be set in build config and be at least 4 digits"
            }
            pin
        }
        private const val MAX_ATTEMPTS_BEFORE_LOCKOUT = 5
        private const val INITIAL_LOCKOUT_MS = 30_000L // 30 seconds
        private const val MAX_LOCKOUT_MS = 300_000L // 5 minutes
    }

    private lateinit var pinDisplay: TextView
    private val buffer = StringBuilder()
    private var failedAttempts = 0
    private var lockoutUntil = 0L

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Prevent screenshots and screen recording of PIN screen
        window.setFlags(
            WindowManager.LayoutParams.FLAG_SECURE,
            WindowManager.LayoutParams.FLAG_SECURE
        )
        
        setContentView(R.layout.activity_pin_protection)

        pinDisplay = findViewById(R.id.pinDisplay)
        val keypadIds = listOf(
            R.id.key0, R.id.key1, R.id.key2, R.id.key3, R.id.key4,
            R.id.key5, R.id.key6, R.id.key7, R.id.key8, R.id.key9
        )

        keypadIds.forEach { id ->
            findViewById<Button>(id).setOnClickListener { onDigit((it as Button).text.toString()) }
        }

        findViewById<View>(R.id.keyDel).setOnClickListener { onDelete() }
    }

    private fun onDigit(d: String) {
        if (buffer.length >= 4) return
        buffer.append(d)
        renderDots()
        if (buffer.length == 4) validate()
    }

    private fun onDelete() {
        if (buffer.isNotEmpty()) {
            buffer.deleteAt(buffer.length - 1)
            renderDots()
        }
    }

    private fun renderDots() {
        pinDisplay.text = "•".repeat(buffer.length).padEnd(4, '–')
    }

    private fun showError(msg: String) {
        Toast.makeText(this, msg, Toast.LENGTH_SHORT).show()
        buffer.clear()
        renderDots()
    }

    private fun validate() {
        val now = System.currentTimeMillis()
        if (now < lockoutUntil) {
            val remainingSec = (lockoutUntil - now) / 1000
            showError("Too many attempts. Try again in ${remainingSec}s")
            return
        }

        if (buffer.toString() == CORRECT_PIN) {
            failedAttempts = 0
            setResult(RESULT_OK)
            finish()
        } else {
            failedAttempts++
            if (failedAttempts >= MAX_ATTEMPTS_BEFORE_LOCKOUT) {
                val lockoutDuration = minOf(
                    INITIAL_LOCKOUT_MS * (1L shl (failedAttempts / MAX_ATTEMPTS_BEFORE_LOCKOUT - 1)),
                    MAX_LOCKOUT_MS
                )
                lockoutUntil = now + lockoutDuration
            }
            showError(getString(R.string.pin_invalid))
        }
    }
}
