import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_browser_client.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

import '../config/feature_config.dart';
import '../models/device_data.dart';
import 'data_parser.dart';

// ================================================================
//  Message types
// ================================================================

/// Dữ liệu telemetry đã parse từ topic  <deviceId>/data
class MqttDataMessage {
  final String deviceId;
  final DeviceData data;
  final String raw;

  const MqttDataMessage({
    required this.deviceId,
    required this.data,
    required this.raw,
  });
}

/// Notification từ topic  <deviceId>/noti
class MqttNotiMessage {
  final String deviceId;
  final String message;

  const MqttNotiMessage({required this.deviceId, required this.message});
}

/// Backward-compat: vehicle state từ bridge server (vehicles/+/state)
class MqttVehicleState {
  final String topic;
  final Map<String, dynamic> payload;

  const MqttVehicleState({required this.topic, required this.payload});

  String get vehicleId {
    final parts = topic.split('/');
    if (parts.length >= 2) return parts[1];
    return (payload['id'] ?? '').toString();
  }
}

// ================================================================
//  MqttService
// ================================================================

/// MQTT client cho toàn bộ app.
///
/// Luồng dữ liệu:
///   Broker →(WS)→ MqttService._handleMessage()
///                → DataParser.parse(raw)
///                → dataMessages stream → DeviceProvider
///                → notifications stream → DeviceProvider
///
/// Topics MCU (khớp với web):
///   <deviceId>/data  – telemetry (subscribe)
///   <deviceId>/noti  – notification  (subscribe)
///   <deviceId>/cmd   – lệnh điều khiển (publish)
class MqttService {
  MqttClient? _client;
  bool _isConnected = false;

  /// Tập topics đã subscribe (để re-sub sau reconnect)
  final Set<String> _subscribedTopics = {};

  // ---- Streams ----
  final _dataController =
      StreamController<MqttDataMessage>.broadcast();
  final _notiController =
      StreamController<MqttNotiMessage>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();

  // Backward-compat stream cho FleetProvider
  final _vehicleStateController =
      StreamController<MqttVehicleState>.broadcast();

  /// Stream dữ liệu telemetry từ <deviceId>/data (đã parse)
  Stream<MqttDataMessage> get dataMessages => _dataController.stream;

  /// Stream notification từ <deviceId>/noti
  Stream<MqttNotiMessage> get notifications => _notiController.stream;

  /// Stream trạng thái kết nối: true = connected, false = disconnected
  Stream<bool> get connectionState => _connectionController.stream;

  /// Backward-compat: stream vehicle state (dùng bởi FleetProvider)
  Stream<MqttVehicleState> get vehicleStates =>
      _vehicleStateController.stream;

  bool get isConnected => _isConnected;

  // ================================================================
  //  Connection
  // ================================================================

