// @file       mqtt_service.dart
// @brief      Service for MQTT.

/* Imports ------------------------------------------------------------ */
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

/* Public classes ----------------------------------------------------- */
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

// Notification from topic <deviceId>/noti
class MqttNotiMessage {
  final String deviceId;
  final String message;

  const MqttNotiMessage({required this.deviceId, required this.message});
}

// Message from mobile app via topic <bikeId>/app_web
class MqttRentalRequestMessage {
  final String bikeId;
  final String raw;

  const MqttRentalRequestMessage({required this.bikeId, required this.raw});
}

// Message from topic Q7M4K2P/request — add tokens to a user account.
class MqttTokenRequestMessage {
  final String raw;
  const MqttTokenRequestMessage({required this.raw});
}

// Backward-compat: vehicle state from bridge server (vehicles/+/state)
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

// MQTT client for all MQTT interactions: connect, subscribe, publish, and message handling.
// Workflow:
//   Broker →(WS)→ MqttService._handleMessage()
//                → DataParser.parse(raw)
//                → dataMessages stream → DeviceProvider
//                → notifications stream → DeviceProvider
//
// Topics MCU and web:
//   <deviceId>/data  – subscription (subscribe)
//   <deviceId>/noti  – notification  (subscribe)
//   <deviceId>/cmd   – control command (publish)
class MqttService {
  MqttClient? _client;
  bool _isConnected = false;

  // Set of currently subscribed topics to avoid duplicate subscriptions, re-subscribe on reconnect.
  final Set<String> _subscribedTopics = {};

  // ---- Streams ----
  final _dataController = StreamController<MqttDataMessage>.broadcast();
  final _notiController = StreamController<MqttNotiMessage>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();
  final _rentalRequestController =
      StreamController<MqttRentalRequestMessage>.broadcast();
  final _tokenRequestController =
      StreamController<MqttTokenRequestMessage>.broadcast();

  // Backward-compat stream cho FleetProvider
  final _vehicleStateController =
      StreamController<MqttVehicleState>.broadcast();

  // Stream parsed data, notifications, and connection state to listeners (providers).
  Stream<MqttDataMessage> get dataMessages => _dataController.stream;
  Stream<MqttNotiMessage> get notifications => _notiController.stream;
  Stream<bool> get connectionState => _connectionController.stream;

  // Messages from mobile app via topic <bikeId>/app_web
  Stream<MqttRentalRequestMessage> get rentalRequests =>
      _rentalRequestController.stream;

  // Messages from topic Q7M4K2P/request — add tokens to user accounts
  Stream<MqttTokenRequestMessage> get tokenRequests =>
      _tokenRequestController.stream;

  // Backward-compat: stream vehicle state (use by FleetProvider)
  Stream<MqttVehicleState> get vehicleStates => _vehicleStateController.stream;

  bool get isConnected => _isConnected;

