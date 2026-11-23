package com.codecore.player

import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.os.Process
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * `codecore/restart`: `restart` stops the app's services, starts the launcher
 * activity in a fresh task and kills the process (a real restart, unlike
 * closing the Activity). Replies false when there is no launch intent.
 */
object RestartChannel {
    private val services = listOf(
        "com.ryanheise.audioservice.AudioService",
        "com.codecore.player.ImportService",
        "com.codecore.player.ReceiveService",
    )

    fun register(messenger: BinaryMessenger, context: Context) {
        MethodChannel(messenger, "codecore/restart").setMethodCallHandler { call, result ->
            if (call.method != "restart") return@setMethodCallHandler result.notImplemented()
            val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
            if (launch == null) return@setMethodCallHandler result.success(false)
            services.forEach { context.stopService(Intent().setClassName(context, it)) }
            context.startActivity(launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK))
            result.success(true)
            // Let the reply reach Dart before the process goes.
            Handler(Looper.getMainLooper()).postDelayed({ Process.killProcess(Process.myPid()) }, 300)
        }
    }
}
