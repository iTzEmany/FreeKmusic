package com.codecore.player

import android.content.Context
import android.content.Intent
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.util.Log
import androidx.core.content.FileProvider
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

/**
 * `codecore/update`: the pieces the in-app updater needs on Android: `abi`,
 * `canInstall`, `openInstallSettings`, `sameSigner(path)` and `install(path)`.
 * Paths must live in `cache/updates` (the only folder the FileProvider shares).
 */
object UpdateChannel {
    private const val TAG = "UpdateChannel"
    private val main = Handler(Looper.getMainLooper())
    private val io = Executors.newSingleThreadExecutor()

    fun register(messenger: BinaryMessenger, context: Context) {
        appCache = context.cacheDir
        MethodChannel(messenger, "codecore/update").setMethodCallHandler { call, result ->
            when (call.method) {
                "abi" -> result.success(Build.SUPPORTED_ABIS[0])
                "canInstall" -> result.success(
                    Build.VERSION.SDK_INT < Build.VERSION_CODES.O ||
                        context.packageManager.canRequestPackageInstalls()
                )
                "openInstallSettings" -> run(result) {
                    context.startActivity(
                        Intent(
                            Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                            Uri.parse("package:${context.packageName}"),
                        ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    )
                    null
                }
                "sameSigner" -> withApk(call.argument<String>("path"), result) { sameSigner(context, it) }
                "install" -> withApk(call.argument<String>("path"), result) { install(context, it) }
                else -> result.notImplemented()
            }
        }
    }

    /** Runs [block] off the main thread and answers on the main thread. */
    private fun run(result: MethodChannel.Result, block: () -> Any?) {
        io.execute {
            try {
                val value = block()
                main.post { result.success(value) }
            } catch (e: Exception) {
                Log.w(TAG, "call failed", e)
                main.post { result.error("update", e.message, null) }
            }
        }
    }

    private fun withApk(path: String?, result: MethodChannel.Result, block: (File) -> Any?) {
        if (path == null) {
            result.error("args", "path is required", null)
            return
        }
        run(result) {
            val file = File(path).canonicalFile
            val dir = File(appCache, "updates").canonicalFile
            require(file.parentFile == dir && file.isFile) { "path outside cache/updates" }
            block(file)
        }
    }

    private lateinit var appCache: File

    private fun signers(info: PackageInfo?): Set<String> {
        if (info == null) return emptySet()
        @Suppress("DEPRECATION")
        val sigs = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            info.signingInfo?.apkContentsSigners
        } else {
            info.signatures
        }
        return sigs?.map { it.toCharsString() }?.toSet() ?: emptySet()
    }

    private fun sameSigner(context: Context, apk: File): Boolean {
        val pm = context.packageManager
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            PackageManager.GET_SIGNING_CERTIFICATES
        } else {
            @Suppress("DEPRECATION") PackageManager.GET_SIGNATURES
        }
        // Android 9-10 fill an archive's signingInfo only when GET_SIGNATURES is also asked.
        @Suppress("DEPRECATION")
        val archiveFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            flags or PackageManager.GET_SIGNATURES
        } else {
            flags
        }
        val archive = pm.getPackageArchiveInfo(apk.path, archiveFlags) ?: return false
        // A different package name (e.g. the perf build) also counts as "different signer".
        if (archive.packageName != context.packageName) return false
        val installed = pm.getPackageInfo(context.packageName, flags)
        val mine = signers(installed)
        return mine.isNotEmpty() && mine == signers(archive)
    }

    private fun install(context: Context, apk: File): Boolean {
        val uri = FileProvider.getUriForFile(context, "${context.packageName}.updates", apk)
        context.startActivity(
            Intent(Intent.ACTION_VIEW)
                .setDataAndType(uri, "application/vnd.android.package-archive")
                .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
        )
        return true
    }
}
