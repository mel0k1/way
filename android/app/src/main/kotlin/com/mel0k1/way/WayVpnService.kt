package com.mel0k1.way

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.net.VpnService
import android.os.Build
import android.os.IBinder
import android.os.ParcelFileDescriptor
import io.mel0k1.libbox.BridgeOptions
import io.mel0k1.libbox.BridgeSession
import io.mel0k1.libbox.CommandServer
import io.mel0k1.libbox.CommandServerHandler
import io.mel0k1.libbox.ConnectionOwner
import io.mel0k1.libbox.InterfaceUpdateListener
import io.mel0k1.libbox.LocalDNSTransport
import io.mel0k1.libbox.NeighborUpdateListener
import io.mel0k1.libbox.NetworkInterfaceIterator
import io.mel0k1.libbox.Notification as BoxNotification
import io.mel0k1.libbox.OverrideOptions
import io.mel0k1.libbox.PlatformInterface
import io.mel0k1.libbox.PlatformUser
import io.mel0k1.libbox.ShellSession
import io.mel0k1.libbox.StringIterator
import io.mel0k1.libbox.SystemProxyStatus
import io.mel0k1.libbox.TunOptions
import io.mel0k1.libbox.WIFIState
import io.mel0k1.waycore.Waycore
import java.net.NetworkInterface as JavaNetworkInterface

