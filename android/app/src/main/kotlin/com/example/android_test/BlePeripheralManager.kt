package com.example.android_test

import android.bluetooth.*
import android.bluetooth.le.AdvertiseCallback
import android.bluetooth.le.AdvertiseData
import android.bluetooth.le.AdvertiseSettings
import android.bluetooth.le.BluetoothLeAdvertiser
import android.content.Context
import android.os.ParcelUuid
import android.util.Log
import io.flutter.plugin.common.MethodChannel
import java.util.*

class BlePeripheralManager(private val context: Context, private val channel: MethodChannel) {

    companion object {
        private const val TAG = "BlePeripheralManager"

        // UUIDs matching those in ble_manager.dart
        val SERVICE_UUID = UUID.fromString("12345678-1234-5678-1234-56789abcdef0")
        val CODE_CHAR_UUID = UUID.fromString("12345678-1234-5678-1234-56789abcdef1")
        val PLAYER_ACTION_CHAR_UUID = UUID.fromString("12345678-1234-5678-1234-56789abcdef2")
        val GAME_STATE_CHAR_UUID = UUID.fromString("12345678-1234-5678-1234-56789abcdef3")
    }

    private var bluetoothManager: BluetoothManager? = null
    private var bluetoothAdapter: BluetoothAdapter? = null
    private var advertiser: BluetoothLeAdvertiser? = null
    private var gattServer: BluetoothGattServer? = null

    private var gameCode: String = ""
    private val connectedDevices = mutableListOf<BluetoothDevice>()
    private val deviceCodes = mutableMapOf<BluetoothDevice, String>()

    private val advertiseCallback = object : AdvertiseCallback() {
        override fun onStartSuccess(settingsInEffect: AdvertiseSettings?) {
            Log.d(TAG, "Advertising started successfully")
            channel.invokeMethod("onAdvertisingStarted", null)
        }

        override fun onStartFailure(errorCode: Int) {
            Log.e(TAG, "Advertising failed with error: $errorCode")
            channel.invokeMethod("onAdvertisingFailed", mapOf("errorCode" to errorCode))
        }
    }

