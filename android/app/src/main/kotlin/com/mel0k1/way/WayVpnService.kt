package com.mel0k1.way

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.net.VpnService
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.ParcelFileDescriptor
import io.mel0k1.waycore.CommandServer
import io.mel0k1.waycore.PlatformInterface
import io.mel0k1.waycore.StringIterator
import io.mel0k1.waycore.TunConfig
import io.mel0k1.waycore.Waycore

class WayVpnService : VpnService(), PlatformInterface {
    companion object {
        const val STATE_STOPPED = "stopped"
        const val STATE_STARTING = "starting"
        const val STATE_STARTED = "started"
        const val STATE_STOPPING = "stopping"
        private const val CHANNEL_ID = "way_vpn"
        private const val NOTIFICATION_ID = 7
        private const val PREFS = "way_vpn"
        private const val MAX_RESTARTS = 10

        @Volatile
        var state: String = STATE_STOPPED
            private set

        @Volatile
        var lastError: String? = null
            private set

        fun setState(value: String, error: String? = null) {
            state = value
            lastError = error
        }
    }

    private var commandServer: CommandServer? = null
    private var tunFd: ParcelFileDescriptor? = null
    private var desired = false
    private var splitMode = "off"
    private var splitApps = emptyList<String>()
    private var restartAttempts = 0
    private val watchdog = Handler(Looper.getMainLooper())
    private val watchdogTick = object : Runnable {
        override fun run() {
            if (desired && commandServer == null) {
                if (restartAttempts >= MAX_RESTARTS) {
                    desired = false
                    setState(STATE_STOPPED, "watchdog gave up")
                    return
                }
                restartAttempts++
                restoreConfig()
            }
            if (desired) {
                watchdog.postDelayed(this, 5000)
            }
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent == null) {
            restoreConfig()
            return START_STICKY
        }
        if (intent.getBooleanExtra("stop", false)) {
            desired = false
            clearSavedConfig()
            stopCore()
            stopSelf()
            return START_NOT_STICKY
        }
        val engine = intent.getStringExtra("engine") ?: return START_NOT_STICKY
        splitMode = intent.getStringExtra("split_mode") ?: "off"
        splitApps = intent.getStringExtra("split_apps")
            ?.split(",")
            ?.map { it.trim() }
            ?.filter { it.isNotEmpty() }
            .orEmpty()
        startForegroundCompat()
        startCore(
            engine = engine,
            singboxConfig = intent.getStringExtra("singbox") ?: "",
            xrayConfig = intent.getStringExtra("xray") ?: "",
            bridgeConfig = intent.getStringExtra("bridge") ?: "",
        )
        return START_STICKY
    }

    override fun onDestroy() {
        stopCore()
        super.onDestroy()
    }

    override fun onRevoke() {
        desired = false
        clearSavedConfig()
        stopCore()
        stopSelf()
    }

