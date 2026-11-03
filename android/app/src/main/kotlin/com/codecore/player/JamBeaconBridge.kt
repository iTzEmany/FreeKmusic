package com.codecore.player

import android.Manifest
import android.app.Activity
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.bluetooth.le.AdvertiseCallback
import android.bluetooth.le.AdvertiseData
import android.bluetooth.le.AdvertiseSettings
import android.bluetooth.le.AdvertisingSet
import android.bluetooth.le.AdvertisingSetCallback
import android.bluetooth.le.AdvertisingSetParameters
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanFilter
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.location.LocationManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.ParcelUuid
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * `codecore/jam_beacon`: the Bluetooth LE "there is a Jam here" beacon (D-254).
 * Advertises a non connectable, non scannable legacy packet with only service data on
 * UUID16 0xC0DE (no name) and scans for it with one low power scan. Without support or
 * permission every call answers empty/false: it never throws. `found` is pushed to Dart.
 */
object JamBeaconBridge {
    private const val REQUEST = 4108
    private const val START_TIMEOUT_MS = 3000L
    private val uuid = ParcelUuid.fromString("0000C0DE-0000-1000-8000-00805F9B34FB")
    private val main = Handler(Looper.getMainLooper())

    // The Activity is only for the permission dialog; Bluetooth services come from the
    // application context so the beacon outlives the Activity (the Jam goes on in background).
    private var activity: Activity? = null
    private var appContext: Context? = null
    private var channel: MethodChannel? = null
    private var stateReceiver: BroadcastReceiver? = null
    private val waiting = mutableListOf<MethodChannel.Result>()

    private var advSet: AdvertisingSet? = null
    private var advCallback: AdvertisingSetCallback? = null
    private var legacyCallback: AdvertiseCallback? = null
    private var scanCallback: ScanCallback? = null
    private var startResult: MethodChannel.Result? = null
    private val startTimeout = Runnable { stopAdvertising() }

