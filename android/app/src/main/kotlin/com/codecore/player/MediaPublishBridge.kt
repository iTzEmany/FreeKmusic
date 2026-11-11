package com.codecore.player

import android.content.ContentValues
import android.content.Context
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * `codecore/publish`: `publish({path})` copies a finished download from the
 * private work folder into `Music/FreeKmusic` through MediaStore (IS_PENDING
 * 1 -> 0, the app owns the entry and can rewrite its tags) and answers with
 * the final path, e.g. `/storage/emulated/0/Music/FreeKmusic/Song.m4a`.
 * `subdir` keeps the import's folder under `Music/FreeKmusic`. Called only on
 * Android 11+ (D-567); the work copy is deleted by the caller.
 */
object MediaPublishBridge {
    private const val DIR = "FreeKmusic"
    private val main = Handler(Looper.getMainLooper())

    fun register(messenger: BinaryMessenger, context: Context) {
        MethodChannel(messenger, "codecore/publish").setMethodCallHandler { call, result ->
            if (call.method == "sdk") {
                result.success(Build.VERSION.SDK_INT)
                return@setMethodCallHandler
            }
            if (call.method != "publish") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val path = call.argument<String>("path")
            if (path == null) {
                result.error("args", "path missing", null)
                return@setMethodCallHandler
            }
            Thread {
                try {
                    val out = publish(context, File(path), call.argument<String>("subdir") ?: "")
                    main.post { result.success(out) }
                } catch (e: Exception) {
                    main.post { result.error("publish", e.message, null) }
                }
            }.start()
        }
    }

    // MediaStore only takes audio/* in Music: never the video/* some extensions map to.
    private fun audioMime(ext: String) = when (ext.lowercase()) {
        "mp3" -> "audio/mpeg"
        "flac" -> "audio/flac"
        "opus", "ogg" -> "audio/ogg"
        "webm" -> "audio/webm"
        else -> "audio/mp4"
    }

    private fun publish(context: Context, src: File, subdir: String): String {
        val sub = subdir.split('/').filter { it.isNotEmpty() && it != "." && it != ".." }.joinToString("/")
        val rel = if (sub.isEmpty()) DIR else "$DIR/$sub"
        val mime = audioMime(src.extension)
        val values = ContentValues().apply {
            put(MediaStore.Audio.Media.DISPLAY_NAME, src.name)
            put(MediaStore.Audio.Media.MIME_TYPE, mime)
            put(MediaStore.Audio.Media.RELATIVE_PATH, "${Environment.DIRECTORY_MUSIC}/$rel")
            put(MediaStore.Audio.Media.IS_PENDING, 1)
        }
        val resolver = context.contentResolver
        val uri = resolver.insert(MediaStore.Audio.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY), values)
            ?: throw IllegalStateException("MediaStore refused the insert")
        try {
            resolver.openOutputStream(uri)!!.use { out -> src.inputStream().use { it.copyTo(out) } }
            resolver.update(uri, ContentValues().apply { put(MediaStore.Audio.Media.IS_PENDING, 0) }, null, null)
        } catch (e: Exception) {
            resolver.delete(uri, null, null)
            throw e
        }
        // MediaStore renames a clash («Song (1).m4a»): the real path is what it stored.
        resolver.query(uri, arrayOf(MediaStore.MediaColumns.DATA), null, null, null)?.use {
            if (it.moveToFirst()) return it.getString(0)
        }
        return File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_MUSIC), "$rel/${src.name}").path
    }
}
