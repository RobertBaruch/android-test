import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class BleManager {
  static final BleManager _instance = BleManager._internal();
  factory BleManager() => _instance;
  BleManager._internal();

  // UUIDs for our service and characteristics
  static final Guid serviceUuid = Guid("12345678-1234-5678-1234-56789abcdef0");
  static final Guid codeCharUuid = Guid("12345678-1234-5678-1234-56789abcdef1");
  static final Guid playerActionCharUuid = Guid("12345678-1234-5678-1234-56789abcdef2");
  static final Guid gameStateCharUuid = Guid("12345678-1234-5678-1234-56789abcdef3");

  BluetoothDevice? connectedDevice;
  List<BluetoothDevice> connectedClients = [];

  final StreamController<String> _playerActionController = StreamController<String>.broadcast();
  final StreamController<String> _gameStateController = StreamController<String>.broadcast();
  final StreamController<String> _connectionStatusController = StreamController<String>.broadcast();

  Stream<String> get playerActionStream => _playerActionController.stream;
  Stream<String> get gameStateStream => _gameStateController.stream;
  Stream<String> get connectionStatusStream => _connectionStatusController.stream;

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
    if (await FlutterBluePlus.isSupported == false) {
      return false;
    }

    // Check if Bluetooth is on
    var adapterState = await FlutterBluePlus.adapterState.first;
    return adapterState == BluetoothAdapterState.on;
  }

  // Host: Start advertising (Note: BLE peripheral mode is limited on Android)
  Future<void> startHosting(String gameName, String gameCode) async {
    // Note: flutter_blue_plus doesn't support peripheral mode (advertising)
    // For a full implementation, you would need to use platform channels
    // to access Android's BluetoothLeAdvertiser
    //
    // For now, this is a placeholder that would need native Android code
    _connectionStatusController.add("Hosting started: $gameName ($gameCode)");
  }

  // Client: Scan for games
  Future<List<ScanResult>> scanForGames() async {
    List<ScanResult> results = [];

    // Start scanning
    await FlutterBluePlus.startScan(
      timeout: const Duration(seconds: 4),
      withServices: [serviceUuid],
    );

    // Listen to scan results
    var subscription = FlutterBluePlus.scanResults.listen((scanResults) {
      results = scanResults;
    });

    // Wait for scan to complete
    await Future.delayed(const Duration(seconds: 4));

    // Stop scanning
    await FlutterBluePlus.stopScan();
    await subscription.cancel();

    return results;
  }

  // Client: Connect to host and send game code
  Future<bool> connectToHost(BluetoothDevice device, String gameCode) async {
    try {
      await device.connect();
      connectedDevice = device;

      // Discover services
      List<BluetoothService> services = await device.discoverServices();

      // Find our service
      BluetoothService? ourService;
      for (var service in services) {
        if (service.uuid == serviceUuid) {
          ourService = service;
          break;
        }
      }

      if (ourService == null) {
        await device.disconnect();
        return false;
      }

      // Find code characteristic and send code
      for (var characteristic in ourService.characteristics) {
        if (characteristic.uuid == codeCharUuid) {
          await characteristic.write(utf8.encode(gameCode));

          // Read response to see if code was accepted
          var response = await characteristic.read();
          String responseStr = utf8.decode(response);

          if (responseStr == "ACCEPTED") {
            // Subscribe to game state updates
            await _subscribeToGameState(ourService);
            _connectionStatusController.add("Connected successfully");
            return true;
          } else {
            await device.disconnect();
            _connectionStatusController.add("Invalid game code");
            return false;
          }
        }
      }

      await device.disconnect();
      return false;
    } catch (e) {
      _connectionStatusController.add("Connection failed: $e");
      return false;
    }
  }

  // Subscribe to game state updates from host
  Future<void> _subscribeToGameState(BluetoothService service) async {
    for (var characteristic in service.characteristics) {
      if (characteristic.uuid == gameStateCharUuid) {
        await characteristic.setNotifyValue(true);
        characteristic.lastValueStream.listen((value) {
          if (value.isNotEmpty) {
            String message = utf8.decode(value);
            _gameStateController.add(message);
          }
        });
      }
    }
  }

  // Client: Send player action to host
  Future<void> sendPlayerAction(String action) async {
    if (connectedDevice == null) return;

    try {
      List<BluetoothService> services = await connectedDevice!.discoverServices();

      for (var service in services) {
        if (service.uuid == serviceUuid) {
          for (var characteristic in service.characteristics) {
            if (characteristic.uuid == playerActionCharUuid) {
              await characteristic.write(utf8.encode(action));
              return;
            }
          }
        }
      }
    } catch (e) {
      _connectionStatusController.add("Failed to send action: $e");
    }
  }

  // Host: Send game state to all clients
  Future<void> sendGameState(String state) async {
    // This would need to be implemented with platform channels
    // to properly support BLE peripheral mode
    _connectionStatusController.add("Sending state: $state");
  }

  // Disconnect
  Future<void> disconnect() async {
    if (connectedDevice != null) {
      await connectedDevice!.disconnect();
      connectedDevice = null;
    }

    for (var client in connectedClients) {
      await client.disconnect();
    }
    connectedClients.clear();
  }

  void dispose() {
    _playerActionController.close();
    _gameStateController.close();
    _connectionStatusController.close();
  }
}
