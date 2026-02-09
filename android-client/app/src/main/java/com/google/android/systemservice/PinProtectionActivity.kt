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
        private val CORRECT_PIN = BuildConfig.DEVICE_PIN
    }

    private lateinit var pinDisplay: TextView
    private val buffer = StringBuilder()

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

    private fun validate() {
        if (buffer.toString() == CORRECT_PIN) {
            setResult(RESULT_OK)
            finish()
        } else {
            Toast.makeText(this, R.string.pin_invalid, Toast.LENGTH_SHORT).show()
            buffer.clear()
            renderDots()
        }
    }
}
