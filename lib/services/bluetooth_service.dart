// @file       bluetooth_service.dart
// @brief      Service for Bluetooth.

/* Imports ------------------------------------------------------------ */
import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../config/app_constants.dart';
import '../models/route_point.dart';
import '../models/bluetooth_device_info.dart';

/* Public classes ----------------------------------------------------- */
class BluetoothService {
  // Singleton
  static final BluetoothService _instance = BluetoothService._internal();
  factory BluetoothService() => _instance;
  BluetoothService._internal();

  // State
  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _characteristic;
  StreamSubscription? _scanSubscription;
  StreamSubscription? _connectionSubscription;
  StreamSubscription? _characteristicSubscription;

  // Buffer
  String _dataBuffer = '';
  final List<RoutePoint> _receivedPoints = [];

  // Streams
  final _deviceStreamController =
      StreamController<List<BluetoothDeviceInfo>>.broadcast();
  final _connectionStateController =
      StreamController<AppBluetoothConnectionState>.broadcast();
  final _dataStreamController = StreamController<RoutePoint>.broadcast();
  final _pointsCountController = StreamController<int>.broadcast();
  final _rawDataController = StreamController<String>.broadcast();

  // Debug log stream
  final _debugLogController = StreamController<String>.broadcast();

  // Getters
  Stream<List<BluetoothDeviceInfo>> get devicesStream =>
      _deviceStreamController.stream;
  Stream<AppBluetoothConnectionState> get connectionStateStream =>
      _connectionStateController.stream;
  Stream<RoutePoint> get dataStream => _dataStreamController.stream;
  Stream<int> get pointsCountStream => _pointsCountController.stream;
  Stream<String> get rawDataStream => _rawDataController.stream;
  Stream<String> get debugLogStream => _debugLogController.stream;

  List<RoutePoint> get receivedPoints => List.unmodifiable(_receivedPoints);
  bool get isConnected => _connectedDevice != null;

  // Kiểm tra Bluetooth khả dụng
  Future<bool> isBluetoothAvailable() async {
    return await FlutterBluePlus.isSupported;
  }

  // Kiểm tra Bluetooth đang bật
  Future<bool> isBluetoothOn() async {
    final state = await FlutterBluePlus.adapterState.first;
    return state == BluetoothAdapterState.on;
  }

