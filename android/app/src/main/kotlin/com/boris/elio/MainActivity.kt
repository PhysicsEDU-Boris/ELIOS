package com.boris.elio

import android.app.ActivityManager
import android.app.UiModeManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Debug
import android.os.PowerManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    // Dark mode is an in-app choice (decision 0130). Android needs the per-app night
    // mode for the next cold start's launch screen, and the launcher alias for the icon.
    // Swapping the alias closes the running app on some launchers, so it waits for onStop.
    private var pendingIconDark: Boolean? = null

    private fun applyAppearance(dark: Boolean) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            (getSystemService(Context.UI_MODE_SERVICE) as UiModeManager).setApplicationNightMode(
                if (dark) UiModeManager.MODE_NIGHT_YES else UiModeManager.MODE_NIGHT_NO
            )
        }
        pendingIconDark = dark
    }

    private fun alias(name: String) = ComponentName(packageName, "$packageName.$name")

    private fun aliasEnabled(name: String, manifestDefault: Boolean): Boolean =
        when (packageManager.getComponentEnabledSetting(alias(name))) {
            PackageManager.COMPONENT_ENABLED_STATE_ENABLED -> true
            PackageManager.COMPONENT_ENABLED_STATE_DISABLED -> false
            else -> manifestDefault
        }

    private fun swapLauncherIcon(dark: Boolean) {
        val on = if (dark) "LauncherDark" else "LauncherLight"
        val off = if (dark) "LauncherLight" else "LauncherDark"
        if (aliasEnabled(on, !dark) && !aliasEnabled(off, dark)) return
        // Enable the new entry first so the app is never without a launcher entry.
        packageManager.setComponentEnabledSetting(
            alias(on), PackageManager.COMPONENT_ENABLED_STATE_ENABLED, PackageManager.DONT_KILL_APP
        )
        packageManager.setComponentEnabledSetting(
            alias(off), PackageManager.COMPONENT_ENABLED_STATE_DISABLED, PackageManager.DONT_KILL_APP
        )
    }

    override fun onStop() {
        super.onStop()
        pendingIconDark?.let {
            pendingIconDark = null
            swapLauncherIcon(it)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "elio/appearance")
            .setMethodCallHandler { call, result ->
                if (call.method == "setDark") {
                    applyAppearance(call.arguments as Boolean)
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
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
    }
}
