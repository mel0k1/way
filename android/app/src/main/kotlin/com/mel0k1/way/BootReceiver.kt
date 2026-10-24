package com.mel0k1.way

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.core.content.ContextCompat

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        if (action != Intent.ACTION_BOOT_COMPLETED && action != Intent.ACTION_MY_PACKAGE_REPLACED) {
            return
        }
        val boot = context.getSharedPreferences("way_boot", Context.MODE_PRIVATE)
        if (!boot.getBoolean("autostart", false)) return
        val saved = context.getSharedPreferences("way_vpn", Context.MODE_PRIVATE)
        if (saved.getString("engine", null) == null) return
        try {
            ContextCompat.startForegroundService(
                context,
                Intent(context, WayVpnService::class.java).putExtra("restore", true),
            )
        } catch (_: Throwable) {
        }
    }
}
