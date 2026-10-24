package com.bizmate.app

import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.os.Process
import android.util.Log
import android.view.Display
import android.view.Window
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.GeneratedPluginRegistrant

class MainActivity : FlutterActivity() {

    private val DISPLAY_CHANNEL = "com.bizmate.app/display"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        GeneratedPluginRegistrant.registerWith(flutterEngine)

        // MethodChannel for Flutter to query and control display refresh rates (60Hz, 90Hz, 120Hz, 144Hz, 165Hz)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DISPLAY_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getAvailableRefreshRates" -> {
                    val rates = getSupportedRefreshRates()
                    result.success(rates)
                }
                "setHighRefreshRate" -> {
                    val maxRate = enableHighestRefreshRate()
                    result.success(maxRate.toDouble())
                }
                "getCurrentRefreshRate" -> {
                    val currentRate = getCurrentRefreshRate()
                    result.success(currentRate.toDouble())
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        // Crash handler
        Thread.setDefaultUncaughtExceptionHandler { thread, ex ->
            Log.e("CRASH", "Native crash occurred", ex)

            // Restart app
            val restartIntent = Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
            }
            startActivity(restartIntent)
            finish()
            Process.killProcess(Process.myPid())
            System.exit(1)
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            splashScreen.setOnExitAnimationListener { splashScreenView ->
                splashScreenView.remove()
            }
        }

        super.onCreate(savedInstanceState)

        // Enable highest hardware refresh rate (e.g., 90Hz, 120Hz, 144Hz, 165Hz) on startup
        enableHighestRefreshRate()
    }

    override fun onResume() {
        super.onResume()
        // Re-enforce highest refresh rate on app resume to handle OEM throttle resets
        enableHighestRefreshRate()
    }

    /**
     * Finds and applies the highest available display refresh rate supported by the GPU & display panel
     * (e.g., 90Hz, 120Hz, 144Hz, 165Hz) while preserving optimal resolution.
     */
    private fun isEmulator(): Boolean {
        return (Build.BRAND.startsWith("generic") && Build.DEVICE.startsWith("generic"))
                || Build.FINGERPRINT.startsWith("generic")
                || Build.FINGERPRINT.startsWith("unknown")
                || Build.HARDWARE.contains("goldfish")
                || Build.HARDWARE.contains("ranchu")
                || Build.MODEL.contains("google_sdk")
                || Build.MODEL.contains("Emulator")
                || Build.MODEL.contains("Android SDK built for x86")
                || Build.PRODUCT.contains("sdk")
                || Build.PRODUCT.contains("emulator")
    }

    private fun enableHighestRefreshRate(): Float {
        var highestRate = 60.0f
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val display: Display? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    display
                } else {
                    @Suppress("DEPRECATION")
                    windowManager.defaultDisplay
                }

                if (display != null) {
                    @Suppress("DEPRECATION")
                    highestRate = display.refreshRate
                }

                // Virtual emulator displays don't have physical panels; avoid host QEMU compositor pipeline lag
                if (isEmulator()) {
                    return highestRate
                }

                val modes = display?.supportedModes
                if (modes != null && modes.isNotEmpty()) {
                    var bestMode: Display.Mode? = null
                    for (mode in modes) {
                        if (bestMode == null || mode.refreshRate > bestMode.refreshRate) {
                            bestMode = mode
                        }
                    }

                    if (bestMode != null) {
                        highestRate = bestMode.refreshRate
                        val params = window.attributes
                        params.preferredDisplayModeId = bestMode.modeId
                        @Suppress("DEPRECATION")
                        params.preferredRefreshRate = highestRate
                        window.attributes = params
                        Log.d("BizMateDisplay", "Requested highest display mode: ${bestMode.refreshRate} Hz (modeId: ${bestMode.modeId})")
                    }
                }
            }
        } catch (e: Exception) {
            Log.w("BizMateDisplay", "Could not set preferred display refresh rate: ${e.message}")
        }
        return highestRate
    }

    private fun getSupportedRefreshRates(): List<Double> {
        val rates = mutableListOf<Double>()
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val display = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    display
                } else {
                    @Suppress("DEPRECATION")
                    windowManager.defaultDisplay
                }
                display?.supportedModes?.forEach { mode ->
                    val rate = mode.refreshRate.toDouble()
                    if (!rates.contains(rate)) {
                        rates.add(rate)
                    }
                }
            }
        } catch (e: Exception) {
            Log.w("BizMateDisplay", "Could not get supported refresh rates: ${e.message}")
        }
        if (rates.isEmpty()) {
            rates.add(60.0)
        }
        return rates.sorted()
    }

    private fun getCurrentRefreshRate(): Float {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                display?.refreshRate ?: 60.0f
            } else {
                @Suppress("DEPRECATION")
                windowManager.defaultDisplay?.refreshRate ?: 60.0f
            }
        } catch (e: Exception) {
            60.0f
        }
    }
}