    private val gattServerCallback = object : BluetoothGattServerCallback() {
        override fun onConnectionStateChange(device: BluetoothDevice?, status: Int, newState: Int) {
            super.onConnectionStateChange(device, status, newState)
            device?.let {
                when (newState) {
                    BluetoothProfile.STATE_CONNECTED -> {
                        Log.d(TAG, "Device connected: ${device.address}")
                        channel.invokeMethod("onDeviceConnected", mapOf("deviceId" to device.address))
                    }
                    BluetoothProfile.STATE_DISCONNECTED -> {
                        Log.d(TAG, "Device disconnected: ${device.address}")
                        connectedDevices.remove(device)
                        deviceCodes.remove(device)
                        channel.invokeMethod("onDeviceDisconnected", mapOf("deviceId" to device.address))
                    }
                }
            }
        }

        override fun onCharacteristicWriteRequest(
            device: BluetoothDevice?,
            requestId: Int,
            characteristic: BluetoothGattCharacteristic?,
            preparedWrite: Boolean,
            responseNeeded: Boolean,
            offset: Int,
            value: ByteArray?
        ) {
            super.onCharacteristicWriteRequest(device, requestId, characteristic, preparedWrite, responseNeeded, offset, value)

            device?.let { dev ->
                characteristic?.let { char ->
                    when (char.uuid) {
                        CODE_CHAR_UUID -> {
                            // Client is sending their game code for verification
                            val receivedCode = value?.let { String(it, Charsets.UTF_8) } ?: ""
                            Log.d(TAG, "Received code from ${dev.address}: $receivedCode")

                            if (receivedCode == gameCode) {
                                // Code matches - accept the connection
                                connectedDevices.add(dev)
                                deviceCodes[dev] = receivedCode

                                if (responseNeeded) {
                                    gattServer?.sendResponse(dev, requestId, BluetoothGatt.GATT_SUCCESS, offset, "ACCEPTED".toByteArray())
                                }

                                channel.invokeMethod("onPlayerJoined", mapOf(
                                    "deviceId" to dev.address,
                                    "playerName" to dev.address
                                ))
                            } else {
                                // Code doesn't match - reject
                                if (responseNeeded) {
                                    gattServer?.sendResponse(dev, requestId, BluetoothGatt.GATT_FAILURE, offset, "REJECTED".toByteArray())
                                }
                                // Disconnect the device
                                gattServer?.cancelConnection(dev)
                            }
                        }

                        PLAYER_ACTION_CHAR_UUID -> {
                            // Client is sending a player action
                            val action = value?.let { String(it, Charsets.UTF_8) } ?: ""
                            Log.d(TAG, "Received action from ${dev.address}: $action")

                            if (responseNeeded) {
                                gattServer?.sendResponse(dev, requestId, BluetoothGatt.GATT_SUCCESS, offset, null)
                            }

                            channel.invokeMethod("onPlayerAction", mapOf(
                                "deviceId" to dev.address,
                                "action" to action
                            ))
                        }
                    }
                }
            }
        }

        override fun onCharacteristicReadRequest(
            device: BluetoothDevice?,
            requestId: Int,
            offset: Int,
            characteristic: BluetoothGattCharacteristic?
        ) {
            super.onCharacteristicReadRequest(device, requestId, offset, characteristic)

            gattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, offset, null)
        }
    }

    fun startAdvertising(gameName: String, code: String): Boolean {
        gameCode = code

        bluetoothManager = context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
        bluetoothAdapter = bluetoothManager?.adapter

        if (bluetoothAdapter == null || !bluetoothAdapter!!.isEnabled) {
            Log.e(TAG, "Bluetooth not available or not enabled")
            return false
        }

        advertiser = bluetoothAdapter?.bluetoothLeAdvertiser
        if (advertiser == null) {
            Log.e(TAG, "BLE advertising not supported")
            return false
        }

        // Set up GATT server
        gattServer = bluetoothManager?.openGattServer(context, gattServerCallback)

        // Create service
        val service = BluetoothGattService(SERVICE_UUID, BluetoothGattService.SERVICE_TYPE_PRIMARY)

        // Add code characteristic (write only)
        val codeChar = BluetoothGattCharacteristic(
            CODE_CHAR_UUID,
            BluetoothGattCharacteristic.PROPERTY_WRITE,
            BluetoothGattCharacteristic.PERMISSION_WRITE
        )
        service.addCharacteristic(codeChar)

        // Add player action characteristic (write only)
        val actionChar = BluetoothGattCharacteristic(
            PLAYER_ACTION_CHAR_UUID,
            BluetoothGattCharacteristic.PROPERTY_WRITE,
            BluetoothGattCharacteristic.PERMISSION_WRITE
        )
        service.addCharacteristic(actionChar)

        // Add game state characteristic (read and notify)
        val stateChar = BluetoothGattCharacteristic(
            GAME_STATE_CHAR_UUID,
            BluetoothGattCharacteristic.PROPERTY_READ or BluetoothGattCharacteristic.PROPERTY_NOTIFY,
            BluetoothGattCharacteristic.PERMISSION_READ
        )

        // Add descriptor for notifications
        val descriptor = BluetoothGattDescriptor(
            UUID.fromString("00002902-0000-1000-8000-00805f9b34fb"),
            BluetoothGattDescriptor.PERMISSION_WRITE or BluetoothGattDescriptor.PERMISSION_READ
        )
        stateChar.addDescriptor(descriptor)
        service.addCharacteristic(stateChar)

        gattServer?.addService(service)

        // Start advertising
        val settings = AdvertiseSettings.Builder()
            .setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_BALANCED)
            .setConnectable(true)
            .setTimeout(0)
            .setTxPowerLevel(AdvertiseSettings.ADVERTISE_TX_POWER_MEDIUM)
            .build()

        val data = AdvertiseData.Builder()
            .setIncludeDeviceName(false)
            .addServiceUuid(ParcelUuid(SERVICE_UUID))
            .build()

        advertiser?.startAdvertising(settings, data, advertiseCallback)

        return true
    }

    fun stopAdvertising() {
        advertiser?.stopAdvertising(advertiseCallback)
        gattServer?.close()
        gattServer = null
        connectedDevices.clear()
        deviceCodes.clear()
    }

    fun sendGameState(state: String) {
        val service = gattServer?.getService(SERVICE_UUID)
        val characteristic = service?.getCharacteristic(GAME_STATE_CHAR_UUID)

        characteristic?.let { char ->
            char.value = state.toByteArray(Charsets.UTF_8)

            connectedDevices.forEach { device ->
                gattServer?.notifyCharacteristicChanged(device, char, false)
            }
        }
    }
}
