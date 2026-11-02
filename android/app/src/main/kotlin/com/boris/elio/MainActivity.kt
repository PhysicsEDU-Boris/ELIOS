package com.boris.elio

import android.app.ActivityManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Debug
import android.os.PowerManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "elio/device_health")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "thermalStatus" ->
                        result.success((getSystemService(Context.POWER_SERVICE) as PowerManager).currentThermalStatus)
                    "memory" -> {
                        val am = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
                        val info = ActivityManager.MemoryInfo().also { am.getMemoryInfo(it) }
                        val mem = Debug.MemoryInfo().also { Debug.getMemoryInfo(it) }
                        result.success(
                            mapOf(
                                "pssKb" to mem.totalPss,
                                "availKb" to (info.availMem / 1024).toInt(),
                                "totalKb" to (info.totalMem / 1024).toInt(),
                                "lowMemory" to info.lowMemory,
                            )
                        )
                    }
                    "lastExitReason" -> {
                        val am = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
                        result.success(am.getHistoricalProcessExitReasons(null, 0, 1).firstOrNull()?.reason)
                    }
                    "shareText" -> {
                        val send = Intent(Intent.ACTION_SEND).apply {
                            type = "text/plain"
                            putExtra(Intent.EXTRA_TEXT, call.arguments as String)
                        }
                        startActivity(Intent.createChooser(send, "Bagikan log ELIOS"))
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "elio/app_icon")
            .setMethodCallHandler { call, result ->
                if (call.method != "setDark") return@setMethodCallHandler result.notImplemented()
                pendingDarkIcon = call.arguments as Boolean
                result.success(null)
            }
    }

    // Disabling the alias the app was opened through closes its window (seen on
    // the Edge 60 Fusion), so the icon switches when the app leaves the screen.
    private var pendingDarkIcon: Boolean? = null

    override fun onStop() {
        super.onStop()
        val dark = pendingDarkIcon ?: return
        pendingDarkIcon = null
        val (on, off) = if (dark) "LauncherDark" to "LauncherLight" else "LauncherLight" to "LauncherDark"
        setAlias(on, true)
        setAlias(off, false)
    }

    // Called with the new alias first, so a launcher entry always exists.
    private fun setAlias(name: String, on: Boolean) {
        val state = if (on) PackageManager.COMPONENT_ENABLED_STATE_ENABLED else PackageManager.COMPONENT_ENABLED_STATE_DISABLED
        val component = ComponentName(this, "$packageName.$name")
        if (packageManager.getComponentEnabledSetting(component) == state) return
        packageManager.setComponentEnabledSetting(component, state, PackageManager.DONT_KILL_APP)
    }
}
