package com.example.my_money_flutter

import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableHighRefreshRate()
    }

    private fun enableHighRefreshRate() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            // Android 11+ (API 30+)
            val currentDisplay = display ?: return
            val modes = currentDisplay.supportedModes
            val highestMode = modes.maxByOrNull { it.refreshRate }
            if (highestMode != null && highestMode.refreshRate >= 90.0f) {
                val params = window.attributes
                params.preferredDisplayModeId = highestMode.modeId
                window.attributes = params
            }
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            // Android 6.0 - 10 (API 23 - 29)
            @Suppress("DEPRECATION")
            val currentDisplay = windowManager.defaultDisplay
            val modes = currentDisplay.supportedModes
            val highestMode = modes.maxByOrNull { it.refreshRate }
            if (highestMode != null && highestMode.refreshRate >= 90.0f) {
                val params = window.attributes
                params.preferredDisplayModeId = highestMode.modeId
                window.attributes = params
            }
        }

        // Android 15+ (API 35+) frame rate category via safe reflection (compatible with any compileSdk)
        if (Build.VERSION.SDK_INT >= 34) {
            try {
                val method = window.javaClass.getMethod("setFrameRateCategory", Int::class.javaPrimitiveType)
                method.invoke(window, 2 /* WINDOW_FRAME_RATE_CATEGORY_HIGH */)
            } catch (_: Throwable) {}
        }
    }
}
