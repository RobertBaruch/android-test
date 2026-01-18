package com.example.android_test

import android.bluetooth.*
import android.bluetooth.le.BluetoothLeScanner
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanFilter
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.Context
import android.os.Handler
import android.os.Looper
import android.os.ParcelUuid
import android.util.Log
import io.flutter.plugin.common.MethodChannel
import no.nordicsemi.android.ble.BleManager
import no.nordicsemi.android.ble.callback.DataReceivedCallback
import no.nordicsemi.android.ble.data.Data
import java.util.*

class BleCentralManager(private val context: Context, private val channel: MethodChannel) {

    companion object {
        private const val TAG = "BleCentralManager"

        // UUIDs matching those in ble_manager.dart
        val SERVICE_UUID = UUID.fromString("12345678-1234-5678-1234-56789abcdef0")
        val CODE_CHAR_UUID = UUID.fromString("12345678-1234-5678-1234-56789abcdef1")
        val PLAYER_ACTION_CHAR_UUID = UUID.fromString("12345678-1234-5678-1234-56789abcdef2")
        val GAME_STATE_CHAR_UUID = UUID.fromString("12345678-1234-5678-1234-56789abcdef3")
    }

    private var bluetoothManager: BluetoothManager? = null
    private var bluetoothAdapter: BluetoothAdapter? = null
    private var scanner: BluetoothLeScanner? = null
    private var gameConnectionManager: GameConnectionManager? = null

    private val scanResults = mutableListOf<ScanResult>()
    private var scanCallback: ScanCallback? = null
    private val handler = Handler(Looper.getMainLooper())

    init {
        bluetoothManager = context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
        bluetoothAdapter = bluetoothManager?.adapter
    }

    fun isBluetoothAvailable(): Boolean {
        return bluetoothAdapter?.isEnabled == true
    }

    fun startScan(timeoutSeconds: Int): Boolean {
        if (bluetoothAdapter?.isEnabled != true) {
            Log.e(TAG, "Bluetooth not enabled")
            return false
        }

        scanner = bluetoothAdapter?.bluetoothLeScanner
        if (scanner == null) {
            Log.e(TAG, "BLE scanning not supported")
            return false
        }

        scanResults.clear()

        val scanFilter = ScanFilter.Builder()
            .setServiceUuid(ParcelUuid(SERVICE_UUID))
            .build()

        val scanSettings = ScanSettings.Builder()
            .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
            .build()

        scanCallback = object : ScanCallback() {
            override fun onScanResult(callbackType: Int, result: ScanResult?) {
                result?.let {
                    if (!scanResults.any { sr -> sr.device.address == it.device.address }) {
                        scanResults.add(it)
                        Log.d(TAG, "Found device: ${it.device.address}")
                    }
                }
            }

            override fun onScanFailed(errorCode: Int) {
                Log.e(TAG, "Scan failed with error: $errorCode")
                channel.invokeMethod("onScanFailed", mapOf("errorCode" to errorCode))
            }
        }

        try {
            scanner?.startScan(listOf(scanFilter), scanSettings, scanCallback)
            Log.d(TAG, "Started scanning for BLE devices")

            // Stop scan after timeout
            handler.postDelayed({
                stopScan()
            }, (timeoutSeconds * 1000).toLong())

            return true
        } catch (e: SecurityException) {
            Log.e(TAG, "Security exception during scan: ${e.message}")
            return false
        }
    }

    fun stopScan() {
        try {
            scanCallback?.let {
                scanner?.stopScan(it)
                Log.d(TAG, "Stopped scanning")
            }
        } catch (e: SecurityException) {
            Log.e(TAG, "Security exception stopping scan: ${e.message}")
        }
    }

    fun getScanResults(): List<Map<String, Any>> {
        return scanResults.map { result ->
            mapOf(
                "deviceId" to result.device.address,
                "deviceName" to (result.device.name ?: "Unknown"),
                "rssi" to result.rssi
            )
        }
    }

