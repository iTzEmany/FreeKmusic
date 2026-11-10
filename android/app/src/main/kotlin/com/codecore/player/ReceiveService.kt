package com.codecore.player

import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder

/**
 * Keeps the process alive while "receive from the local network" is on, so
 * the Dart side can keep announcing itself and accept offers. Stopped from the
 * setting or from the notification's own button.
 */
class ReceiveService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val title = intent?.getStringExtra("title") ?: "FreeKmusic"
        val text = intent?.getStringExtra("text") ?: ""
        val disable = intent?.getStringExtra("disable") ?: "Stop"
        val n = ShareNotifications.serviceNotification(this, title, text, disable)
        if (Build.VERSION.SDK_INT >= 34) {
            startForeground(ShareNotifications.SERVICE_ID, n,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(ShareNotifications.SERVICE_ID, n)
        }
        // Not sticky: a restarted process would have no Dart side to serve.
        return START_NOT_STICKY
    }

    companion object {
        fun start(ctx: Context, title: String, text: String, disable: String) {
            val i = Intent(ctx, ReceiveService::class.java)
                .putExtra("title", title).putExtra("text", text).putExtra("disable", disable)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) ctx.startForegroundService(i)
            else ctx.startService(i)
        }

        fun stop(ctx: Context) {
            ctx.stopService(Intent(ctx, ReceiveService::class.java))
        }
    }
}
