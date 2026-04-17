// @file       bluetooth_provider.dart
// @brief      State provider for Bluetooth.

/* Imports ------------------------------------------------------------ */
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../models/bluetooth_device_info.dart';
import '../models/route_point.dart';
import '../services/bluetooth_service.dart' as app_bt;

/* Public classes ----------------------------------------------------- */
class BluetoothProvider extends ChangeNotifier {
  final app_bt.BluetoothService _btService = app_bt.BluetoothService();

  List<BluetoothDeviceInfo> _devices = [];
  AppBluetoothConnectionState _connectionState =
      AppBluetoothConnectionState.disconnected;
  BluetoothDeviceInfo? _connectedDevice;
  bool _isScanning = false;
  int _receivedPointsCount = 0;
  String? _error;

  StreamSubscription? _devicesSub;
  StreamSubscription? _connectionSub;
  StreamSubscription? _pointsCountSub;

  // Getters
  List<BluetoothDeviceInfo> get devices => List.unmodifiable(_devices);
  AppBluetoothConnectionState get connectionState => _connectionState;
  BluetoothDeviceInfo? get connectedDevice => _connectedDevice;
  bool get isScanning => _isScanning;
  bool get isConnected =>
      _connectionState == AppBluetoothConnectionState.connected;
  bool get isConnecting =>
      _connectionState == AppBluetoothConnectionState.connecting;
  int get receivedPointsCount => _receivedPointsCount;
  String? get error => _error;
  List<RoutePoint> get receivedPoints => _btService.receivedPoints;

  // Getter cho BluetoothDevice thực (để FOTA sử dụng)
  BluetoothDevice? get connectedBleDevice => _connectedDevice != null
      ? BluetoothDevice.fromId(_connectedDevice!.id)
      : null;

  // Stream để UI subscribe
  Stream<RoutePoint> get dataStream => _btService.dataStream;
  Stream<AppBluetoothConnectionState> get connectionStateStream =>
      _btService.connectionStateStream;

  BluetoothProvider() {
    _initStreams();
  }

  void _initStreams() {
    _devicesSub = _btService.devicesStream.listen((devices) {
      _devices = devices;
      notifyListeners();
    });

    _connectionSub = _btService.connectionStateStream.listen((state) {
      _connectionState = state;
      if (state == AppBluetoothConnectionState.disconnected) {
        _connectedDevice = null;
      }
      notifyListeners();
    });

    _pointsCountSub = _btService.pointsCountStream.listen((count) {
      _receivedPointsCount = count;
      notifyListeners();
    });
  }

  // Check if Bluetooth is available on the device
  Future<bool> checkBluetoothAvailable() async {
    return await _btService.isBluetoothAvailable();
  }

  // Check if Bluetooth is turned on
  Future<bool> checkBluetoothOn() async {
    return await _btService.isBluetoothOn();
  }

  // Start scanning for devices
  Future<void> startScan() async {
    _clearError();
    _isScanning = true;
    _devices = [];
    notifyListeners();

    try {
      await _btService.startScan();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _isScanning = false;
      notifyListeners();
    }
  }

  // Stop scanning
  Future<void> stopScan() async {
    await _btService.stopScan();
    _isScanning = false;
    notifyListeners();
  }

  // Connect to a device
  Future<void> connect(BluetoothDeviceInfo device) async {
    _clearError();

    try {
      _connectedDevice = device.copyWith(
        connectionState: AppBluetoothConnectionState.connecting,
      );
      notifyListeners();

      await _btService.connect(device.id);

      _connectedDevice = device.copyWith(
        connectionState: AppBluetoothConnectionState.connected,
      );
    } catch (e) {
      _connectedDevice = null;
      _setError('Kết nối thất bại: ${e.toString()}');
    }
    notifyListeners();
  }

  // Disconnect from device
  Future<void> disconnect() async {
    await _btService.disconnect();
    _connectedDevice = null;
    notifyListeners();
  }

  // Delete all received points
  void clearBuffer() {
    _btService.clearBuffer();
    _receivedPointsCount = 0;
    notifyListeners();
  }

  // Send data to the connected device
  Future<void> sendData(String data) async {
    try {
      await _btService.sendData(data);
    } catch (e) {
      _setError('Failed to send data: ${e.toString()}');
    }
  }

  void _setError(String message) {
    _error = message;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
  }

  @override
  void dispose() {
    _devicesSub?.cancel();
    _connectionSub?.cancel();
    _pointsCountSub?.cancel();
    _btService.dispose();
    super.dispose();
  }
}

/* End of file -------------------------------------------------------- */
