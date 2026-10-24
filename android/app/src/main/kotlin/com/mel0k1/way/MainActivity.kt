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
    private val pendingResults = mutableListOf<MethodChannel.Result>()
    private var pendingConfig: Map<String, String> = emptyMap()
    private var pendingLink: String? = null
    private var channel: MethodChannel? = null
    private var waitingPermission = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "way/core",
        ).also { ch ->
            ch.setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> {
                        pendingConfig = call.arguments<Map<String, String>>() ?: emptyMap()
                        pendingResults.add(result)
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
                    "take_link" -> {
                        val link = pendingLink
                        pendingLink = null
                        result.success(link)
                    }
                    else -> result.notImplemented()
                }
            }
        }
        takeDeepLink(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        takeDeepLink(intent)
    }

    private fun takeDeepLink(intent: Intent?) {
        val data = intent?.data?.toString() ?: return
        if (!data.contains("://")) return
        val handler = channel
        if (handler != null) {
            try {
                handler.invokeMethod("on_link", data)
            } catch (_: Exception) {
                pendingLink = data
            }
        } else {
            pendingLink = data
        }
    }

    private fun installedApps(): List<Map<String, String>> {
        val pm = packageManager
        val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        val activities = try {
            pm.queryIntentActivities(intent, 0)
        } catch (_: Exception) {
            emptyList()
        }
        val apps = LinkedHashMap<String, Map<String, String>>()
        for (info in activities) {
            val pkg = info.activityInfo?.packageName ?: continue
            if (pkg == packageName || apps.containsKey(pkg)) continue
            val label = try {
                info.loadLabel(pm)?.toString() ?: pkg
            } catch (_: Exception) {
                pkg
            }
            apps[pkg] = mapOf(
                "label" to label,
                "package" to pkg,
            )
        }
        return apps.values.toList()
    }

    private fun launchVpn() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.POST_NOTIFICATIONS,
            ) != PackageManager.PERMISSION_GRANTED
        ) {
            if (waitingPermission) return
            waitingPermission = true
            try {
                requestPermissions(
                    arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                    101,
                )
            } catch (_: Exception) {
                waitingPermission = false
                prepareAndStart()
            }
            return
        }
        prepareAndStart()
    }

    private fun prepareAndStart() {
        if (pendingResults.isEmpty()) return
        val intent = try {
            VpnService.prepare(this)
        } catch (_: Exception) {
            replyPending(mapOf("started" to false))
            return
        }
        if (intent != null) {
            try {
                startActivityForResult(intent, 100)
            } catch (_: Exception) {
                replyPending(mapOf("started" to false))
            }
        } else {
            startVpnService()
        }
    }

    private fun startVpnService() {
        val intent = Intent(this, WayVpnService::class.java)
        for ((key, value) in pendingConfig) {
            intent.putExtra(key, value)
        }
        try {
            ContextCompat.startForegroundService(this, intent)
            replyPending(mapOf("started" to true))
        } catch (e: Exception) {
            replyPending(mapOf("started" to false))
        }
    }

    private fun replyPending(value: Map<String, Any>) {
        val results = pendingResults.toList()
        pendingResults.clear()
        for (result in results) {
            try {
                result.success(value)
            } catch (_: Exception) {
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == 100) {
            if (resultCode == RESULT_OK) {
                startVpnService()
            } else {
                replyPending(mapOf("started" to false))
            }
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 101) {
            waitingPermission = false
            prepareAndStart()
        }
    }
}
