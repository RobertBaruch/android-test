package com.example.android_test

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.android_test/ble_peripheral"
    private var blePeripheralManager: BlePeripheralManager? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        blePeripheralManager = BlePeripheralManager(this, channel)

        channel.setMethodCallHandler { call, result ->
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
    }

    override fun onDestroy() {
        blePeripheralManager?.stopAdvertising()
        super.onDestroy()
    }
}
