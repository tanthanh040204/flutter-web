import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../services/fota_service.dart';

/// ============================================
/// FOTA PROVIDER - State management cho FOTA
/// ============================================

class FotaProvider extends ChangeNotifier {
  final FotaService _fotaService = FotaService();

  // State
  FotaState _state = FotaState.idle;
  double _progress = 0;
  final List<String> _logs = [];
  String? _error;

  // Firmware files
  Uint8List? _app1Data;
  Uint8List? _app2Data;
  String? _app1FileName;
  String? _app2FileName;

  // Subscriptions
  bool _isInitialized = false;

  // Getters
  FotaState get state => _state;
  double get progress => _progress;
  List<String> get logs => List.unmodifiable(_logs);
  String? get error => _error;
  bool get isReady => _app1Data != null && _app2Data != null;
  String? get app1FileName => _app1FileName;
  String? get app2FileName => _app2FileName;
  bool get isUpdating => _state != FotaState.idle && 
                         _state != FotaState.completed && 
                         _state != FotaState.error;
  bool get isCompleted => _state == FotaState.completed;
  bool get hasError => _state == FotaState.error;

  /// Khởi tạo với device đã kết nối
  Future<bool> initWithDevice(BluetoothDevice device) async {
    if (_isInitialized) return true;

    final success = await _fotaService.initWithConnectedDevice(device);
    if (success) {
      _isInitialized = true;
      
      // Listen to state changes
      _fotaService.stateStream.listen((state) {
        _state = state;
        notifyListeners();
      });

      // Listen to progress
      _fotaService.progressStream.listen((progress) {
        _progress = progress;
        notifyListeners();
      });

      // Listen to logs
      _fotaService.logStream.listen((log) {
        _logs.add(log);
        if (_logs.length > 200) {
          _logs.removeAt(0);
        }
        notifyListeners();
      });

      _addLog('[FOTA] Khởi tạo thành công');
    } else {
      _error = 'Không thể khởi tạo FOTA service';
      _addLog('[ERROR] $_error');
    }

    notifyListeners();
    return success;
  }

  /// Đặt firmware APP_1
  void setApp1Firmware(Uint8List data, String fileName) {
    _app1Data = data;
    _app1FileName = fileName;
    _addLog('[FILE] APP_1: $fileName (${data.length} bytes)');
    notifyListeners();
  }

  /// Đặt firmware APP_2
  void setApp2Firmware(Uint8List data, String fileName) {
    _app2Data = data;
    _app2FileName = fileName;
    _addLog('[FILE] APP_2: $fileName (${data.length} bytes)');
    notifyListeners();
  }

  /// Bắt đầu update
  Future<bool> startUpdate() async {
    if (_app1Data == null || _app2Data == null) {
      _error = 'Chưa chọn đủ file firmware APP_1 và APP_2';
      _addLog('[ERROR] $_error');
      notifyListeners();
      return false;
    }

    _error = null;
    _addLog('[FOTA] Bắt đầu quá trình update...');
    
    final success = await _fotaService.startUpdate(
      app1Data: _app1Data!,
      app2Data: _app2Data!,
    );

    if (!success) {
      _error = 'Update thất bại';
    }

    notifyListeners();
    return success;
  }

  /// Gửi lệnh UPDATE
  Future<bool> sendUpdateCommand() async {
    _addLog('[FOTA] Gửi lệnh UPDATE để MCU cập nhật firmware...');
    final success = await _fotaService.sendUpdateCommand();
    notifyListeners();
    return success;
  }

  /// Reset state
  void reset() {
    _fotaService.reset();
    _state = FotaState.idle;
    _progress = 0;
    _error = null;
    _addLog('[FOTA] Reset state');
    notifyListeners();
  }

  /// Clear logs
  void clearLogs() {
    _logs.clear();
    notifyListeners();
  }

  /// Clear all (including files)
  void clearAll() {
    reset();
    _app1Data = null;
    _app2Data = null;
    _app1FileName = null;
    _app2FileName = null;
    _logs.clear();
    _isInitialized = false;
    notifyListeners();
  }

  void _addLog(String message) {
    final timestamp = DateTime.now().toString().substring(11, 19);
    _logs.add('[$timestamp] $message');
    if (_logs.length > 200) {
      _logs.removeAt(0);
    }
  }

  String get stateText {
    switch (_state) {
      case FotaState.idle:
        return 'Sẵn sàng';
      case FotaState.connecting:
        return 'Đang kết nối...';
      case FotaState.waitingAppSelection:
        return 'Đang chờ MCU chọn APP...';
      case FotaState.sendingInfo:
        return 'Đang gửi thông tin file...';
      case FotaState.sendingData:
        return 'Đang truyền firmware...';
      case FotaState.waitingEnd:
        return 'Chờ xác nhận hoàn tất...';
      case FotaState.sendingUpdate:
        return 'Đang gửi lệnh UPDATE...';
      case FotaState.completed:
        return 'Hoàn tất!';
      case FotaState.error:
        return 'Lỗi!';
    }
  }
}