  /// Kết nối đến broker qua WebSocket (web) hoặc TCP (native).
  /// Sử dụng host/port từ [FeatureConfig].
  Future<void> connect() async {
    if (_isConnected && _client != null) return;

    final rand = math.Random();
    final clientId = FeatureConfig.mqttClientIdPrefix +
        rand.nextInt(0xFFFFFF).toRadixString(16).padLeft(6, '0');

    if (kIsWeb) {
      // mqtt_client (web) sẽ giữ nguyên path trong `server` rồi replace(port).
      // Vì broker EMQX public dùng path `/mqtt`, ta truyền path ngay từ đây.
      final proto = FeatureConfig.mqttUseSsl ? 'wss' : 'ws';
      final serverBase = '$proto://${FeatureConfig.mqttHost}/mqtt';
      final wsUrl = '$proto://${FeatureConfig.mqttHost}:${FeatureConfig.mqttWsPort}/mqtt';

      if (FeatureConfig.debugMqttLog) {
        debugPrint('[MQTT] Connecting → $wsUrl | clientId: $clientId');
      }

      final client = MqttBrowserClient(serverBase, clientId);
      client.port = FeatureConfig.mqttWsPort;
      client.setProtocolV311();
      client.logging(on: FeatureConfig.debugMqttLog);
      client.keepAlivePeriod = FeatureConfig.mqttKeepalive;
      client.autoReconnect = true;
      client.resubscribeOnAutoReconnect = true;
      client.onConnected = _onConnected;
      client.onDisconnected = _onDisconnected;
      client.connectionMessage = MqttConnectMessage()
          .withClientIdentifier(clientId)
          .startClean();

      _client = client;
      try {
        final u = FeatureConfig.mqttUsername;
        final p = FeatureConfig.mqttPassword;
        await client.connect(u.isEmpty ? null : u, p.isEmpty ? null : p);
      } catch (e) {
        debugPrint('[MQTT] Connect error (web): $e');
        rethrow;
      }
    } else {
      if (FeatureConfig.debugMqttLog) {
        debugPrint(
          '[MQTT] Connecting → ${FeatureConfig.mqttHost}:${FeatureConfig.mqttWsPort} | clientId: $clientId',
        );
      }

      final client =
          MqttServerClient(FeatureConfig.mqttHost, clientId);
      client.port = FeatureConfig.mqttWsPort;
      client.setProtocolV311();
      client.secure = FeatureConfig.mqttUseSsl;
      client.logging(on: FeatureConfig.debugMqttLog);
      client.keepAlivePeriod = FeatureConfig.mqttKeepalive;
      client.autoReconnect = true;
      client.resubscribeOnAutoReconnect = true;
      client.onConnected = _onConnected;
      client.onDisconnected = _onDisconnected;
      client.connectionMessage = MqttConnectMessage()
          .withClientIdentifier(clientId)
          .startClean();

      _client = client;
      try {
        final u = FeatureConfig.mqttUsername;
        final p = FeatureConfig.mqttPassword;
        await client.connect(u.isEmpty ? null : u, p.isEmpty ? null : p);
      } catch (e) {
        debugPrint('[MQTT] Connect error (native): $e');
        rethrow;
      }
    }

    final status = _client?.connectionStatus?.state;
    if (FeatureConfig.debugMqttLog) {
      debugPrint('[MQTT] Connection status: $status');
    }
    if (status != MqttConnectionState.connected) {
      throw Exception('MQTT connection failed. Status: $status');
    }

    _client!.updates!.listen(_onMessage);
  }

  void disconnect() {
    _client?.disconnect();
    _isConnected = false;
  }

  // ================================================================
  //  Subscribe / Unsubscribe
  // ================================================================

  /// Subscribe topic data và noti của thiết bị.
  /// Nếu chưa connect → sẽ được re-sub trong _onConnected().
  void subscribeDevice(String deviceId) {
    final topics = [
      '$deviceId${FeatureConfig.topicDataSuffix}',
      '$deviceId${FeatureConfig.topicNotiSuffix}',
    ];
    for (final topic in topics) {
      _subscribedTopics.add(topic);
      if (_isConnected && _client != null) {
        _client!.subscribe(topic, MqttQos.atMostOnce);
        if (FeatureConfig.debugMqttLog) {
          debugPrint('[MQTT] Subscribed: $topic');
        }
      }
    }
  }

  /// Hủy subscribe topics của thiết bị.
  void unsubscribeDevice(String deviceId) {
    final topics = [
      '$deviceId${FeatureConfig.topicDataSuffix}',
      '$deviceId${FeatureConfig.topicNotiSuffix}',
    ];
    for (final topic in topics) {
      _subscribedTopics.remove(topic);
      if (_isConnected && _client != null) {
        _client!.unsubscribe(topic);
      }
    }
  }

  /// Backward-compat: subscribe tất cả device mặc định từ FeatureConfig.
  Future<void> subscribeFleetState() async {
    for (final id in FeatureConfig.defaultDevices) {
      subscribeDevice(id);
    }
  }

  // ================================================================
  //  Publish
  // ================================================================

  /// Publish chuỗi lệnh đến  <deviceId>/cmd.
  /// Ví dụ: publish('haq-trk-001', 'LOCK')
  /// Trả về true nếu gửi thành công.
  bool publish(String deviceId, String command) {
    if (!_isConnected || _client == null) {
      debugPrint('[MQTT] Cannot publish: not connected');
      return false;
    }
    final topic = '$deviceId${FeatureConfig.topicCmdSuffix}';
    final builder = MqttClientPayloadBuilder()..addString(command);
    _client!.publishMessage(topic, MqttQos.atMostOnce, builder.payload!);
    if (FeatureConfig.debugMqttLog) {
      final preview =
          command.length > 80 ? command.substring(0, 80) : command;
      debugPrint('[MQTT] Published → $topic | $preview');
    }
    return true;
  }

