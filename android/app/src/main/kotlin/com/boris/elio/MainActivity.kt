package com.boris.elio

import android.app.ActivityManager
import android.content.Context
import android.content.Intent
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
    }
}