    fun connectToDevice(deviceAddress: String, gameCode: String): Boolean {
        val device = bluetoothAdapter?.getRemoteDevice(deviceAddress)
        if (device == null) {
            Log.e(TAG, "Device not found: $deviceAddress")
            return false
        }

        gameConnectionManager = GameConnectionManager(context, channel, gameCode)
        gameConnectionManager?.connect(device)?.enqueue()

        return true
    }

    fun disconnect() {
        gameConnectionManager?.disconnect()?.enqueue()
        gameConnectionManager = null
    }

    fun sendPlayerAction(action: String) {
        gameConnectionManager?.sendPlayerAction(action)
    }

    // Inner class that extends Nordic BleManager to handle our game connection
    private class GameConnectionManager(
        context: Context,
        private val channel: MethodChannel,
        private val gameCode: String
    ) : BleManager(context) {

        private var codeCharacteristic: BluetoothGattCharacteristic? = null
        private var playerActionCharacteristic: BluetoothGattCharacteristic? = null
        private var gameStateCharacteristic: BluetoothGattCharacteristic? = null

        override fun getGattCallback(): BleManagerGattCallback {
            return GameGattCallback()
        }

        fun sendPlayerAction(action: String) {
            playerActionCharacteristic?.let { char ->
                writeCharacteristic(char, action.toByteArray())
                    .enqueue()
            }
        }

        private inner class GameGattCallback : BleManagerGattCallback() {
            override fun isRequiredServiceSupported(gatt: BluetoothGatt): Boolean {
                val service = gatt.getService(SERVICE_UUID)
                if (service == null) {
                    Log.e(TAG, "Required service not found")
                    return false
                }

                codeCharacteristic = service.getCharacteristic(CODE_CHAR_UUID)
                playerActionCharacteristic = service.getCharacteristic(PLAYER_ACTION_CHAR_UUID)
                gameStateCharacteristic = service.getCharacteristic(GAME_STATE_CHAR_UUID)

                return codeCharacteristic != null &&
                       playerActionCharacteristic != null &&
                       gameStateCharacteristic != null
            }

            override fun initialize() {
                super.initialize()

                // Send game code for verification
                codeCharacteristic?.let { char ->
                    writeCharacteristic(char, gameCode.toByteArray())
                        .with { device, data ->
                            Log.d(TAG, "Code sent to server")
                        }
                        .enqueue()

                    // Read the response
                    readCharacteristic(char)
                        .with { device, data ->
                            val response = data.value?.let { String(it, Charsets.UTF_8) } ?: ""
                            Log.d(TAG, "Received response: $response")

                            if (response == "ACCEPTED") {
                                channel.invokeMethod("onConnectionAccepted", null)
                                // Subscribe to game state updates
                                subscribeToGameState()
                            } else {
                                channel.invokeMethod("onConnectionRejected", mapOf("reason" to "Invalid game code"))
                                disconnect().enqueue()
                            }
                        }
                        .fail { device, status ->
                            Log.e(TAG, "Failed to read response: $status")
                            channel.invokeMethod("onConnectionFailed", mapOf("error" to "Failed to read response"))
                        }
                        .enqueue()
                }
            }

            private fun subscribeToGameState() {
                gameStateCharacteristic?.let { char ->
                    setNotificationCallback(char).with { device, data ->
                        val gameState = data.value?.let { String(it, Charsets.UTF_8) } ?: ""
                        Log.d(TAG, "Received game state: $gameState")
                        channel.invokeMethod("onGameStateReceived", mapOf("state" to gameState))
                    }

                    enableNotifications(char)
                        .done { device ->
                            Log.d(TAG, "Notifications enabled for game state")
                        }
                        .fail { device, status ->
                            Log.e(TAG, "Failed to enable notifications: $status")
                        }
                        .enqueue()
                }
            }

            override fun onServicesInvalidated() {
                codeCharacteristic = null
                playerActionCharacteristic = null
                gameStateCharacteristic = null
            }
        }

        override fun log(priority: Int, message: String) {
            Log.println(priority, TAG, message)
        }
    }
}
