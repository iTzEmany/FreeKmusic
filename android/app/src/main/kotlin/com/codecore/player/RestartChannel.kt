package com.codecore.player

import android.content.Context
import android.content.Intent
import android.os.Process
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * `codecore/restart`: `restart` hands over to [RestartActivity] (another
 * process), which kills this one and starts the app again. Replies false when
 * there is no launch intent. Services die with the process.
 */
object RestartChannel {
    fun register(messenger: BinaryMessenger, context: Context) {
        MethodChannel(messenger, "codecore/restart").setMethodCallHandler { call, result ->
            if (call.method != "restart") return@setMethodCallHandler result.notImplemented()
            if (context.packageManager.getLaunchIntentForPackage(context.packageName) == null) {
                return@setMethodCallHandler result.success(false)
            }
            context.startActivity(
                Intent(context, RestartActivity::class.java)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    .putExtra("pid", Process.myPid())
            )
            result.success(true)
        }
    }
}
