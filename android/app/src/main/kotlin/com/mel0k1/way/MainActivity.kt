package com.mel0k1.way

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.VpnService
import android.os.Build
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
                else -> result.notImplemented()
            }
        }
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
