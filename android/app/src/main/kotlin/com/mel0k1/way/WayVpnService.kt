package com.mel0k1.way

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.net.VpnService
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.ParcelFileDescriptor
import android.os.SystemClock
import android.widget.RemoteViews
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
        private val brandColor: Int = 0xFF2E7D53.toInt()

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
    private var connectStartMs = 0L
    private var foregroundShown = false
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
        try {
            if (intent == null) {
                handleNullIntent()
                return START_STICKY
            }
            if (intent.getBooleanExtra("restore", false)) {
                startForegroundCompat(getString(R.string.nt_connecting))
                restoreConfig()
                return START_STICKY
            }
            if (intent.getBooleanExtra("stop", false)) {
                ensureForeground()
                desired = false
                clearSavedConfig()
                stopCore()
                stopSelf()
                return START_NOT_STICKY
            }
            val engine = intent.getStringExtra("engine") ?: run {
                stopSelf()
                return START_NOT_STICKY
            }
            splitMode = intent.getStringExtra("split_mode") ?: "off"
            splitApps = intent.getStringExtra("split_apps")
                ?.split(",")
                ?.map { it.trim() }
                ?.filter { it.isNotEmpty() }
                .orEmpty()
            startForegroundCompat(getString(R.string.nt_connecting))
            startCore(
                engine = engine,
                singboxConfig = intent.getStringExtra("singbox") ?: "",
                xrayConfig = intent.getStringExtra("xray") ?: "",
                bridgeConfig = intent.getStringExtra("bridge") ?: "",
            )
            return START_STICKY
        } catch (e: Throwable) {
            setState(STATE_STOPPED, e.message ?: e.toString())
            try {
                stopCore()
            } catch (_: Throwable) {
            }
            try {
                stopSelf()
            } catch (_: Throwable) {
            }
            return START_NOT_STICKY
        }
    }

    private fun handleNullIntent() {
        try {
            val prefs = getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            if (prefs.getString("engine", null) == null) {
                stopSelf()
                return
            }
            restoreConfig()
        } catch (e: Throwable) {
            setState(STATE_STOPPED, e.message ?: e.toString())
            try {
                stopSelf()
            } catch (_: Throwable) {
            }
        }
    }

    private fun ensureForeground() {
        if (foregroundShown) return
        try {
            startForegroundCompat(getString(R.string.nt_disconnecting))
        } catch (_: Throwable) {
        }
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

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channel = NotificationChannel(
            CHANNEL_ID,
            getString(R.string.nt_channel_name),
            NotificationManager.IMPORTANCE_LOW,
        )
        manager.createNotificationChannel(channel)
    }

    private fun buildNotification(statusText: String, showTimer: Boolean): Notification {
        val views = RemoteViews(packageName, R.layout.notification_way)
        views.setTextViewText(R.id.nt_status, statusText)
        if (showTimer && connectStartMs > 0) {
            views.setViewVisibility(R.id.nt_timer, android.view.View.VISIBLE)
            views.setChronometer(R.id.nt_timer, connectStartMs, null, true)
        } else {
            views.setViewVisibility(R.id.nt_timer, android.view.View.GONE)
        }
        views.setOnClickPendingIntent(
            R.id.nt_action,
            PendingIntent.getService(
                this,
                1,
                Intent(this, WayVpnService::class.java).putExtra("stop", true),
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            ),
        )
        val contentIntent = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java).setFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        return builder
            .setSmallIcon(R.drawable.ic_stat_way)
            .setContent(views)
            .setContentIntent(contentIntent)
            .setColor(brandColor)
            .setColorized(true)
            .setOngoing(true)
            .build()
    }

    private fun showNotification(statusText: String, showTimer: Boolean) {
        try {
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.notify(NOTIFICATION_ID, buildNotification(statusText, showTimer))
        } catch (_: Throwable) {
        }
    }

    private fun startForegroundCompat(statusText: String) {
        ensureChannel()
        val notification = buildNotification(statusText, false)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
        foregroundShown = true
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
            connectStartMs = SystemClock.elapsedRealtime()
            showNotification(getString(R.string.nt_connected), true)
            watchdog.removeCallbacks(watchdogTick)
            watchdog.postDelayed(watchdogTick, 5000)
        } catch (e: Throwable) {
            setState(STATE_STOPPED, e.message ?: e.toString())
            stopCore()
            val err = lastError
            showNotification(
                if (err.isNullOrBlank()) getString(R.string.nt_disconnected)
                else "${getString(R.string.nt_disconnected)} · ${err.take(80)}",
                false,
            )
        }
    }

    private fun restoreConfig() {
        try {
            val prefs = getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val engine = prefs.getString("engine", null) ?: return
            val singbox = prefs.getString("singbox", null) ?: return
            splitMode = prefs.getString("split_mode", null) ?: "off"
            splitApps = prefs.getString("split_apps", null)
                ?.split(",")
                ?.filter { it.isNotBlank() }
                .orEmpty()
            startForegroundCompat(getString(R.string.nt_connecting))
            startCore(
                engine = engine,
                singboxConfig = singbox,
                xrayConfig = prefs.getString("xray", null) ?: "",
                bridgeConfig = prefs.getString("bridge", null) ?: "",
            )
        } catch (e: Throwable) {
            setState(STATE_STOPPED, e.message ?: e.toString())
            try {
                stopSelf()
            } catch (_: Throwable) {
            }
        }
    }

    private fun saveConfig(engine: String, singbox: String, xray: String, bridge: String) {
        getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putString("engine", engine)
            .putString("singbox", singbox)
            .putString("xray", xray)
            .putString("bridge", bridge)
            .putString("split_mode", splitMode)
            .putString("split_apps", splitApps.joinToString(","))
            .apply()
    }

    private fun clearSavedConfig() {
        getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().clear().apply()
    }

    private fun stopCore() {
        setState(STATE_STOPPING)
        showNotification(getString(R.string.nt_disconnecting), false)
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
        foregroundShown = false
        setState(STATE_STOPPED)
    }

    override fun autoDetectInterfaceControl(fd: Int) {
        protect(fd)
    }

    override fun openTun(config: TunConfig): Int {
        if (prepare(this) != null) error("missing vpn permission")
        val builder = Builder()
            .setSession("Way")
            .setMtu(config.getMTU())
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
        addPrefixes(config.getInet4Addresses()) { addr, prefix -> builder.addAddress(addr, prefix) }
        addPrefixes(config.getInet6Addresses()) { addr, prefix -> builder.addAddress(addr, prefix) }
        if (config.getAutoRoute()) {
            val dns = config.getDNSServers()
            while (dns.hasNext()) {
                builder.addDnsServer(dns.next())
            }
        }
        val routes4 = config.getInet4Routes()
        if (routes4.hasNext()) {
            addPrefixes(routes4) { addr, prefix -> builder.addRoute(addr, prefix) }
        } else if (config.getInet4Addresses().hasNext()) {
            builder.addRoute("0.0.0.0", 0)
        }
        val routes6 = config.getInet6Routes()
        if (routes6.hasNext()) {
            addPrefixes(routes6) { addr, prefix -> builder.addRoute(addr, prefix) }
        } else if (config.getInet6Addresses().hasNext()) {
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
