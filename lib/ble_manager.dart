import 'dart:async';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class BleDevice {
  final String deviceId;
  final String deviceName;
  final int rssi;

  BleDevice({
    required this.deviceId,
    required this.deviceName,
    required this.rssi,
  });

  factory BleDevice.fromMap(Map<dynamic, dynamic> map) {
    return BleDevice(
      deviceId: map['deviceId'] as String,
      deviceName: map['deviceName'] as String,
      rssi: map['rssi'] as int,
    );
  }
}

class BleManager {
  static final BleManager _instance = BleManager._internal();
  factory BleManager() => _instance;
  BleManager._internal() {
    _setupPlatformChannels();
  }

  static const peripheralChannel =
      MethodChannel('com.example.android_test/ble_peripheral');
  static const centralChannel =
      MethodChannel('com.example.android_test/ble_central');
  final StreamController<Map<String, dynamic>> _playerJoinedController =
      StreamController<Map<String, dynamic>>.broadcast();

  String? connectedDeviceId;
  List<String> connectedClientIds = [];

  final StreamController<String> _playerActionController =
      StreamController<String>.broadcast();
  final StreamController<String> _gameStateController =
      StreamController<String>.broadcast();
  final StreamController<String> _connectionStatusController =
      StreamController<String>.broadcast();

  Stream<String> get playerActionStream => _playerActionController.stream;
  Stream<String> get gameStateStream => _gameStateController.stream;
  Stream<String> get connectionStatusStream =>
      _connectionStatusController.stream;
  Stream<Map<String, dynamic>> get playerJoinedStream =>
      _playerJoinedController.stream;

  void _setupPlatformChannels() {
    // Setup peripheral channel callbacks (for hosting/server mode)
    peripheralChannel.setMethodCallHandler((call) {
      final args = call.arguments as Map<dynamic, dynamic>?;
      switch (call.method) {
        case 'onAdvertisingStarted':
          _connectionStatusController.add("Advertising started successfully");
          break;
        case 'onAdvertisingFailed':
          final errorCode = args?['errorCode'];
          _connectionStatusController.add("Advertising failed: $errorCode");
          break;
        case 'onDeviceConnected':
          final deviceId = args?['deviceId'];
          _connectionStatusController.add("Device connected: $deviceId");
          break;
        case 'onDeviceDisconnected':
          final deviceId = args?['deviceId'];
          _connectionStatusController.add("Device disconnected: $deviceId");
          break;
        case 'onPlayerJoined':
          final deviceId = args?['deviceId'];
          final playerName = args?['playerName'];
          _playerJoinedController.add({
            'deviceId': deviceId,
            'playerName': playerName,
          });
          _connectionStatusController.add("Player joined: $playerName");
          break;
        case 'onPlayerAction':
          final action = args?['action'];
          _playerActionController.add(action);
          break;
      }
      return Future.value(null);
    });

    // Setup central channel callbacks (for client/scanner mode)
    centralChannel.setMethodCallHandler((call) {
      final args = call.arguments as Map<dynamic, dynamic>?;
      switch (call.method) {
        case 'onScanFailed':
          final errorCode = args?['errorCode'];
          _connectionStatusController.add("Scan failed: $errorCode");
          break;
        case 'onConnectionAccepted':
          _connectionStatusController.add("Connected successfully");
          break;
        case 'onConnectionRejected':
          final reason = args?['reason'] ?? 'Unknown reason';
          _connectionStatusController.add("Connection rejected: $reason");
          break;
        case 'onConnectionFailed':
          final error = args?['error'] ?? 'Unknown error';
          _connectionStatusController.add("Connection failed: $error");
          break;
        case 'onGameStateReceived':
          final state = args?['state'];
          if (state != null) {
            _gameStateController.add(state);
          }
          break;
      }
      return Future.value(null);
    });
  }

  // Request BLE permissions
  Future<bool> requestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.bluetoothAdvertise,
      Permission.location,
    ].request();

    return statuses.values.every((status) => status.isGranted);
  }

  // Check if Bluetooth is available and on
  Future<bool> isBluetoothAvailable() async {
    try {
      final result = await centralChannel.invokeMethod('isBluetoothAvailable');
      return result as bool;
    } catch (e) {
      return false;
    }
  }

  // Host: Start advertising using native Android BLE peripheral mode
  Future<bool> startHosting(String gameName, String gameCode) async {
    try {
      final result = await peripheralChannel.invokeMethod('startAdvertising', {
        'gameName': gameName,
        'gameCode': gameCode,
      });
      return result as bool;
    } catch (e) {
      _connectionStatusController.add("Failed to start hosting: $e");
      return false;
    }
  }

  // Host: Stop advertising
  Future<void> stopHosting() async {
    try {
      await peripheralChannel.invokeMethod('stopAdvertising');
    } catch (e) {
      _connectionStatusController.add("Failed to stop hosting: $e");
    }
  }

  // Client: Scan for games
  Future<List<BleDevice>> scanForGames() async {
    try {
      // Start scanning
      await centralChannel.invokeMethod('startScan', {
        'timeoutSeconds': 4,
      });

      // Wait for scan to complete
      await Future.delayed(const Duration(seconds: 4, milliseconds: 100));

      // Get scan results
      final results = await centralChannel.invokeMethod('getScanResults');
      final List<BleDevice> devices = [];

      if (results is List) {
        for (var result in results) {
          if (result is Map) {
            devices.add(BleDevice.fromMap(result));
          }
        }
      }

      return devices;
    } catch (e) {
      _connectionStatusController.add("Scan failed: $e");
      return [];
    }
  }

  // Client: Connect to host and send game code
  Future<bool> connectToHost(BleDevice device, String gameCode) async {
    try {
      final result = await centralChannel.invokeMethod('connectToDevice', {
        'deviceAddress': device.deviceId,
        'gameCode': gameCode,
      });

      if (result as bool) {
        connectedDeviceId = device.deviceId;
        return true;
      }
      return false;
    } catch (e) {
      _connectionStatusController.add("Connection failed: $e");
      return false;
    }
  }

  // Client: Send player action to host
  Future<void> sendPlayerAction(String action) async {
    if (connectedDeviceId == null) return;

    try {
      await centralChannel.invokeMethod('sendPlayerAction', {
        'action': action,
      });
    } catch (e) {
      _connectionStatusController.add("Failed to send action: $e");
    }
  }

  // Host: Send game state to all clients
  Future<void> sendGameState(String state) async {
    try {
      await peripheralChannel.invokeMethod('sendGameState', {
        'state': state,
      });
    } catch (e) {
      _connectionStatusController.add("Failed to send game state: $e");
    }
  }

  // Disconnect
  Future<void> disconnect() async {
    // Stop hosting if we're a host
    await stopHosting();

    // Disconnect if we're a client
    if (connectedDeviceId != null) {
      try {
        await centralChannel.invokeMethod('disconnect');
        connectedDeviceId = null;
      } catch (e) {
        _connectionStatusController.add("Failed to disconnect: $e");
      }
    }

    connectedClientIds.clear();
  }

  void dispose() {
    _playerActionController.close();
    _gameStateController.close();
    _connectionStatusController.close();
    _playerJoinedController.close();
  }
}