class WayVpnService : VpnService(), PlatformInterface, CommandServerHandler {
    companion object {
        const val STATE_STOPPED = "stopped"
        const val STATE_STARTING = "starting"
        const val STATE_STARTED = "started"
        const val STATE_STOPPING = "stopping"
        private const val CHANNEL_ID = "way_vpn"
        private const val NOTIFICATION_ID = 7

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
    private var fileDescriptor: ParcelFileDescriptor? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.getBooleanExtra("stop", false) == true) {
            stopCore()
            stopSelf()
            return START_NOT_STICKY
        }
        val engine = intent?.getStringExtra("engine") ?: return START_NOT_STICKY
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
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE,
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
            val server = Waycore.newCommandServer(this, this)
            server.start()
            val activeConfig = if (engine == "xray") bridgeConfig else singboxConfig
            server.startOrReloadService(activeConfig, OverrideOptions())
            commandServer = server
            setState(STATE_STARTED)
        } catch (e: Throwable) {
            setState(STATE_STOPPED, e.message ?: e.toString())
            stopCore()
        }
    }

    private fun stopCore() {
        setState(STATE_STOPPING)
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
        val pfd = fileDescriptor
        fileDescriptor = null
        try {
            pfd?.close()
        } catch (_: Throwable) {
        }
        setState(STATE_STOPPED)
    }

    override fun autoDetectInterfaceControl(fd: Int) {
        protect(fd)
    }

    override fun openTun(options: TunOptions): Int {
        if (prepare(this) != null) error("missing vpn permission")
        val builder = Builder()
            .setSession("Way")
            .setMtu(options.mtu)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            builder.setMetered(false)
        }
        val inet4 = options.inet4Address
        while (inet4.hasNext()) {
            val addr = inet4.next()
            builder.addAddress(addr.address(), addr.prefix())
        }
        val inet6 = options.inet6Address
        while (inet6.hasNext()) {
            val addr = inet6.next()
            builder.addAddress(addr.address(), addr.prefix())
        }
        if (options.autoRoute) {
            val dns = options.dnsServerAddress
            while (dns.hasNext()) {
                builder.addDnsServer(dns.next())
            }
            val v4Routes = options.inet4RouteAddress
            if (v4Routes.hasNext()) {
                while (v4Routes.hasNext()) {
                    val r = v4Routes.next()
                    builder.addRoute(r.address(), r.prefix())
                }
            } else if (options.inet4Address.hasNext()) {
                builder.addRoute("0.0.0.0", 0)
            }
            val v6Routes = options.inet6RouteAddress
            if (v6Routes.hasNext()) {
                while (v6Routes.hasNext()) {
                    val r = v6Routes.next()
                    builder.addRoute(r.address(), r.prefix())
                }
            } else if (options.inet6Address.hasNext()) {
                builder.addRoute("::", 0)
            }
        }
        val pfd = builder.establish() ?: error("vpn establish failed")
        fileDescriptor = pfd
        return pfd.fd
    }

    override fun usePlatformAutoDetectInterfaceControl(): Boolean = true

    override fun useProcFS(): Boolean = true

    override fun localDNSTransport(): LocalDNSTransport? = null

    override fun findConnectionOwner(
        ipProtocol: Int,
        sourceAddress: String?,
        sourcePort: Int,
        destinationAddress: String?,
        destinationPort: Int
    ): ConnectionOwner = error("connection owner lookup is not supported")

    override fun startDefaultInterfaceMonitor(listener: InterfaceUpdateListener?) {}

    override fun closeDefaultInterfaceMonitor(listener: InterfaceUpdateListener?) {}

    override fun getInterfaces(): NetworkInterfaceIterator {
        val list = mutableListOf<io.mel0k1.libbox.NetworkInterface>()
        val interfaces = JavaNetworkInterface.getNetworkInterfaces()
        while (interfaces?.hasMoreElements() == true) {
            val nif = interfaces.nextElement()
            val item = io.mel0k1.libbox.NetworkInterface()
            item.name = nif.name
            item.index = nif.index
            item.mtu = try { nif.mtu } catch (_: Exception) { 0 }
            item.addresses = StringIteratorImpl(
                nif.interfaceAddresses.mapNotNull { it.address.hostAddress }.iterator()
            )
            item.flags = 0
            list.add(item)
        }
        return NetworkInterfaceIteratorImpl(list.iterator())
    }

    override fun underNetworkExtension(): Boolean = false

    override fun includeAllNetworks(): Boolean = false

    override fun readWIFIState(): WIFIState? = null

    override fun clearDNSCache() {}

    override fun sendNotification(notification: BoxNotification?) {}

    override fun cancelNotification(identifier: String?, typeID: Int) {}

    override fun startNeighborMonitor(listener: NeighborUpdateListener?) {}

    override fun closeNeighborMonitor(listener: NeighborUpdateListener?) {}

    override fun registerMyInterface(name: String?) {}

    override fun usePlatformShell(): Boolean = false

    override fun checkPlatformShell() {}

    override fun openShellSession(
        user: PlatformUser?,
        command: String?,
        environ: StringIterator?,
        term: String?,
        rows: Int,
        cols: Int
    ): ShellSession = error("shell sessions are not supported")

    override fun lookupUser(username: String?): PlatformUser = error("user lookup is not supported")

    override fun lookupSFTPServer(): String = error("sftp is not supported")

    override fun readSystemSSHHostKey(): String = error("ssh host keys are not supported")

    override fun tailscaleHostname(): String = ""

    override fun usePlatformBridge(): Boolean = false

    override fun createBridge(options: BridgeOptions?): BridgeSession = error("bridge is not supported")

    override fun serviceStop() {
        stopCore()
    }

    override fun serviceReload() {}

    override fun getSystemProxyStatus(): SystemProxyStatus? = null

    override fun setSystemProxyEnabled(enabled: Boolean) {}

    override fun triggerNativeCrash() {
        throw IllegalStateException("triggered")
    }

    override fun writeDebugMessage(message: String?) {}

    override fun connectSSHAgent(): Int = error("ssh agent is not supported")
}

class StringIteratorImpl(private val iterator: Iterator<String>) : StringIterator {
    override fun hasNext(): Boolean = iterator.hasNext()
    override fun next(): String = iterator.next()
    override fun len(): Int = 0
}

class NetworkInterfaceIteratorImpl(
    private val iterator: Iterator<io.mel0k1.libbox.NetworkInterface>
) : NetworkInterfaceIterator {
    override fun hasNext(): Boolean = iterator.hasNext()
    override fun next(): io.mel0k1.libbox.NetworkInterface = iterator.next()
}