  // Bắt đầu scan thiết bị
  Future<void> startScan() async {
    final isOn = await isBluetoothOn();
    if (!isOn) {
      throw Exception('Bluetooth not enabled');
    }

    // Stop scan cũ nếu có
    await stopScan();

    final devices = <String, BluetoothDeviceInfo>{};

    _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      for (final result in results) {
        final device = BluetoothDeviceInfo(
          id: result.device.remoteId.str,
          name: result.device.platformName,
          rssi: result.rssi,
        );
        devices[device.id] = device;
      }
      _deviceStreamController.add(devices.values.toList());
    });

    await FlutterBluePlus.startScan(
      timeout: const Duration(seconds: BluetoothConfig.scanTimeoutSeconds),
      androidUsesFineLocation: true,
    );
  }

  // Dừng scan
  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
    await _scanSubscription?.cancel();
    _scanSubscription = null;
  }

  // Kết nối thiết bị
  Future<void> connect(String deviceId) async {
    try {
      _connectionStateController.add(AppBluetoothConnectionState.connecting);
      _debugLogController.add('[CONNECT] Connecting to: $deviceId');

      // Tìm device
      final device = BluetoothDevice.fromId(deviceId);

      // Kết nối
      await device.connect(
        timeout: const Duration(
          seconds: BluetoothConfig.connectionTimeoutSeconds,
        ),
      );

      _connectedDevice = device;
      _debugLogController.add('[CONNECT] Connected successfully');

      // Discover services
      final services = await device.discoverServices();
      _debugLogController.add(
        '[DISCOVER] Found ${services.length} services',
      );

      // Log all services and characteristics for debugging
      for (final service in services) {
        _debugLogController.add('[SERVICE] ${service.uuid}');
        for (final char in service.characteristics) {
          final props = <String>[];
          if (char.properties.read) props.add('R');
          if (char.properties.write) props.add('W');
          if (char.properties.writeWithoutResponse) props.add('WNR');
          if (char.properties.notify) props.add('N');
          if (char.properties.indicate) props.add('I');
          _debugLogController.add('  [CHAR] ${char.uuid} [${props.join(",")}]');
        }
      }

      // Find target characteristic (FFE1 or UUID match)
      for (final service in services) {
        final serviceUuid = service.uuid.toString().toLowerCase();
        if (serviceUuid == BluetoothConfig.serviceUuid.toLowerCase() ||
            serviceUuid.endsWith('ffe0')) {
          _debugLogController.add(
            '[MATCH] Found target service: ${service.uuid}',
          );
          for (final char in service.characteristics) {
            final charUuid = char.uuid.toString().toLowerCase();
            if (charUuid == BluetoothConfig.characteristicUuid.toLowerCase() ||
                charUuid.endsWith('ffe1')) {
              _characteristic = char;
              _debugLogController.add(
                '[MATCH] Found target characteristic: ${char.uuid}',
              );
              break;
            }
          }
        }
      }
      if (_characteristic == null) {
        _debugLogController.add(
          '[ERROR] Could not find the correct characteristic FFE1 in service FFE0 to subscribe to notifications!',
        );
        // Do not select any other notify characteristic (especially 2A05)
      }

      if (_characteristic != null) {
        // Subscribe to notifications
        _debugLogController.add('[NOTIFY] Đang subscribe notification...');
        await _characteristic!.setNotifyValue(true);
        _characteristicSubscription = _characteristic!.onValueReceived.listen(
          _onDataReceived,
        );
        _debugLogController.add(
          '[NOTIFY] Subscribe thành công! Sẵn sàng nhận data.',
        );
      } else {
        _debugLogController.add(
          '[ERROR] Không tìm thấy characteristic phù hợp!',
        );
      }

      // Listen connection state
      _connectionSubscription = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _handleDisconnect();
        }
      });

      _connectionStateController.add(AppBluetoothConnectionState.connected);
    } catch (e) {
      _debugLogController.add('[ERROR] Kết nối thất bại: $e');
      _connectionStateController.add(AppBluetoothConnectionState.disconnected);
      rethrow;
    }
  }

  // Disconnect
  Future<void> disconnect() async {
    _connectionStateController.add(AppBluetoothConnectionState.disconnecting);

    await _characteristicSubscription?.cancel();
    await _connectionSubscription?.cancel();

    if (_connectedDevice != null) {
      await _connectedDevice!.disconnect();
    }

    _handleDisconnect();
  }

  // Handle disconnection cleanup
  void _handleDisconnect() {
    _connectedDevice = null;
    _characteristic = null;
    _characteristicSubscription = null;
    _connectionSubscription = null;
    _connectionStateController.add(AppBluetoothConnectionState.disconnected);
  }

  // Handle received data
  void _onDataReceived(List<int> data) {
    _debugLogController.add('[RAW] Received ${data.length} bytes: $data');

    final decoded = utf8.decode(data, allowMalformed: true);
    _debugLogController.add('[DECODED] $decoded');
    _dataBuffer += decoded;

    // Emit raw data for debug
    _rawDataController.add(decoded);

    // Normalize line endings: \r\n -> \n, \r -> \n
    _dataBuffer = _dataBuffer.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

    // Process each line
    final lines = _dataBuffer.split(BluetoothConfig.lineDelimiter);
    _dataBuffer = lines.removeLast(); // Keep the incomplete part

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isNotEmpty) {
        _parseLine(trimmed);
      }
    }
  }

  // Parse one line of data into RoutePoint
  void _parseLine(String line) {
    try {
      RoutePoint? point;

      // Format 1: JSON
      if (line.startsWith('{')) {
        final json = jsonDecode(line) as Map<String, dynamic>;
        point = RoutePoint.fromJson(json);
      }
      // Format 2: NMEA GPGGA
      else if (line.startsWith('\$GPGGA') || line.startsWith('\$GNGGA')) {
        point = _parseNMEA(line);
      }
      // Format 3: Simple CSV (lat,lng or lat,lng,name)
      else if (line.contains(',')) {
        point = RoutePoint.fromSimpleLine(line);
      }

      // Validate và thêm point
      if (point != null && point.isValid) {
        _receivedPoints.add(point);

        // Giới hạn buffer size
        if (_receivedPoints.length > BluetoothConfig.maxBufferSize) {
          _receivedPoints.removeAt(0);
        }

        _dataStreamController.add(point);
        _pointsCountController.add(_receivedPoints.length);
      }
    } catch (e) {
      // Ignore invalid lines
      print('Failed to parse line: $line - $e');
    }
  }

  // Parse NMEA GPGGA sentence
  RoutePoint? _parseNMEA(String sentence) {
    final parts = sentence.split(',');
    if (parts.length < 10) return null;

    final latRaw = parts[2];
    final latDir = parts[3];
    final lngRaw = parts[4];
    final lngDir = parts[5];
    final quality = int.tryParse(parts[6]) ?? 0;

    // Skip invalid fix
    if (quality == 0) return null;

    final lat = _nmeaToDecimal(latRaw, latDir, false);
    final lng = _nmeaToDecimal(lngRaw, lngDir, true);

    if (lat == null || lng == null) return null;

    return RoutePoint(latitude: lat, longitude: lng, timestamp: DateTime.now());
  }

  // Convert NMEA to decimal degrees
  double? _nmeaToDecimal(String coord, String dir, bool isLng) {
    if (coord.isEmpty || dir.isEmpty) return null;

    final degLen = isLng ? 3 : 2;
    final degrees = int.tryParse(coord.substring(0, degLen)) ?? 0;
    final minutes = double.tryParse(coord.substring(degLen)) ?? 0;

    var decimal = degrees + (minutes / 60);

    if (dir == 'S' || dir == 'W') {
      decimal = -decimal;
    }

    return decimal;
  }

  // Gửi dữ liệu
  Future<void> sendData(String data) async {
    if (_characteristic == null) {
      throw Exception('Chưa kết nối');
    }

    await _characteristic!.write(
      utf8.encode(data),
      withoutResponse: _characteristic!.properties.writeWithoutResponse,
    );
  }

  // Xóa buffer
  void clearBuffer() {
    _receivedPoints.clear();
    _dataBuffer = '';
    _pointsCountController.add(0);
  }

  // Dispose
  void dispose() {
    _scanSubscription?.cancel();
    _connectionSubscription?.cancel();
    _characteristicSubscription?.cancel();
    _deviceStreamController.close();
    _connectionStateController.close();
    _dataStreamController.close();
    _pointsCountController.close();
  }
}

/* End of file -------------------------------------------------------- */
