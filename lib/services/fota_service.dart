// @file       fota_service.dart
// @brief      Service for FOTA.

/* Imports ------------------------------------------------------------ */
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../config/app_constants.dart';

/* Enums -------------------------------------------------------------- */
enum FotaState {
  idle,
  connecting,
  waitingAppSelection,
  sendingInfo,
  sendingData,
  waitingEnd,
  sendingUpdate,
  completed,
  error,
}

// ACK results
enum AckResult { ack, nack, timeout, error }

// Configuration timeouts (seconds) - similar to bootloader_usb
/* Public classes ----------------------------------------------------- */
class FotaConfig {
  static const double appSelectionTimeout = 30.0;
  static const double ackTimeoutDefault = 30.0;
  static const double ackTimeoutInfo = 30.0;
  static const double ackTimeoutDataBlock = 10.0;
  static const double ackTimeoutEnd = 5.0;
  static const double endBeforeUpdateDelay = 5.0;
  static const int chunkSize = 512;
  static const int maxRetries = 5;
}

class FotaService {
  // Singleton
  static final FotaService _instance = FotaService._internal();
  factory FotaService() => _instance;
  FotaService._internal();

  // BLE
  BluetoothDevice? _device;
  BluetoothCharacteristic? _characteristic;
  StreamSubscription? _notifySubscription;

  // Buffer nhận
  final StringBuffer _receiveBuffer = StringBuffer();

  // Streams
  final _stateController = StreamController<FotaState>.broadcast();
  final _progressController = StreamController<double>.broadcast();
  final _logController = StreamController<String>.broadcast();

  Stream<FotaState> get stateStream => _stateController.stream;
  Stream<double> get progressStream => _progressController.stream;
  Stream<String> get logStream => _logController.stream;

  FotaState _currentState = FotaState.idle;
  FotaState get currentState => _currentState;

  bool get isConnected => _device != null && _characteristic != null;

  // Log helper
  void _log(String message) {
    final timestamp = DateTime.now().toString().substring(11, 19);
    _logController.add('[$timestamp] $message');
  }

  // Update state
  void _setState(FotaState state) {
    _currentState = state;
    _stateController.add(state);
  }

  // Khởi tạo với device đã kết nối
  Future<bool> initWithConnectedDevice(BluetoothDevice device) async {
    try {
      _device = device;
      _log('[FOTA] Initializing with device: ${device.remoteId}');

      // Discover services
      final services = await device.discoverServices();
      _log('[FOTA] Found ${services.length} services');

      // Tìm characteristic FFE1
      for (final service in services) {
        final serviceUuid = service.uuid.toString().toLowerCase();
        if (serviceUuid == BluetoothConfig.serviceUuid.toLowerCase() ||
            serviceUuid.endsWith('ffe0')) {
          for (final char in service.characteristics) {
            final charUuid = char.uuid.toString().toLowerCase();
            if (charUuid == BluetoothConfig.characteristicUuid.toLowerCase() ||
                charUuid.endsWith('ffe1')) {
              _characteristic = char;
              _log('[FOTA] Found characteristic: ${char.uuid}');
              break;
            }
          }
        }
      }

      if (_characteristic == null) {
        _log('[ERROR] No characteristic FFE1 found!');
        return false;
      }

      // Subscribe notification
      await _characteristic!.setNotifyValue(true);
      _notifySubscription = _characteristic!.onValueReceived.listen(
        _onDataReceived,
      );
      _log('[FOTA] Subscribe notification successful');

      return true;
    } catch (e) {
      _log('[ERROR] Initializing FOTA failed: $e');
      return false;
    }
  }

  // Xử lý data nhận được
  void _onDataReceived(List<int> data) {
    final decoded = String.fromCharCodes(data);
    _receiveBuffer.write(decoded);
    _log('[RX] (${data.length} bytes): $decoded');
  }

  // Đợi ACK/NACK
  Future<AckResult> _waitForAck({
    double timeout = FotaConfig.ackTimeoutDefault,
  }) async {
    _receiveBuffer.clear();
    final startTime = DateTime.now();

    while (DateTime.now().difference(startTime).inMilliseconds <
        timeout * 1000) {
      await Future.delayed(const Duration(milliseconds: 50));

      final buffer = _receiveBuffer.toString();
      if (buffer.contains('NACK')) {
        _log('[WARN] NACK detected');
        return AckResult.nack;
      }
      if (buffer.contains('ACK')) {
        _log('[INFO] ACK detected');
        return AckResult.ack;
      }
    }

    _log('[WARN] Timeout waiting for ACK');
    return AckResult.timeout;
  }

  // Đợi APP_1 hoặc APP_2
  Future<String?> _waitForAppSelection({
    double timeout = FotaConfig.appSelectionTimeout,
  }) async {
    _receiveBuffer.clear();
    final startTime = DateTime.now();

    while (DateTime.now().difference(startTime).inMilliseconds <
        timeout * 1000) {
      await Future.delayed(const Duration(milliseconds: 50));

      final buffer = _receiveBuffer.toString();
      if (buffer.contains('APP_1')) {
        _log('[INFO] MCU selected APP_1');
        return 'APP_1';
      }
      if (buffer.contains('APP_2')) {
        _log('[INFO] MCU selected APP_2');
        return 'APP_2';
      }
    }

    _log('[WARN] Timeout waiting for APP selection');
    return null;
  }