  /* Public functions --------------------------------------------------- */
  // Connect to MQTT broker with configured settings.
  Future<void> connect() async {
    if (_isConnected && _client != null) return;

    final rand = math.Random();
    final clientId =
        FeatureConfig.mqttClientIdPrefix +
        rand.nextInt(0xFFFFFF).toRadixString(16).padLeft(6, '0');

    if (kIsWeb) {
      final proto = FeatureConfig.mqttUseSsl ? 'wss' : 'ws';
      final serverBase = '$proto://${FeatureConfig.mqttHost}/mqtt';
      final wsUrl =
          '$proto://${FeatureConfig.mqttHost}:${FeatureConfig.mqttWsPort}/mqtt';

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

      final client = MqttServerClient(FeatureConfig.mqttHost, clientId);
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

    // Subscribe to the token request topic
    _subscribeRaw(FeatureConfig.tokenRequestTopic);
  }

  void _subscribeRaw(String topic) {
    final isNew = _subscribedTopics.add(topic);
    if (isNew && _isConnected && _client != null) {
      _client!.subscribe(topic, MqttQos.atMostOnce);
      if (FeatureConfig.debugMqttLog) {
        debugPrint('[MQTT] Subscribed: $topic');
      }
    }
  }

  void disconnect() {
    _client?.disconnect();
    _isConnected = false;
  }

  // Subscribe device topics for data and notifications.
  // No-op for topics already subscribed — safe to call repeatedly.
  void subscribeDevice(String deviceId) {
    final topics = [
      '$deviceId${FeatureConfig.topicDataSuffix}',
      '$deviceId${FeatureConfig.topicNotiSuffix}',
      '$deviceId${FeatureConfig.topicAppWebSuffix}',
    ];
    for (final topic in topics) {
      final isNew = _subscribedTopics.add(topic);
      if (isNew && _isConnected && _client != null) {
        _client!.subscribe(topic, MqttQos.atMostOnce);
        if (FeatureConfig.debugMqttLog) {
          debugPrint('[MQTT] Subscribed: $topic');
        }
      }
    }
  }

  // Unsubscribe device topics for data and notifications
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

  // Backward-compat: subscribe all devices from FeatureConfig.
  Future<void> subscribeFleetState() async {
    for (final id in FeatureConfig.defaultDevices) {
      subscribeDevice(id);
    }
  }

  // Publish command (string)
  bool publish(String deviceId, String command) {
    if (!_isConnected || _client == null) {
      debugPrint('[MQTT] Cannot publish: not connected');
      return false;
    }
    final topic = '$deviceId${FeatureConfig.topicCmdSuffix}';
    final builder = MqttClientPayloadBuilder()..addString(command);
    _client!.publishMessage(topic, MqttQos.atMostOnce, builder.payload!);
    if (FeatureConfig.debugMqttLog) {
      final preview = command.length > 80 ? command.substring(0, 80) : command;
      debugPrint('[MQTT] Published → $topic | $preview');
    }
    return true;
  }

  // Publish JSON command
  bool publishCommand(String vehicleId, Map<String, dynamic> payload) {
    return publish(vehicleId, jsonEncode(payload));
  }

  // Publish response to mobile app via topic <bikeId>/app_web
  bool publishToApp(String bikeId, String message) {
    final topic = '$bikeId${FeatureConfig.topicWebAppSuffix}';
    return publishRaw(topic, message);
  }

  // Publish to topic
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

  void dispose() {
    disconnect();
    _dataController.close();
    _notiController.close();
    _connectionController.close();
    _rentalRequestController.close();
    _tokenRequestController.close();
    _vehicleStateController.close();
  }

  // ---- Private methods ----
  void _onConnected() {
    _isConnected = true;
    if (FeatureConfig.debugMqttLog) debugPrint('[MQTT] Connected');

    // Re-subscribe all topics after reconnect
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

      final raw = MqttPublishPayload.bytesToStringAsString(msg.payload.message);
      if (FeatureConfig.debugMqttLog) {
        final preview = raw.length > 100 ? raw.substring(0, 100) : raw;
        debugPrint('[MQTT] RX  topic=${event.topic}  payload=$preview');
      }

      _handleMessage(event.topic, raw);
    }
  }

  // Handle incoming MQTT message: parse and add to streams.
  void _handleMessage(String topic, String raw) {
    final dataSuffix = FeatureConfig.topicDataSuffix;
    final notiSuffix = FeatureConfig.topicNotiSuffix;
    final appWebSuffix = FeatureConfig.topicAppWebSuffix;

    if (topic == FeatureConfig.tokenRequestTopic) {
      // ---- TOKEN REQUEST ----
      _tokenRequestController.add(MqttTokenRequestMessage(raw: raw.trim()));
      return;
    }

    if (topic.endsWith(appWebSuffix)) {
      // ---- RENTAL REQUEST from mobile app ----
      final bikeId = topic.substring(0, topic.length - appWebSuffix.length);
      _rentalRequestController.add(
        MqttRentalRequestMessage(bikeId: bikeId, raw: raw.trim()),
      );
      return;
    }

    if (topic.endsWith(dataSuffix)) {
      // ---- DATA message ----
      final deviceId = topic.substring(0, topic.length - dataSuffix.length);
      final parsed = DataParser.parse(raw);
      if (parsed == null) return;

      _dataController.add(
        MqttDataMessage(deviceId: deviceId, data: parsed, raw: raw),
      );

      // Backward-compat: map MCU data → MqttVehicleState cho FleetProvider
      final vKmh =
          parsed.velocityKmh ??
          (parsed.velocityMs != null ? parsed.velocityMs! * 3.6 : null);
      final payload = <String, dynamic>{
        'id': deviceId,
        'batteryPercent': (parsed.battery ?? 0).toInt(),
        'lat': parsed.lat ?? 0.0,
        'lon': parsed.lng ?? 0.0,
        'isLocked': false,
        'isRunning': (vKmh ?? 0) > 0,
      };
      if (parsed.totalKm != null) {
        payload['totalKm'] = parsed.totalKm;
      }
      if (parsed.temp != null) payload['temp'] = parsed.temp;
      if (parsed.hum != null) payload['hum'] = parsed.hum;
      if (parsed.dust != null) payload['dust'] = parsed.dust;
      if (vKmh != null) payload['velocityKmh'] = vKmh;

      _vehicleStateController.add(
        MqttVehicleState(topic: topic, payload: payload),
      );
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

/* End of file -------------------------------------------------------- */
