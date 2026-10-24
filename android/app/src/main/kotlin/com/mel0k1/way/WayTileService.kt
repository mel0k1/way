package com.mel0k1.way

import android.app.PendingIntent
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import androidx.core.content.ContextCompat

class WayTileService : TileService() {

    override fun onStartListening() {
        updateTile()
    }

    override fun onClick() {
        super.onClick()
        try {
            when (WayVpnService.state) {
                WayVpnService.STATE_STARTED -> {
                    val stop = Intent(this, WayVpnService::class.java).putExtra("stop", true)
                    startService(stop)
                    qsTile.state = Tile.STATE_INACTIVE
                    qsTile.updateTile()
                    return
                }
                WayVpnService.STATE_STARTING, WayVpnService.STATE_STOPPING -> {
                    qsTile.updateTile()
                    return
                }
                else -> {}
            }
            val prefs = getSharedPreferences("way_vpn", MODE_PRIVATE)
            val saved = prefs.getString("engine", null)
            val prepared = saved != null && VpnService.prepare(this) == null
            if (prepared) {
                val intent = Intent(this, WayVpnService::class.java).putExtra("restore", true)
                var started = false
                try {
                    ContextCompat.startForegroundService(this, intent)
                    started = true
                } catch (_: Throwable) {
                    started = false
                }
                if (started) {
                    qsTile.state = Tile.STATE_ACTIVE
                    qsTile.updateTile()
                    return
                }
            }
            openApp()
        } catch (_: Throwable) {
        }
        updateTile()
    }

    private fun openApp() {
        try {
            val launch = packageManager.getLaunchIntentForPackage(packageName)
                ?: Intent(this, MainActivity::class.java)
            launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val pending = PendingIntent.getActivity(
                    this,
                    0,
                    launch,
                    PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
                )
                startActivityAndCollapse(pending)
            } else {
                @Suppress("DEPRECATION")
                startActivityAndCollapse(launch)
            }
        } catch (_: Throwable) {
        }
    }

    private fun updateTile() {
        try {
            val active = WayVpnService.state == WayVpnService.STATE_STARTED
            qsTile.state = if (active) Tile.STATE_ACTIVE else Tile.STATE_INACTIVE
            qsTile.updateTile()
        } catch (_: Throwable) {
        }
    }
}
