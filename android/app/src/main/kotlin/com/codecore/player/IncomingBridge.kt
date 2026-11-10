package com.codecore.player

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns
import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * `codecore/incoming`: a ZIP/CSV opened with Codecore («Apri con», «Condividi»).
 * The content is copied into the cache (at most [MAX_BYTES], a sanitized name)
 * and its path kept until Dart takes it with `takeIncoming`; `incoming` is
 * pushed to Dart when the file arrives while the app already runs.
 */
object IncomingBridge {
    private const val MAX_BYTES = 20L * 1024 * 1024
    private const val TAG = "IncomingBridge"
    private var channel: MethodChannel? = null

    // One copy at a time, so two files arriving together do not clash.
    private val copier = java.util.concurrent.Executors.newSingleThreadExecutor()

    @Volatile
    private var pendingPath: String? = null

    // A queue, so shares arriving before Dart drains it are not overwritten.
    private val pendingTexts = java.util.concurrent.ConcurrentLinkedQueue<String>()

    fun detach() {
        channel = null
    }

    fun register(messenger: BinaryMessenger) {
        val ch = MethodChannel(messenger, "codecore/incoming")
        channel = ch
        ch.setMethodCallHandler { call, result ->
            when (call.method) {
                "takeIncoming" -> {
                    result.success(pendingPath)
                    pendingPath = null
                }
                "takeIncomingText" -> {
                    val all = ArrayList<String>()
                    while (true) all.add(pendingTexts.poll() ?: break)
                    result.success(all)
                }
                else -> result.notImplemented()
            }
        }
    }

    @Suppress("DEPRECATION")
    fun handleIntent(ctx: Context, intent: Intent?) {
        if (intent == null) return
        val stream = if (intent.action == Intent.ACTION_SEND) {
            intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)
        } else null
        // A stream always takes today's path; shared text only when it is not a ZIP/CSV.
        val uri: Uri? = when (intent.action) {
            Intent.ACTION_VIEW -> intent.data
            Intent.ACTION_SEND -> stream?.takeIf { isZipOrCsv(ctx, it, intent.type) }
            else -> null
        }
        if (uri == null) {
            if (intent.action != Intent.ACTION_SEND || stream != null) return
            val text = intent.getStringExtra(Intent.EXTRA_TEXT)?.takeIf { it.isNotBlank() }
                ?: intent.getStringExtra(Intent.EXTRA_SUBJECT)?.takeIf { it.isNotBlank() }
                ?: return
            intent.action = null
            pendingTexts.add(text)
            channel?.invokeMethod("incomingText", null)
            return
        }
        // Handled once, even if the activity is recreated with the same intent.
        intent.action = null
        copier.execute {
            val path = copyToCache(ctx, uri)
            if (path != null) {
                pendingPath = path
                android.os.Handler(android.os.Looper.getMainLooper()).post {
                    channel?.invokeMethod("incoming", null)
                }
            }
        }
    }

    private fun isZipOrCsv(ctx: Context, uri: Uri, type: String?): Boolean {
        val t = (type ?: ctx.contentResolver.getType(uri) ?: "").lowercase()
        if (t.contains("zip") || t.contains("csv") || t == "text/comma-separated-values") return true
        val n = displayName(ctx, uri).lowercase()
        return n.endsWith(".zip") || n.endsWith(".csv")
    }

    private fun displayName(ctx: Context, uri: Uri): String {
        var name: String? = null
        try {
            ctx.contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
                ?.use { if (it.moveToFirst()) name = it.getString(0) }
        } catch (e: Exception) {
            Log.w(TAG, "no display name", e)
        }
        return name ?: uri.lastPathSegment ?: "import"
    }

    // The shared name may lack an extension; Dart tells ZIP from CSV by it.
    private fun withExtension(ctx: Context, uri: Uri, name: String): String {
        val low = name.lowercase()
        if (low.endsWith(".zip") || low.endsWith(".csv")) return name
        return if (ctx.contentResolver.getType(uri) == "application/zip") "$name.zip" else "$name.csv"
    }

    private fun copyToCache(ctx: Context, uri: Uri): String? {
        val safe = withExtension(ctx, uri, displayName(ctx, uri).substringAfterLast('/'))
            .replace(Regex("[^A-Za-z0-9._ ()-]"), "_").take(80)
        // A new folder each time, so Dart sees every arrival as a different file
        // while the name (the playlist name in Dart) stays the shared one.
        val root = File(ctx.cacheDir, "incoming").apply { mkdirs() }
        val old = System.currentTimeMillis() - 60 * 60 * 1000
        root.listFiles()?.forEach { if (it.lastModified() < old) it.deleteRecursively() }
        val dir = File(root, "${System.currentTimeMillis()}").apply { mkdirs() }
        val out = File(dir, safe)
        return try {
            ctx.contentResolver.openInputStream(uri)?.use { input ->
                out.outputStream().use { o ->
                    val buf = ByteArray(64 * 1024)
                    var total = 0L
                    while (true) {
                        val n = input.read(buf)
                        if (n < 0) break
                        total += n
                        if (total > MAX_BYTES) throw java.io.IOException("over $MAX_BYTES bytes")
                        o.write(buf, 0, n)
                    }
                }
            } ?: return null
            out.path
        } catch (e: Exception) {
            Log.w(TAG, "could not copy the incoming file", e)
            out.delete()
            null
        }
    }
}
