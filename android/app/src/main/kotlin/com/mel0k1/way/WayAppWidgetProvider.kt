package com.mel0k1.way

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.VpnService
import android.widget.RemoteViews
import androidx.core.content.ContextCompat

/**
 * Home-screen widget: a one-tap VPN switch. Reuses the same `restore` /
 * `stop` service intents as the quick-settings tile, so it works even when
 * the Flutter app process is not running.
 */
class WayAppWidgetProvider : AppWidgetProvider() {

    companion object {
        const val ACTION_TOGGLE = "com.mel0k1.way.action.WIDGET_TOGGLE"

        fun toggleIntent(context: Context): Intent =
            Intent(context, WayAppWidgetProvider::class.java).setAction(ACTION_TOGGLE)

        fun updateAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context) ?: return
            val views = buildViews(context)
            try {
                manager.updateAppWidget(
                    ComponentName(context, WayAppWidgetProvider::class.java),
                    views,
                )
            } catch (_: Throwable) {
            }
        }

        private fun buildViews(context: Context): RemoteViews {
            val views = RemoteViews(context.packageName, R.layout.widget_way)
            val state = WayVpnService.state
            val started = state == WayVpnService.STATE_STARTED
            val waiting = state == WayVpnService.STATE_STARTING ||
                state == WayVpnService.STATE_STOPPING

            views.setTextViewText(
                R.id.widget_status,
                context.getString(
                    when {
                        started -> R.string.widget_on
                        waiting -> R.string.widget_wait
                        else -> R.string.widget_off
                    }
                ),
            )
            views.setInt(
                R.id.widget_root,
                "setBackgroundResource",
                when {
                    started -> R.drawable.widget_bg_on
                    waiting -> R.drawable.widget_bg_wait
                    else -> R.drawable.widget_bg_off
                },
            )
            // Rebind the toggle on every push — fresh RemoteViews lose the
            // previous click handler.
            views.setOnClickPendingIntent(
                R.id.widget_root,
                PendingIntent.getBroadcast(
                    context,
                    0,
                    toggleIntent(context),
                    PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
                ),
            )
            return views
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        val views = buildViews(context)
        for (id in appWidgetIds) {
            try {
                appWidgetManager.updateAppWidget(id, views)
            } catch (_: Throwable) {
            }
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == ACTION_TOGGLE) {
            toggle(context)
        }
        updateAll(context)
    }

    private fun toggle(context: Context) {
        try {
            when (WayVpnService.state) {
                WayVpnService.STATE_STARTED -> {
                    val stop = Intent(context, WayVpnService::class.java)
                        .putExtra("stop", true)
                    context.startService(stop)
                    return
                }
                WayVpnService.STATE_STARTING, WayVpnService.STATE_STOPPING -> return
                else -> {}
            }
            if (VpnService.prepare(context) == null) {
                val restore = Intent(context, WayVpnService::class.java)
                    .putExtra("restore", true)
                try {
                    ContextCompat.startForegroundService(context, restore)
                } catch (_: Throwable) {
                    openApp(context)
                }
            } else {
                // Never prepared before — hand over to the app UI.
                openApp(context)
            }
        } catch (_: Throwable) {
        }
    }

    private fun openApp(context: Context) {
        try {
            val launch = context.packageManager.getLaunchIntentForPackage(
                context.packageName,
            ) ?: Intent(context, MainActivity::class.java)
            launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            context.startActivity(launch)
        } catch (_: Throwable) {
        }
    }
}
