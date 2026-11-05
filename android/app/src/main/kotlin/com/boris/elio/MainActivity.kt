package com.boris.elio

import android.content.ContentValues
import android.net.Uri
import android.os.Environment
import android.provider.MediaStore
import java.io.IOException
import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "elio/device_health")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "shareText" -> {
                        val send = Intent(Intent.ACTION_SEND).apply {
                            type = "text/plain"
                            putExtra(Intent.EXTRA_TEXT, call.arguments as String)
                        }
                        startActivity(Intent.createChooser(send, "Bagikan log ELIOS"))
                        result.success(null)
                    }
                    "wifiSettings" -> {
                        // R2 Control: "Wi-Fi settings" on the disconnected state.
                        startActivity(Intent(Settings.ACTION_WIFI_SETTINGS))
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "elio/pdf")
            .setMethodCallHandler { call, result ->
                if (call.method != "saveToDownloads") return@setMethodCallHandler result.notImplemented()
                val args = call.arguments as? Map<*, *>
                val bytes = args?.get("bytes") as? ByteArray
                val name = args?.get("filename") as? String
                if (name == null || name.length > 240 || !Regex("[A-Za-z0-9_-]+\\.pdf").matches(name) ||
                    bytes == null || bytes.size < 5 || !bytes.copyOfRange(0, 5).contentEquals("%PDF-".toByteArray())) {
                    return@setMethodCallHandler result.error("invalid_pdf", "Invalid PDF or filename", null)
                }
                val resolver = applicationContext.contentResolver
                Thread {
                    var created: Uri? = null
                    try {
                        val values = ContentValues().apply {
                            put(MediaStore.MediaColumns.DISPLAY_NAME, name)
                            put(MediaStore.MediaColumns.MIME_TYPE, "application/pdf")
                            put(MediaStore.MediaColumns.RELATIVE_PATH, "${Environment.DIRECTORY_DOWNLOADS}/ELIOS")
                            put(MediaStore.MediaColumns.IS_PENDING, 1)
                        }
                        val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                            ?: throw IOException("Cannot create download")
                        created = uri
                        (resolver.openOutputStream(uri) ?: throw IOException("Cannot open download")).use { it.write(bytes) }
                        values.clear()
                        values.put(MediaStore.MediaColumns.IS_PENDING, 0)
                        if (resolver.update(uri, values, null, null) != 1) throw IOException("Cannot publish download")
                        val actualName = resolver.query(uri, arrayOf(MediaStore.MediaColumns.DISPLAY_NAME), null, null, null)?.use {
                            if (it.moveToFirst()) it.getString(0) else name
                        } ?: name
                        runOnUiThread { result.success("${Environment.DIRECTORY_DOWNLOADS}/ELIOS/$actualName") }
                    } catch (e: Exception) {
                        // Remove only the incomplete file this request created.
                        created?.let { try { resolver.delete(it, null, null) } catch (_: Exception) {} }
                        runOnUiThread { result.error("pdf_save_failed", "PDF belum dapat disimpan ke Download.", null) }
                    }
                }.start()
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
