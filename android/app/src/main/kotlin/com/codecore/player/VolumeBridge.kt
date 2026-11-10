package com.codecore.player

import android.content.Context
import android.database.ContentObserver
import android.media.AudioManager
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * `codecore/volume`: `get` answers the media volume as 0..1 (0 = the stream's
 * minimum), `start`/`stop` toggle a ContentObserver on the application context
 * that pushes `changed` (the new 0..1 value) only when the value changes.
 */
object VolumeBridge {
    private var channel: MethodChannel? = null
    private var observer: ContentObserver? = null
    private var resolver: android.content.ContentResolver? = null
    private var last = -1.0

    fun register(messenger: BinaryMessenger, context: Context) {
        val app = context.applicationContext
        val am = app.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        // A new activity on the cached engine re-points the channel; the observer stays.
        val channel = MethodChannel(messenger, "codecore/volume")
        this.channel = channel
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "get" -> result.success(read(am))
                "start" -> {
                    start(app, am)
                    result.success(null)
                }
                "stop" -> {
                    unregister()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun start(app: Context, am: AudioManager) {
        unregister()
        last = read(am)
        val obs = object : ContentObserver(Handler(Looper.getMainLooper())) {
            override fun onChange(selfChange: Boolean) {
                val v = read(am)
                if (v == last) return
                last = v
                channel?.invokeMethod("changed", v)
            }
        }
        observer = obs
        resolver = app.contentResolver.also {
            it.registerContentObserver(Settings.System.CONTENT_URI, true, obs)
        }
    }

    fun unregister() {
        observer?.let { resolver?.unregisterContentObserver(it) }
        observer = null
        resolver = null
    }

    private fun read(am: AudioManager): Double {
        val min = am.getStreamMinVolume(AudioManager.STREAM_MUSIC)
        val max = am.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
        return if (max <= min) 0.0
        else (am.getStreamVolume(AudioManager.STREAM_MUSIC) - min).toDouble() / (max - min)
    }
}
