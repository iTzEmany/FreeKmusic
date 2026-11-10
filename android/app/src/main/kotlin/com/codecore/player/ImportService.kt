package com.codecore.player

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.net.wifi.WifiManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * Keeps the process alive while an import or downloads run: without a
 * foreground service Android freezes the app a few seconds after it leaves the
 * screen, and everything stops. The notification says how far it is; «Pausa»
 * stops the import. Locks keep the CPU and the Wi-Fi awake with the screen off.
 */
class ImportService : Service() {
    private var wake: PowerManager.WakeLock? = null
    private var wifi: WifiManager.WifiLock? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val n = ImportNotifications.progress(this, ImportNotifications.last)
        if (Build.VERSION.SDK_INT >= 34) {
            startForeground(ImportNotifications.ID, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(ImportNotifications.ID, n)
        }
        running = true
        if (wake == null) {
            wake = (getSystemService(POWER_SERVICE) as PowerManager)
                .newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "codecore:import")
                .apply { setReferenceCounted(false); acquire(6 * 60 * 60 * 1000L) }
        }
        if (wifi == null) {
            @Suppress("DEPRECATION")
            wifi = (applicationContext.getSystemService(WIFI_SERVICE) as WifiManager)
                .createWifiLock(WifiManager.WIFI_MODE_FULL_HIGH_PERF, "codecore:import")
                .apply { setReferenceCounted(false); acquire() }
        }
        // Not sticky: a restarted process would have no Dart side to run the import.
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        running = false
        wake?.takeIf { it.isHeld }?.release()
        wifi?.takeIf { it.isHeld }?.release()
        super.onDestroy()
    }

    companion object {
        @Volatile
        var running = false

        fun show(ctx: Context, p: ImportNotifications.Progress) {
            ImportNotifications.last = p
            if (running) {
                ctx.getSystemService(NotificationManager::class.java)
                    .notify(ImportNotifications.ID, ImportNotifications.progress(ctx, p))
                return
            }
            val i = Intent(ctx, ImportService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) ctx.startForegroundService(i)
            else ctx.startService(i)
        }

        fun stop(ctx: Context) {
            ctx.stopService(Intent(ctx, ImportService::class.java))
        }
    }
}

/** The import's notifications: the one that stays while it runs, the summary at the end. */
object ImportNotifications {
    const val CHANNEL = "import"
    const val ID = 4201
    private const val DONE_ID = 4202
    const val ACTION_PAUSE = "com.codecore.player.IMPORT_PAUSE"

    data class Progress(
        val title: String,
        val text: String,
        val done: Int,
        val total: Int,
        val pauseLabel: String?,
    )

    @Volatile
    var last = Progress("FreeKmusic", "", 0, 0, null)

    private fun builder(ctx: Context): Notification.Builder {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            ctx.getSystemService(NotificationManager::class.java).createNotificationChannel(
                NotificationChannel(CHANNEL, "Importazioni e download", NotificationManager.IMPORTANCE_LOW)
            )
            return Notification.Builder(ctx, CHANNEL)
        }
        @Suppress("DEPRECATION") return Notification.Builder(ctx)
    }

    private fun openApp(ctx: Context): PendingIntent {
        val i = Intent(ctx, MainActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        return PendingIntent.getActivity(ctx, 2, i,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
    }

    fun progress(ctx: Context, p: Progress): Notification {
        val b = builder(ctx)
            .setSmallIcon(R.drawable.ic_stat_codecore)
            .setContentTitle(p.title)
            .setContentText(p.text)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setContentIntent(openApp(ctx))
        if (p.total > 0) b.setProgress(p.total, p.done, false) else b.setProgress(0, 0, true)
        if (p.pauseLabel != null) {
            val pi = PendingIntent.getBroadcast(ctx, 3,
                Intent(ctx, ImportActionReceiver::class.java).setAction(ACTION_PAUSE),
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
            b.addAction(Notification.Action.Builder(
                android.graphics.drawable.Icon.createWithResource(ctx, R.drawable.ic_stat_codecore),
                p.pauseLabel, pi).build())
        }
        return b.build()
    }

    /** A plain notification the user can swipe away: how the import ended. */
    fun finished(ctx: Context, title: String, text: String) {
        val n = builder(ctx)
            .setSmallIcon(R.drawable.ic_stat_codecore)
            .setContentTitle(title)
            .setContentText(text)
            .setStyle(Notification.BigTextStyle().bigText(text))
            .setAutoCancel(true)
            .setContentIntent(openApp(ctx))
            .build()
        ctx.getSystemService(NotificationManager::class.java).notify(DONE_ID, n)
    }
}

/** «Pausa» on the notification. */
class ImportActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != ImportNotifications.ACTION_PAUSE) return
        Handler(Looper.getMainLooper()).post { ImportBridge.channel?.invokeMethod("pause", null) }
    }
}

/** `codecore/import`: Dart says what to show; the notification's button comes back. */
object ImportBridge {
    @Volatile
    var channel: MethodChannel? = null

    fun register(messenger: BinaryMessenger, ctx: Context) {
        val ch = MethodChannel(messenger, "codecore/import")
        channel = ch
        ch.setMethodCallHandler { call, result ->
            when (call.method) {
                "show" -> {
                    ImportService.show(ctx, ImportNotifications.Progress(
                        call.argument<String>("title") ?: "FreeKmusic",
                        call.argument<String>("text") ?: "",
                        call.argument<Int>("done") ?: 0,
                        call.argument<Int>("total") ?: 0,
                        call.argument<String>("pause"),
                    ))
                    result.success(null)
                }
                "stop" -> {
                    ImportService.stop(ctx)
                    result.success(null)
                }
                "finished" -> {
                    ImportNotifications.finished(ctx,
                        call.argument<String>("title") ?: "FreeKmusic",
                        call.argument<String>("text") ?: "")
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
