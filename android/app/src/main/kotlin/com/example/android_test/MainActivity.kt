package com.example.android_test

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val PERIPHERAL_CHANNEL = "com.example.android_test/ble_peripheral"
    private val CENTRAL_CHANNEL = "com.example.android_test/ble_central"
    private var blePeripheralManager: BlePeripheralManager? = null
    private var bleCentralManager: BleCentralManager? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Setup peripheral channel (for hosting/server mode)
        val peripheralChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PERIPHERAL_CHANNEL)
        blePeripheralManager = BlePeripheralManager(this, peripheralChannel)

        peripheralChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "startAdvertising" -> {
                    val gameName = call.argument<String>("gameName") ?: ""
                    val gameCode = call.argument<String>("gameCode") ?: ""

                    val success = blePeripheralManager?.startAdvertising(gameName, gameCode) ?: false
                    result.success(success)
                }

                "stopAdvertising" -> {
                    blePeripheralManager?.stopAdvertising()
                    result.success(true)
                }

                "sendGameState" -> {
                    val state = call.argument<String>("state") ?: ""
                    blePeripheralManager?.sendGameState(state)
                    result.success(true)
                }

                else -> {
                    result.notImplemented()
                }
            }
        }

        // Setup central channel (for client/scanner mode)
        val centralChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CENTRAL_CHANNEL)
        bleCentralManager = BleCentralManager(this, centralChannel)

        centralChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "isBluetoothAvailable" -> {
                    val available = bleCentralManager?.isBluetoothAvailable() ?: false
                    result.success(available)
                }

                "startScan" -> {
                    val timeoutSeconds = call.argument<Int>("timeoutSeconds") ?: 4
                    val success = bleCentralManager?.startScan(timeoutSeconds) ?: false
                    result.success(success)
                }

                "stopScan" -> {
                    bleCentralManager?.stopScan()
                    result.success(true)
                }

                "getScanResults" -> {
                    val results = bleCentralManager?.getScanResults() ?: emptyList()
                    result.success(results)
                }

                "connectToDevice" -> {
                    val deviceAddress = call.argument<String>("deviceAddress") ?: ""
                    val gameCode = call.argument<String>("gameCode") ?: ""
                    val success = bleCentralManager?.connectToDevice(deviceAddress, gameCode) ?: false
                    result.success(success)
                }

                "disconnect" -> {
                    bleCentralManager?.disconnect()
                    result.success(true)
                }

                "sendPlayerAction" -> {
                    val action = call.argument<String>("action") ?: ""
                    bleCentralManager?.sendPlayerAction(action)
                    result.success(true)
                }

                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    override fun onDestroy() {
        blePeripheralManager?.stopAdvertising()
        bleCentralManager?.disconnect()
        super.onDestroy()
    }
}
