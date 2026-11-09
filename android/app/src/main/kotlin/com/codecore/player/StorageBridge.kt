package com.codecore.player

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.StatFs
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * `codecore/storage`: `diskSpace({path})` answers `{total, free}` in bytes for
 * the volume the path is on (the nearest existing parent when the folder is
 * gone), for the «Memoria» tab; `openFolder({uri})` shows a DocumentsContract
 * folder URI in the file manager (answers false when no app takes it).
 */
object StorageBridge {
    fun register(context: Context, messenger: BinaryMessenger) {
        MethodChannel(messenger, "codecore/storage").setMethodCallHandler { call, result ->
            if (call.method == "openFolder") {
                val uri = call.argument<String>("uri")
                if (uri == null) {
                    result.error("bad_args", "uri is required", null)
                    return@setMethodCallHandler
                }
                try {
                    val intent = Intent(Intent.ACTION_VIEW)
                        .setDataAndType(Uri.parse(uri), "vnd.android.document/directory")
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    context.startActivity(intent)
                    result.success(true)
                } catch (e: Exception) {
                    result.success(false)
                }
                return@setMethodCallHandler
            }
            if (call.method != "diskSpace") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val path = call.argument<String>("path")
            if (path == null) {
                result.error("bad_args", "path is required", null)
                return@setMethodCallHandler
            }
            try {
                var dir: File? = File(path)
                while (dir != null && !dir.exists()) dir = dir.parentFile
                val stat = StatFs((dir ?: File("/")).path)
                result.success(mapOf("total" to stat.totalBytes, "free" to stat.availableBytes))
            } catch (e: Exception) {
                result.error("stat_failed", e.message, null)
            }
        }
    }
}
