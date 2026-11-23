package com.codecore.player

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.os.Process

/**
 * Runs in the `:restart` process: kills the main process (`pid` extra), starts
 * the launcher activity in a fresh task and exits. Started by [RestartChannel].
 */
class RestartActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Process.killProcess(intent.getIntExtra("pid", -1))
        packageManager.getLaunchIntentForPackage(packageName)?.let {
            startActivity(it.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK))
        }
        finish()
        Runtime.getRuntime().exit(0)
    }
}
