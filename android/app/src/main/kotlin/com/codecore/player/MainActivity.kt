package com.codecore.player

import android.Manifest
import android.bluetooth.BluetoothA2dp
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.media.AudioDeviceCallback
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/** The single activity: hosts the platform channels the Dart side uses. */
class MainActivity : AudioServiceActivity() {
    private val main = Handler(Looper.getMainLooper())
    private var deviceCallback: AudioDeviceCallback? = null
    private var btReceiver: BroadcastReceiver? = null
    private val btPermissionResults = mutableListOf<MethodChannel.Result>()

    // A restored activity gets its old launch intent again: not a new file.
    private var restored = false

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        restored = savedInstanceState != null
        super.onCreate(savedInstanceState)
    }

    override fun onResume() {
        super.onResume()
        ShareBridge.foreground = true
        ShareBridge.channel?.invokeMethod("appResumed", null)
    }

    override fun onStop() {
        super.onStop()
        // Never while the user looks at the app, nor for a rotation or the like.
        if (!isChangingConfigurations) IconBridge.apply(applicationContext)
    }

    override fun onNewIntent(intent: android.content.Intent) {
        super.onNewIntent(intent)
        NotifyBridge.handleIntent(intent)
        IncomingBridge.handleIntent(applicationContext, intent)
    }

    override fun onPause() {
        ShareBridge.foreground = false
        super.onPause()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // yt-dlp lives in the `full` flavor only (see YtDlpChannel).
        YtDlpChannel(applicationContext).register(flutterEngine.dartExecutor.binaryMessenger)
        ImportBridge.register(flutterEngine.dartExecutor.binaryMessenger, applicationContext)
        MediaDeleteBridge.register(flutterEngine.dartExecutor.binaryMessenger, this)
        SaveFileBridge.register(flutterEngine.dartExecutor.binaryMessenger, this)
        StorageBridge.register(flutterEngine.dartExecutor.binaryMessenger)
        NetworkBridge.register(flutterEngine.dartExecutor.binaryMessenger, applicationContext)
        NotifyBridge.register(flutterEngine.dartExecutor.binaryMessenger, applicationContext)
        LinkBridge.register(flutterEngine.dartExecutor.binaryMessenger, applicationContext)
        IconBridge.register(flutterEngine.dartExecutor.binaryMessenger, applicationContext)
        JamBeaconBridge.register(flutterEngine.dartExecutor.binaryMessenger, this)
        NotifyBridge.handleIntent(intent)
        IncomingBridge.register(flutterEngine.dartExecutor.binaryMessenger)
        if (!restored) IncomingBridge.handleIntent(applicationContext, intent)

        // Where the sound goes (headphones or speaker): the equalizer keeps a
        // curve for each.
        val audio = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "codecore/audio")
        audio.setMethodCallHandler { call, result ->
            when (call.method) {
                "outputRoute" -> result.success(currentOutputRoute())
                "bluetoothOutputs" -> bluetoothOutputs(result)
                "netPrefix" -> netPrefix(result)
                "bluetoothOutputActive" -> result.success(bluetoothOutputActive())
                "bluetoothPermission" -> result.success(hasBluetoothPermission())
                "requestBluetoothPermission" -> requestBluetoothPermission(result)
                else -> result.notImplemented()
            }
        }
        registerBluetoothReceiver(audio)
        val audioManager = getSystemService(AUDIO_SERVICE) as AudioManager
        deviceCallback?.let { audioManager.unregisterAudioDeviceCallback(it) }
        val cb = object : AudioDeviceCallback() {
            override fun onAudioDevicesAdded(added: Array<out AudioDeviceInfo>) {
                pushRoute(audio)
                if (added.any { it.type == AudioDeviceInfo.TYPE_BLUETOOTH_A2DP }) {
                    audio.invokeMethod("bluetoothOutputSeen", null)
                }
            }
            override fun onAudioDevicesRemoved(removed: Array<out AudioDeviceInfo>) = pushRoute(audio)
        }
        deviceCallback = cb
        audioManager.registerAudioDeviceCallback(cb, main)

        // Car mode: keep the screen on while it is open.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "codecore/screen")
            .setMethodCallHandler { call, result ->
                if (call.method == "keepOn") {
                    val on = call.arguments as? Boolean ?: false
                    if (on) window.addFlags(android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    else window.clearFlags(android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    result.success(null)
                } else result.notImplemented()
            }

        val share = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "codecore/share")
        ShareBridge.channel = share
        share.setMethodCallHandler { call, result ->
            val ctx = applicationContext
            when (call.method) {
                "startService" -> {
                    ReceiveService.start(
                        ctx,
                        call.argument<String>("title") ?: "Codecore",
                        call.argument<String>("text") ?: "",
                        call.argument<String>("disable") ?: "Stop",
                    )
                    result.success(null)
                }
                "stopService" -> {
                    ReceiveService.stop(ctx)
                    result.success(null)
                }
                "showOffer" -> {
                    ShareNotifications.showOffer(
                        ctx,
                        call.argument<String>("offerId")!!,
                        call.argument<String>("title") ?: "",
                        call.argument<String>("body") ?: "",
                        call.argument<String>("accept") ?: "OK",
                        call.argument<String>("decline") ?: "No",
                    )
                    result.success(null)
                }
                "isForeground" -> result.success(ShareBridge.foreground)
                "deviceName" -> {
                    // The user-visible device name, falling back to the model.
                    val name = try {
                        android.provider.Settings.Global.getString(
                            ctx.contentResolver, "device_name")
                    } catch (e: Exception) {
                        null
                    }
                    result.success(if (name.isNullOrBlank()) android.os.Build.MODEL else name)
                }
                "clearOffer" -> {
                    ShareNotifications.clearOffer(ctx, call.argument<String>("offerId")!!)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        // Nothing may keep pushing to the engine that is going away.
        NetworkBridge.unregister()
        deviceCallback?.let {
            (getSystemService(AUDIO_SERVICE) as AudioManager).unregisterAudioDeviceCallback(it)
        }
        deviceCallback = null
        unregisterBluetoothReceiver()
        answerPermissionRequests()
        ShareBridge.channel = null
        ImportBridge.channel = null
        NotifyBridge.detach()
        IncomingBridge.detach()
        JamBeaconBridge.detach()
        MediaDeleteBridge.detach()
        SaveFileBridge.detach()
        super.cleanUpFlutterEngine(flutterEngine)
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: android.content.Intent?) {
        if (MediaDeleteBridge.onActivityResult(requestCode, resultCode)) return
        if (SaveFileBridge.onActivityResult(this, requestCode, resultCode, data)) return
        @Suppress("DEPRECATION")
        super.onActivityResult(requestCode, resultCode, data)
    }

    override fun onDestroy() {
        JamBeaconBridge.onActivityDestroyed(this)
        unregisterBluetoothReceiver()
        answerPermissionRequests()
        super.onDestroy()
    }

    override fun onRequestPermissionsResult(
        requestCode: Int, permissions: Array<out String>, grantResults: IntArray,
    ) {
        if (JamBeaconBridge.onRequestPermissionsResult(requestCode)) return
        if (requestCode == BT_REQUEST) {
            answerPermissionRequests()
            return
        }
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }

    // Before Android 12 the legacy BLUETOOTH permission is install-time.
    private fun hasBluetoothPermission(): Boolean =
        Build.VERSION.SDK_INT < 31 ||
            checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED

    private fun requestBluetoothPermission(result: MethodChannel.Result) {
        if (hasBluetoothPermission()) return result.success(true)
        val first = btPermissionResults.isEmpty()
        btPermissionResults.add(result)
        if (first) requestPermissions(arrayOf(Manifest.permission.BLUETOOTH_CONNECT), BT_REQUEST)
    }

    /** Every waiting request gets the same, current answer. */
    private fun answerPermissionRequests() {
        val granted = hasBluetoothPermission()
        val waiting = btPermissionResults.toList()
        btPermissionResults.clear()
        waiting.forEach { it.success(granted) }
    }

    private fun bluetoothOutputActive(): Boolean = try {
        (getSystemService(AUDIO_SERVICE) as AudioManager)
            .getDevices(AudioManager.GET_DEVICES_OUTPUTS)
            .any { it.type == AudioDeviceInfo.TYPE_BLUETOOTH_A2DP }
    } catch (e: Exception) {
        android.util.Log.w("Codecore", "bluetooth active check failed", e)
        false
    }

    private fun registerBluetoothReceiver(audio: MethodChannel) {
        unregisterBluetoothReceiver()
        val r = object : BroadcastReceiver() {
            override fun onReceive(c: Context?, i: Intent?) {
                audio.invokeMethod("bluetoothChanged", null)
            }
        }
        btReceiver = r
        try {
            val f = IntentFilter(BluetoothA2dp.ACTION_CONNECTION_STATE_CHANGED)
            // EXPORTED: the broadcast comes from the Bluetooth process (uid 1002), which a
            // NOT_EXPORTED receiver never gets; it is a protected broadcast, so no spoofing.
            if (Build.VERSION.SDK_INT >= 33) registerReceiver(r, f, Context.RECEIVER_EXPORTED)
            else registerReceiver(r, f)
        } catch (e: Exception) {
            android.util.Log.w("Codecore", "bluetooth receiver failed", e)
            btReceiver = null
        }
    }

    private fun unregisterBluetoothReceiver() {
        btReceiver?.let {
            try { unregisterReceiver(it) } catch (e: Exception) {
                android.util.Log.w("Codecore", "bluetooth receiver gone", e)
            }
        }
        btReceiver = null
    }

    /**
     * `[{address, prefix}]` of the up, non-loopback IPv4 interfaces. NetworkInterface
     * (not ConnectivityManager's LinkProperties) because it also lists the hotspot's.
     */
    private fun netPrefix(result: MethodChannel.Result) {
        Thread {
            val out = try {
                java.util.Collections.list(java.net.NetworkInterface.getNetworkInterfaces())
                    .filter { it.isUp && !it.isLoopback }
                    .flatMap { it.interfaceAddresses }
                    .filter { it.address is java.net.Inet4Address }
                    .map { mapOf("address" to it.address.hostAddress, "prefix" to it.networkPrefixLength.toInt()) }
            } catch (e: Exception) {
                android.util.Log.w("Codecore", "net prefix failed", e)
                emptyList()
            }
            main.post { result.success(out) }
        }.start()
    }

    /** `{permission, outputs: [{name, address, deviceClass}]}`; never throws, answers once. */
    private fun bluetoothOutputs(result: MethodChannel.Result) {
        var answered = false
        // ok=false: the read failed (timeout, exception); an empty list with ok=true is real.
        fun reply(permission: Boolean, outputs: List<Map<String, Any?>>, ok: Boolean = true) {
            if (answered) return
            answered = true
            result.success(mapOf("permission" to permission, "outputs" to outputs, "ok" to ok))
        }
        if (!hasBluetoothPermission()) return reply(false, emptyList())
        try {
            val adapter = (getSystemService(BLUETOOTH_SERVICE) as? BluetoothManager)?.adapter
            // With Bluetooth off the proxy would only connect once it is turned on.
            if (adapter == null || !adapter.isEnabled) return reply(true, emptyList())
            var proxy: BluetoothProfile? = null
            fun close() {
                proxy?.let { adapter.closeProfileProxy(BluetoothProfile.A2DP, it) }
                proxy = null
            }
            val timeout = Runnable {
                // Bluetooth turned off meanwhile: the speaker really is gone.
                reply(hasBluetoothPermission(), emptyList(), !adapter.isEnabled)
                close()
            }
            val ok = adapter.getProfileProxy(this, object : BluetoothProfile.ServiceListener {
                override fun onServiceConnected(profile: Int, p: BluetoothProfile) {
                    main.removeCallbacks(timeout)
                    proxy = p
                    try {
                        reply(true, p.connectedDevices.map {
                            mapOf(
                                "name" to it.name,
                                "address" to it.address,
                                "deviceClass" to it.bluetoothClass?.deviceClass,
                            )
                        })
                    } catch (e: Exception) {
                        android.util.Log.w("Codecore", "bluetooth outputs failed", e)
                        reply(hasBluetoothPermission(), emptyList(), false)
                    } finally {
                        close()
                    }
                }
                override fun onServiceDisconnected(profile: Int) {}
            }, BluetoothProfile.A2DP)
            if (ok) main.postDelayed(timeout, 3000) else reply(true, emptyList(), false)
        } catch (e: Exception) {
            android.util.Log.w("Codecore", "bluetooth outputs failed", e)
            reply(hasBluetoothPermission(), emptyList(), false)
        }
    }

    private companion object {
        const val BT_REQUEST = 4107
    }

    private fun pushRoute(audio: MethodChannel) {
        audio.invokeMethod("outputRoute", currentOutputRoute())
    }

    /** `headphones` when wired, Bluetooth or USB headphones are connected, else `speaker`. */
    private fun currentOutputRoute(): String {
        val am = getSystemService(AUDIO_SERVICE) as AudioManager
        val types = mutableSetOf(
            AudioDeviceInfo.TYPE_WIRED_HEADPHONES,
            AudioDeviceInfo.TYPE_WIRED_HEADSET,
            AudioDeviceInfo.TYPE_BLUETOOTH_A2DP,
            AudioDeviceInfo.TYPE_BLUETOOTH_SCO,
            AudioDeviceInfo.TYPE_USB_HEADSET,
        )
        if (Build.VERSION.SDK_INT >= 31) types.add(AudioDeviceInfo.TYPE_BLE_HEADSET)
        val headphones = am.getDevices(AudioManager.GET_DEVICES_OUTPUTS).any { it.type in types }
        return if (headphones) "headphones" else "speaker"
    }
}