  /// Publish JSON command đến <deviceId>/cmd.
  /// Backward-compat với FleetProvider.sendSetLock() v.v.
  bool publishCommand(String vehicleId, Map<String, dynamic> payload) {
    return publish(vehicleId, jsonEncode(payload));
  }

  /// Publish tới bất kỳ topic nào (dùng cho MQTT console/debug).
  bool publishRaw(String topic, String message) {
    if (!_isConnected || _client == null) {
      debugPrint('[MQTT] Cannot publish: not connected');
      return false;
    }
    final builder = MqttClientPayloadBuilder()..addString(message);
    _client!.publishMessage(topic, MqttQos.atMostOnce, builder.payload!);
    if (FeatureConfig.debugMqttLog) {
      debugPrint('[MQTT] Published (raw) → $topic | $message');
    }
    return true;
  }

  // ================================================================
  //  Cleanup
  // ================================================================

  void dispose() {
    disconnect();
    _dataController.close();
    _notiController.close();
    _connectionController.close();
    _vehicleStateController.close();
  }

  // ================================================================
  //  Private
  // ================================================================

  void _onConnected() {
    _isConnected = true;
    if (FeatureConfig.debugMqttLog) debugPrint('[MQTT] Connected');

    // Re-subscribe tất cả topics đã đăng ký
    for (final topic in _subscribedTopics) {
      _client!.subscribe(topic, MqttQos.atMostOnce);
      if (FeatureConfig.debugMqttLog) {
        debugPrint('[MQTT] Re-subscribed: $topic');
      }
    }

    _connectionController.add(true);
  }

  void _onDisconnected() {
    _isConnected = false;
    if (FeatureConfig.debugMqttLog) debugPrint('[MQTT] Disconnected');
    _connectionController.add(false);
  }

  void _onMessage(List<MqttReceivedMessage<MqttMessage?>>? events) {
    if (events == null) return;
    for (final event in events) {
      final msg = event.payload;
      if (msg is! MqttPublishMessage) continue;

      final raw = MqttPublishPayload.bytesToStringAsString(
        msg.payload.message,
      );
      if (FeatureConfig.debugMqttLog) {
        final preview = raw.length > 100 ? raw.substring(0, 100) : raw;
        debugPrint('[MQTT] RX  topic=${event.topic}  payload=$preview');
      }

      _handleMessage(event.topic, raw);
    }
  }

  /// Phân loại message theo topic suffix và dispatch vào đúng stream.
  void _handleMessage(String topic, String raw) {
    final dataSuffix = FeatureConfig.topicDataSuffix;
    final notiSuffix = FeatureConfig.topicNotiSuffix;

    if (topic.endsWith(dataSuffix)) {
      // ---- DATA message ----
      final deviceId = topic.substring(0, topic.length - dataSuffix.length);
      final parsed = DataParser.parse(raw);
      if (parsed == null) return;

      _dataController.add(
        MqttDataMessage(deviceId: deviceId, data: parsed, raw: raw),
      );

      // Backward-compat: map MCU data → MqttVehicleState cho FleetProvider
      _vehicleStateController.add(MqttVehicleState(
        topic: topic,
        payload: {
          'id': deviceId,
          'batteryPercent': (parsed.battery ?? 0).toInt(),
          'lat': parsed.lat ?? 0.0,
          'lon': parsed.lng ?? 0.0,
          'totalKm': (parsed.distanceM ?? 0) / 1000.0,
          'isLocked': false,
          'isRunning': (parsed.velocityKmh ?? 0) > 0,
          'temp': parsed.temp ?? 0.0,
          'hum': parsed.hum ?? 0.0,
          'dust': parsed.dust ?? 0.0,
        },
      ));
    } else if (topic.endsWith(notiSuffix)) {
      // ---- NOTI message ----
      if (!FeatureConfig.enableNotifications) return;
      final deviceId = topic.substring(0, topic.length - notiSuffix.length);
      final message = raw.trim();
      if (FeatureConfig.debugMqttLog) {
        debugPrint('[MQTT] Noti ← $deviceId: $message');
      }
      _notiController.add(
        MqttNotiMessage(deviceId: deviceId, message: message),
      );
    }
  }
}