    fun register(messenger: BinaryMessenger, activity: Activity) {
        this.activity = activity
        appContext = activity.applicationContext
        val ch = MethodChannel(messenger, "codecore/jam_beacon")
        channel = ch
        registerStateReceiver()
        ch.setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "capabilities" -> result.success(capabilities())
                    "permissions" -> result.success(permissions())
                    "requestPermissions" -> request(result)
                    "startAdvertising", "updateAdvertising" -> advertise(call.arguments as? ByteArray, result)
                    "stopAdvertising" -> { stopAdvertising(); result.success(null) }
                    "startScan" -> result.success(startScan())
                    "stopScan" -> { stopScan(); result.success(null) }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                android.util.Log.w("Codecore", "jam beacon ${call.method} failed", e)
                result.success(if (call.method == "capabilities" || call.method == "permissions") emptyMap<String, Boolean>() else false)
            }
        }
    }

    /** The engine goes away. The advertising is left to Dart's `stopAdvertising`. */
    fun detach() {
        stopScan()
        answer()
        channel?.setMethodCallHandler(null)
        channel = null
        activity = null
        unregisterStateReceiver()
    }

    /** The Activity is destroyed but the engine may live on: drop only what needs it. */
    fun onActivityDestroyed(a: Activity) {
        if (activity !== a) return
        stopScan()
        answer()
        activity = null
    }

    fun onRequestPermissionsResult(requestCode: Int): Boolean {
        if (requestCode != REQUEST) return false
        answer()
        return true
    }

    private fun push(method: String) {
        main.post { channel?.invokeMethod(method, null) }
    }

    private fun registerStateReceiver() {
        unregisterStateReceiver()
        val ctx = appContext ?: return
        val r = object : BroadcastReceiver() {
            override fun onReceive(c: Context?, i: Intent?) {
                val st = i?.getIntExtra(BluetoothAdapter.EXTRA_STATE, BluetoothAdapter.ERROR)
                if (st == BluetoothAdapter.STATE_ON) return
                // Off or switching: every callback of before is dead.
                if (scanCallback != null) { scanCallback = null; push("scanFailed") }
                if (advCallback != null || legacyCallback != null) {
                    advSet = null; advCallback = null; legacyCallback = null
                    answerStart(false)
                    push("advertiseFailed")
                }
            }
        }
        stateReceiver = r
        try {
            val f = IntentFilter(BluetoothAdapter.ACTION_STATE_CHANGED)
            // EXPORTED like the A2DP one: the broadcast comes from the Bluetooth process.
            if (Build.VERSION.SDK_INT >= 33) ctx.registerReceiver(r, f, Context.RECEIVER_EXPORTED)
            else ctx.registerReceiver(r, f)
        } catch (e: Exception) {
            android.util.Log.w("Codecore", "jam beacon state receiver failed", e)
            stateReceiver = null
        }
    }

    private fun unregisterStateReceiver() {
        stateReceiver?.let {
            try { appContext?.unregisterReceiver(it) } catch (e: Exception) {
                android.util.Log.w("Codecore", "jam beacon state receiver gone", e)
            }
        }
        stateReceiver = null
    }

    private fun adapter() =
        (appContext?.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager)?.adapter

    private fun has(p: String) =
        appContext?.checkSelfPermission(p) == PackageManager.PERMISSION_GRANTED

    // Android 12+: BLUETOOTH_SCAN / BLUETOOTH_ADVERTISE; up to 11 the scan needs the location.
    private fun canScan() =
        if (Build.VERSION.SDK_INT >= 31) has(Manifest.permission.BLUETOOTH_SCAN)
        else has(Manifest.permission.ACCESS_FINE_LOCATION)

    private fun canAdvertise() =
        Build.VERSION.SDK_INT < 31 || has(Manifest.permission.BLUETOOTH_ADVERTISE)

    private fun permissions() = mapOf("scan" to canScan(), "advertise" to canAdvertise())

    private fun capabilities(): Map<String, Boolean> {
        val a = adapter()
        val on = a?.isEnabled == true
        val locationOff = Build.VERSION.SDK_INT <= 30 && !locationEnabled()
        return mapOf(
            "bluetoothOn" to on,
            "scan" to (a != null && appContext?.packageManager?.hasSystemFeature(PackageManager.FEATURE_BLUETOOTH_LE) == true),
            "advertise" to (on && a?.isMultipleAdvertisementSupported == true),
            "locationOff" to locationOff,
            "needsLocation" to (Build.VERSION.SDK_INT <= 30),
        )
    }

    private fun locationEnabled(): Boolean {
        val lm = appContext?.getSystemService(Context.LOCATION_SERVICE) as? LocationManager ?: return false
        return if (Build.VERSION.SDK_INT >= 28) lm.isLocationEnabled
        else lm.isProviderEnabled(LocationManager.GPS_PROVIDER) || lm.isProviderEnabled(LocationManager.NETWORK_PROVIDER)
    }

    private fun request(result: MethodChannel.Result) {
        val act = activity ?: return result.success(permissions())
        val missing = (if (Build.VERSION.SDK_INT >= 31)
            listOf(Manifest.permission.BLUETOOTH_SCAN, Manifest.permission.BLUETOOTH_ADVERTISE)
        else listOf(Manifest.permission.ACCESS_FINE_LOCATION)).filter { !has(it) }
        if (missing.isEmpty()) return result.success(permissions())
        val first = waiting.isEmpty()
        waiting.add(result)
        if (first) act.requestPermissions(missing.toTypedArray(), REQUEST)
    }

    private fun answer() {
        val now = permissions()
        val list = waiting.toList()
        waiting.clear()
        list.forEach { it.success(now) }
    }

    private fun data(bytes: ByteArray) = AdvertiseData.Builder()
        .setIncludeDeviceName(false)
        .setIncludeTxPowerLevel(false)
        .addServiceData(uuid, bytes)
        .build()

    private fun answerStart(ok: Boolean) {
        main.removeCallbacks(startTimeout)
        val r = startResult ?: return
        startResult = null
        r.success(ok)
    }

    /** Starts the beacon, or swaps its payload when it runs; answers once it really started. */
    private fun advertise(bytes: ByteArray?, result: MethodChannel.Result) {
        if (bytes == null || !canAdvertise() || !capabilities().getValue("advertise")) return result.success(false)
        val advertiser = adapter()?.bluetoothLeAdvertiser ?: return result.success(false)
        val set = advSet
        if (set != null && advCallback != null) {
            set.setAdvertisingData(data(bytes))
            return result.success(true)
        }
        stopAdvertising()
        startResult = result
        main.postDelayed(startTimeout, START_TIMEOUT_MS)
        if (Build.VERSION.SDK_INT >= 26) {
            val params = AdvertisingSetParameters.Builder()
                .setLegacyMode(true).setConnectable(false).setScannable(false)
                .setInterval(AdvertisingSetParameters.INTERVAL_MEDIUM).build()
            val cb = object : AdvertisingSetCallback() {
                override fun onAdvertisingSetStarted(s: AdvertisingSet?, txPower: Int, status: Int) {
                    main.post {
                        if (advCallback !== this) return@post // an old, already replaced start
                        if (status == ADVERTISE_SUCCESS) { advSet = s; answerStart(true) }
                        else {
                            android.util.Log.w("Codecore", "jam beacon advertise failed: $status")
                            advCallback = null
                            answerStart(false)
                        }
                    }
                }
                override fun onAdvertisingSetStopped(s: AdvertisingSet?) {
                    main.post {
                        if (advCallback !== this) return@post // we stopped it ourselves
                        advSet = null
                        advCallback = null
                        answerStart(false)
                        push("advertiseFailed")
                    }
                }
            }
            advCallback = cb
            advertiser.startAdvertisingSet(params, data(bytes), null, null, null, cb)
        } else {
            val cb = object : AdvertiseCallback() {
                override fun onStartSuccess(settingsInEffect: AdvertiseSettings?) {
                    main.post { if (legacyCallback === this) answerStart(true) }
                }
                override fun onStartFailure(errorCode: Int) {
                    main.post {
                        if (legacyCallback !== this) return@post
                        android.util.Log.w("Codecore", "jam beacon advertise failed: $errorCode")
                        legacyCallback = null
                        answerStart(false)
                    }
                }
            }
            legacyCallback = cb
            val s = AdvertiseSettings.Builder().setConnectable(false)
                .setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_BALANCED).build()
            advertiser.startAdvertising(s, data(bytes), cb)
        }
    }

    private fun stopAdvertising() {
        val adv = advCallback
        val legacy = legacyCallback
        // Cleared first, so the stop callback is recognised as ours.
        advSet = null
        advCallback = null
        legacyCallback = null
        answerStart(false)
        try {
            val advertiser = adapter()?.bluetoothLeAdvertiser
            if (Build.VERSION.SDK_INT >= 26) adv?.let { advertiser?.stopAdvertisingSet(it) }
            legacy?.let { advertiser?.stopAdvertising(it) }
        } catch (e: Exception) {
            android.util.Log.w("Codecore", "jam beacon stop advertising failed", e)
        }
    }

    private fun startScan(): Boolean {
        if (adapter()?.isEnabled != true) { scanCallback = null; return false }
        if (scanCallback != null) return true
        // Android drops a 6th scan start in 30 s: one scan only, the lowest power.
        if (!canScan()) return false
        val scanner = adapter()?.bluetoothLeScanner ?: return false
        val cb = object : ScanCallback() {
            override fun onScanResult(callbackType: Int, r: ScanResult) {
                val bytes = r.scanRecord?.getServiceData(uuid) ?: return
                channel?.invokeMethod("found", mapOf("bytes" to bytes, "rssi" to r.rssi))
            }
            override fun onScanFailed(errorCode: Int) {
                android.util.Log.w("Codecore", "jam beacon scan failed: $errorCode")
                if (scanCallback === this) {
                    scanCallback = null
                    push("scanFailed")
                }
            }
        }
        val filter = ScanFilter.Builder()
            .setServiceData(uuid, byteArrayOf(1), byteArrayOf(0xFF.toByte())).build()
        val settings = ScanSettings.Builder().setScanMode(ScanSettings.SCAN_MODE_LOW_POWER).build()
        scanner.startScan(listOf(filter), settings, cb)
        scanCallback = cb // only after the start went through
        return true
    }

    private fun stopScan() {
        val cb = scanCallback ?: return
        scanCallback = null
        try {
            adapter()?.bluetoothLeScanner?.stopScan(cb)
        } catch (e: Exception) {
            android.util.Log.w("Codecore", "jam beacon stop scan failed", e)
        }
    }
}