  // Gửi command và đợi ACK với retry
  Future<bool> _sendCommandWithAck(
    String command, {
    int retries = FotaConfig.maxRetries,
    double timeout = FotaConfig.ackTimeoutDefault,
  }) async {
    if (_characteristic == null) return false;

    for (int i = 0; i < retries; i++) {
      try {
        _log('[TX] $command');
        await _characteristic!.write(command.codeUnits, withoutResponse: false);

        final result = await _waitForAck(timeout: timeout);
        if (result == AckResult.ack) {
          return true;
        } else if (result == AckResult.nack) {
          _log('[WARN] NACK, retrying... (${i + 1}/$retries)');
          continue;
        }
      } catch (e) {
        _log('[ERROR] Send command failed: $e');
      }
    }

    return false;
  }

  // Tính checksum (giống bootloader_usb)
  int _calcChecksum(Uint8List data) {
    int crc = 0;
    for (final b in data) {
      crc = (crc + b) & 0xFF;
    }
    return crc;
  }

  // Bắt đầu quá trình update
  Future<bool> startUpdate({
    required Uint8List app1Data,
    required Uint8List app2Data,
  }) async {
    if (_characteristic == null) {
      _log('[ERROR] Characteristic not initialized');
      _setState(FotaState.error);
      return false;
    }

    try {
      _setState(FotaState.connecting);
      _progressController.add(0);

      // Step 1: Send START
      _log('[TX] START');
      await _characteristic!.write('START'.codeUnits, withoutResponse: false);

      // Step 2: Wait for APP_1 or APP_2
      _setState(FotaState.waitingAppSelection);
      final selection = await _waitForAppSelection();
      if (selection == null) {
        _log('[ERROR] Không nhận được APP selection từ MCU');
        _setState(FotaState.error);
        return false;
      }

      // Chọn firmware theo selection
      final firmwareData = selection == 'APP_1' ? app1Data : app2Data;
      final total = firmwareData.length;
      _log('[INFO] Selected $selection, size: $total bytes');

      // Step 3: Send INFO=size,checksum
      _setState(FotaState.sendingInfo);
      final checksum = _calcChecksum(firmwareData);
      final infoCmd = 'INFO=$total,$checksum';

      if (!await _sendCommandWithAck(
        infoCmd,
        timeout: FotaConfig.ackTimeoutInfo,
      )) {
        _log('[ERROR] Không nhận được ACK cho INFO');
        _setState(FotaState.error);
        return false;
      }

      // Step 4: Send data in chunks
      _setState(FotaState.sendingData);
      final totalBlocks =
          (total + FotaConfig.chunkSize - 1) ~/ FotaConfig.chunkSize;
      int sentBytes = 0;
      int ackBlocks = 0;

      while (sentBytes < total) {
        final end = (sentBytes + FotaConfig.chunkSize).clamp(0, total);
        final chunk = firmwareData.sublist(sentBytes, end);

        try {
          await _characteristic!.write(chunk, withoutResponse: false);
        } catch (e) {
          _log('[ERROR] Send chunk failed: $e');
          _setState(FotaState.error);
          return false;
        }

        final ackResult = await _waitForAck(
          timeout: FotaConfig.ackTimeoutDataBlock,
        );
        if (ackResult == AckResult.ack) {
          sentBytes = end;
          ackBlocks++;
          final progress = (ackBlocks * 95 / totalBlocks).clamp(0.0, 95.0);
          _progressController.add(progress);
          _log(
            '[PROGRESS] Block $ackBlocks/$totalBlocks (${progress.toStringAsFixed(1)}%)',
          );
        } else if (ackResult == AckResult.nack) {
          // Restart from beginning
          _log('[WARN] NACK received, restarting transfer...');
          sentBytes = 0;
          ackBlocks = 0;
          _progressController.add(0);
          continue;
        } else {
          _log('[ERROR] Timeout waiting for ACK');
          _setState(FotaState.error);
          return false;
        }
      }

      // Step 5: Wait before END
      _setState(FotaState.waitingEnd);
      _log('[INFO] Waiting ${FotaConfig.endBeforeUpdateDelay}s before END...');
      await Future.delayed(
        Duration(seconds: FotaConfig.endBeforeUpdateDelay.toInt()),
      );

      // Step 6: Send END
      if (!await _sendCommandWithAck(
        'END',
        timeout: FotaConfig.ackTimeoutEnd,
      )) {
        _log('[ERROR] Không nhận được ACK cho END');
        _setState(FotaState.error);
        return false;
      }

      _progressController.add(100);
      _log('[INFO] File transmitted successfully!');
      _setState(FotaState.completed);
      return true;
    } catch (e) {
      _log('[ERROR] Update failed: $e');
      _setState(FotaState.error);
      return false;
    }
  }

  // Gửi lệnh UPDATE để MCU cập nhật firmware
  Future<bool> sendUpdateCommand() async {
    if (_characteristic == null) return false;

    try {
      _setState(FotaState.sendingUpdate);
      _log('[TX] UPDATE');
      await _characteristic!.write('UPDATE'.codeUnits, withoutResponse: false);
      _log('[INFO] UPDATE command sent successfully');
      return true;
    } catch (e) {
      _log('[ERROR] Send UPDATE failed: $e');
      return false;
    }
  }

  // Reset state
  void reset() {
    _receiveBuffer.clear();
    _setState(FotaState.idle);
    _progressController.add(0);
    _log('[INFO] FOTA state reset');
  }

  // Dispose
  void dispose() {
    _notifySubscription?.cancel();
    _stateController.close();
    _progressController.close();
    _logController.close();
  }
}

/* End of file -------------------------------------------------------- */
