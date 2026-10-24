package com.mel0k1.way

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.net.VpnService
import android.os.Build
import android.provider.Settings
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var pendingResult: MethodChannel.Result? = null
    private var pendingConfig: Map<String, String> = emptyMap()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "way/core",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    pendingConfig = call.arguments<Map<String, String>>() ?: emptyMap()
                    pendingResult = result
                    launchVpn()
                }
                "stop" -> {
                    val intent = Intent(this, WayVpnService::class.java)
                    intent.putExtra("stop", true)
                    startService(intent)
                    result.success(null)
                }
                "status" -> {
                    result.success(
                        mapOf(
                            "state" to WayVpnService.state,
                            "error" to WayVpnService.lastError,
                        )
                    )
                }
                "vpn_settings" -> {
                    try {
                        startActivity(Intent(Settings.ACTION_VPN_SETTINGS))
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("unavailable", e.message, null)
                    }
                }
                "apps" -> {
                    result.success(installedApps())
                }
                "autostart" -> {
                    val prefs = getSharedPreferences("way_boot", Context.MODE_PRIVATE)
                    result.success(mapOf("enabled" to prefs.getBoolean("autostart", false)))
                }
                "set_autostart" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    getSharedPreferences("way_boot", Context.MODE_PRIVATE)
                        .edit()
                        .putBoolean("autostart", enabled)
                        .apply()
                    result.success(null)
                }
                "open_url" -> {
                    try {
                        val url = call.argument<String>("url")
                        if (url.isNullOrBlank()) throw IllegalArgumentException("url required")
                        startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("unavailable", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun installedApps(): List<Map<String, String>> {
        val pm = packageManager
        val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        val activities = pm.queryIntentActivities(intent, 0)
        val apps = LinkedHashMap<String, Map<String, String>>()
        for (info in activities) {
            val pkg = info.activityInfo.packageName ?: continue
            if (pkg == packageName || apps.containsKey(pkg)) continue
            apps[pkg] = mapOf(
                "label" to (info.loadLabel(pm)?.toString() ?: pkg),
                "package" to pkg,
            )
        }
        return apps.values.toList()
    }

    private fun launchVpn() {
        val intent = VpnService.prepare(this)
        if (intent != null) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                val granted = ContextCompat.checkSelfPermission(
                    this,
                    Manifest.permission.POST_NOTIFICATIONS,
                ) == PackageManager.PERMISSION_GRANTED
                if (!granted) {
                    requestPermissions(
                        arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                        101,
                    )
                }
            }
            startActivityForResult(intent, 100)
        } else {
            startVpnService()
        }
    }

    private fun startVpnService() {
        val intent = Intent(this, WayVpnService::class.java)
        for ((key, value) in pendingConfig) {
            intent.putExtra(key, value)
        }
        ContextCompat.startForegroundService(this, intent)
        pendingResult?.success(mapOf("started" to true))
        pendingResult = null
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == 100) {
            if (resultCode == RESULT_OK) {
                startVpnService()
            } else {
                pendingResult?.success(mapOf("started" to false))
                pendingResult = null
            }
        }
    }
}
