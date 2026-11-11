package com.codecore.player

import android.content.ContentValues
import android.content.Context
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import android.webkit.MimeTypeMap
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * `codecore/publish`: `publish({path})` copies a finished download from the
 * private work folder into `Music/FreeKmusic` through MediaStore (IS_PENDING
 * 1 -> 0, the app owns the entry and can rewrite its tags) and answers with
 * the final path, e.g. `/storage/emulated/0/Music/FreeKmusic/Song.m4a`.
 * The work copy is deleted by the caller. Android 9 and older copy the file.
 */
object MediaPublishBridge {
    private const val DIR = "FreeKmusic"
    private val main = Handler(Looper.getMainLooper())

    fun register(messenger: BinaryMessenger, context: Context) {
        MethodChannel(messenger, "codecore/publish").setMethodCallHandler { call, result ->
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
                    val out = publish(context, File(path))
                    main.post { result.success(out) }
                } catch (e: Exception) {
                    main.post { result.error("publish", e.message, null) }
                }
            }.start()
        }
    }

    private fun publish(context: Context, src: File): String {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            val dir = File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_MUSIC), DIR)
            dir.mkdirs()
            val dest = File(dir, src.name)
            src.copyTo(dest, overwrite = false)
            android.media.MediaScannerConnection.scanFile(context, arrayOf(dest.path), null, null)
            return dest.path
        }
        val mime = MimeTypeMap.getSingleton().getMimeTypeFromExtension(src.extension.lowercase()) ?: "audio/mp4"
        val values = ContentValues().apply {
            put(MediaStore.Audio.Media.DISPLAY_NAME, src.name)
            put(MediaStore.Audio.Media.MIME_TYPE, mime)
            put(MediaStore.Audio.Media.RELATIVE_PATH, "${Environment.DIRECTORY_MUSIC}/$DIR")
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
        return File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_MUSIC), "$DIR/${src.name}").path
    }
}
