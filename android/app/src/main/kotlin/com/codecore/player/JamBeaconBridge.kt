package com.codecore.player

import android.Manifest
import android.app.Activity
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
import android.content.Context
import android.content.pm.PackageManager
import android.location.LocationManager
import android.os.Build
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
    private val uuid = ParcelUuid.fromString("0000C0DE-0000-1000-8000-00805F9B34FB")

    private var activity: Activity? = null
    private var channel: MethodChannel? = null
    private val waiting = mutableListOf<MethodChannel.Result>()

    private var advSet: AdvertisingSet? = null
    private var advCallback: AdvertisingSetCallback? = null
    private var legacyCallback: AdvertiseCallback? = null
    private var scanCallback: ScanCallback? = null

    fun register(messenger: BinaryMessenger, activity: Activity) {
        this.activity = activity
        val ch = MethodChannel(messenger, "codecore/jam_beacon")
        channel = ch
        ch.setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "capabilities" -> result.success(capabilities())
                    "permissions" -> result.success(permissions())
                    "requestPermissions" -> request(result)
                    "startAdvertising", "updateAdvertising" ->
                        result.success(advertise(call.arguments as? ByteArray))
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

    fun detach() {
        stopScan()
        stopAdvertising()
        answer()
        channel?.setMethodCallHandler(null)
        channel = null
        activity = null
    }

    fun onRequestPermissionsResult(requestCode: Int): Boolean {
        if (requestCode != REQUEST) return false
        answer()
        return true
    }

    private fun adapter() =
        (activity?.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager)?.adapter

    private fun has(p: String) =
        activity?.checkSelfPermission(p) == PackageManager.PERMISSION_GRANTED

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
            "scan" to (a != null && activity?.packageManager?.hasSystemFeature(PackageManager.FEATURE_BLUETOOTH_LE) == true),
            "advertise" to (on && a?.isMultipleAdvertisementSupported == true),
            "locationOff" to locationOff,
        )
    }

    private fun locationEnabled(): Boolean {
        val lm = activity?.getSystemService(Context.LOCATION_SERVICE) as? LocationManager ?: return false
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

    /** Starts the beacon, or swaps its payload when it already runs. */
    private fun advertise(bytes: ByteArray?): Boolean {
        if (bytes == null || !canAdvertise() || !capabilities().getValue("advertise")) return false
        val advertiser = adapter()?.bluetoothLeAdvertiser ?: return false
        val set = advSet
        if (set != null) {
            set.setAdvertisingData(data(bytes))
            return true
        }
        stopAdvertising()
        if (Build.VERSION.SDK_INT >= 26) {
            val params = AdvertisingSetParameters.Builder()
                .setLegacyMode(true).setConnectable(false).setScannable(false).build()
            val cb = object : AdvertisingSetCallback() {
                override fun onAdvertisingSetStarted(s: AdvertisingSet?, txPower: Int, status: Int) {
                    if (status == ADVERTISE_SUCCESS) advSet = s
                    else android.util.Log.w("Codecore", "jam beacon advertise failed: $status")
                }
            }
            advCallback = cb
            advertiser.startAdvertisingSet(params, data(bytes), null, null, null, cb)
        } else {
            val cb = object : AdvertiseCallback() {
                override fun onStartFailure(errorCode: Int) {
                    android.util.Log.w("Codecore", "jam beacon advertise failed: $errorCode")
                }
            }
            legacyCallback = cb
            val s = AdvertiseSettings.Builder().setConnectable(false).build()
            advertiser.startAdvertising(s, data(bytes), cb)
        }
        return true
    }

    private fun stopAdvertising() {
        try {
            val advertiser = adapter()?.bluetoothLeAdvertiser
            if (Build.VERSION.SDK_INT >= 26) advCallback?.let { advertiser?.stopAdvertisingSet(it) }
            legacyCallback?.let { advertiser?.stopAdvertising(it) }
        } catch (e: Exception) {
            android.util.Log.w("Codecore", "jam beacon stop advertising failed", e)
        }
        advSet = null
        advCallback = null
        legacyCallback = null
    }

    private fun startScan(): Boolean {
        if (scanCallback != null) return true
        // Android drops a 6th scan start in 30 s: one scan only, the lowest power.
        if (!canScan() || adapter()?.isEnabled != true) return false
        val scanner = adapter()?.bluetoothLeScanner ?: return false
        val cb = object : ScanCallback() {
            override fun onScanResult(callbackType: Int, r: ScanResult) {
                val bytes = r.scanRecord?.getServiceData(uuid) ?: return
                channel?.invokeMethod("found", mapOf("bytes" to bytes, "rssi" to r.rssi))
            }
            override fun onScanFailed(errorCode: Int) {
                android.util.Log.w("Codecore", "jam beacon scan failed: $errorCode")
                if (scanCallback === this) scanCallback = null
            }
        }
        val filter = ScanFilter.Builder()
            .setServiceData(uuid, byteArrayOf(1), byteArrayOf(0xFF.toByte())).build()
        val settings = ScanSettings.Builder().setScanMode(ScanSettings.SCAN_MODE_LOW_POWER).build()
        scanCallback = cb
        scanner.startScan(listOf(filter), settings, cb)
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