    private fun startForegroundCompat() {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Way VPN",
                NotificationManager.IMPORTANCE_LOW,
            )
            manager.createNotificationChannel(channel)
        }
        val notification: Notification = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
                .setContentTitle("Way")
                .setContentText(getString(R.string.app_name))
                .setSmallIcon(android.R.drawable.stat_notify_sync_noanim)
                .setOngoing(true)
                .build()
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
                .setContentTitle("Way")
                .setSmallIcon(android.R.drawable.stat_notify_sync_noanim)
                .setOngoing(true)
                .build()
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_SPECIAL_USE,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun startCore(
        engine: String,
        singboxConfig: String,
        xrayConfig: String,
        bridgeConfig: String,
    ) {
        if (commandServer != null) {
            stopCore()
        }
        try {
            setState(STATE_STARTING)
            if (engine == "xray" && xrayConfig.isNotEmpty()) {
                Waycore.startXray(xrayConfig)
            }
            val server = Waycore.newCommandServer(this)
            server.start()
            val activeConfig = if (engine == "xray") bridgeConfig else singboxConfig
            server.startOrReloadService(activeConfig)
            commandServer = server
            desired = true
            restartAttempts = 0
            saveConfig(engine, singboxConfig, xrayConfig, bridgeConfig)
            setState(STATE_STARTED)
            watchdog.removeCallbacks(watchdogTick)
            watchdog.postDelayed(watchdogTick, 5000)
        } catch (e: Throwable) {
            setState(STATE_STOPPED, e.message ?: e.toString())
            stopCore()
        }
    }

    private fun restoreConfig() {
        val prefs = getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val engine = prefs.getString("engine", null) ?: return
        val singbox = prefs.getString("singbox", null) ?: return
        splitMode = prefs.getString("split_mode", null) ?: "off"
        splitApps = prefs.getString("split_apps", null)
            ?.split(",")
            ?.filter { it.isNotBlank() }
            .orEmpty()
        startForegroundCompat()
        startCore(
            engine = engine,
            singboxConfig = singbox,
            xrayConfig = prefs.getString("xray", null) ?: "",
            bridgeConfig = prefs.getString("bridge", null) ?: "",
        )
    }

    private fun saveConfig(engine: String, singbox: String, xray: String, bridge: String) {
        getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putString("engine", engine)
            .putString("singbox", singbox)
            .putString("xray", xray)
            .putString("bridge", bridge)
            .putString("split_mode", splitMode)
            .putString("split_apps", splitApps.join(","))
            .apply()
    }

    private fun clearSavedConfig() {
        getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().clear().apply()
    }

    private fun stopCore() {
        setState(STATE_STOPPING)
        watchdog.removeCallbacks(watchdogTick)
        val server = commandServer
        commandServer = null
        if (server != null) {
            try {
                server.closeService()
            } catch (_: Throwable) {
            }
            try {
                server.close()
            } catch (_: Throwable) {
            }
        }
        try {
            if (Waycore.xrayRunning()) {
                Waycore.stopXray()
            }
        } catch (_: Throwable) {
        }
        val pfd = tunFd
        tunFd = null
        try {
            pfd?.close()
        } catch (_: Throwable) {
        }
        setState(STATE_STOPPED)
    }

    override fun autoDetectInterfaceControl(fd: Int) {
        protect(fd)
    }

    override fun openTun(config: TunConfig): Int {
        if (prepare(this) != null) error("missing vpn permission")
        val builder = Builder()
            .setSession("Way")
            .setMtu(config.mtu)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            builder.setMetered(false)
        }
        if (splitMode == "include" && splitApps.isNotEmpty()) {
            for (pkg in splitApps) {
                try {
                    builder.addAllowedApplication(pkg)
                } catch (_: Throwable) {
                }
            }
        } else if (splitMode == "exclude" && splitApps.isNotEmpty()) {
            for (pkg in splitApps) {
                try {
                    builder.addDisallowedApplication(pkg)
                } catch (_: Throwable) {
                }
            }
        }
        addPrefixes(config.inet4Addresses) { addr, prefix -> builder.addAddress(addr, prefix) }
        addPrefixes(config.inet6Addresses) { addr, prefix -> builder.addAddress(addr, prefix) }
        if (config.autoRoute) {
            val dns = config.dnsServers
            while (dns.hasNext()) {
                builder.addDnsServer(dns.next())
            }
        }
        val routes4 = config.inet4Routes
        if (routes4.hasNext()) {
            addPrefixes(routes4) { addr, prefix -> builder.addRoute(addr, prefix) }
        } else if (config.inet4Addresses.hasNext()) {
            builder.addRoute("0.0.0.0", 0)
        }
        val routes6 = config.inet6Routes
        if (routes6.hasNext()) {
            addPrefixes(routes6) { addr, prefix -> builder.addRoute(addr, prefix) }
        } else if (config.inet6Addresses.hasNext()) {
            builder.addRoute("::", 0)
        }
        val pfd = builder.establish() ?: error("vpn establish failed")
        tunFd = pfd
        return pfd.fd
    }

    private inline fun addPrefixes(iterator: StringIterator, add: (String, Int) -> Unit) {
        while (iterator.hasNext()) {
            val prefix = iterator.next().split("/")
            if (prefix.size == 2) {
                add(prefix[0], prefix[1].toIntOrNull() ?: 0)
            }
        }
    }
}
