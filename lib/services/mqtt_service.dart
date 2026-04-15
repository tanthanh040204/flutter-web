import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_browser_client.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

import '../config/mqtt_config.dart';

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

class MqttService {
  MqttClient? _client;
  bool _isConnected = false;

  final StreamController<MqttVehicleState> _vehicleStateController =
      StreamController<MqttVehicleState>.broadcast();

  Stream<MqttVehicleState> get vehicleStates => _vehicleStateController.stream;
  bool get isConnected => _isConnected;

  Future<void> connect() async {
    if (_isConnected && _client != null) return;

    final clientId = 'flutter_${DateTime.now().millisecondsSinceEpoch}';

    if (kIsWeb) {
      final client = MqttBrowserClient(MqttConfig.wsUrl, clientId);

      client.logging(on: false);
      client.keepAlivePeriod = 20;
      client.autoReconnect = true;
      client.resubscribeOnAutoReconnect = true;
      client.onConnected = _onConnected;
      client.onDisconnected = _onDisconnected;

      client.connectionMessage = MqttConnectMessage()
          .withClientIdentifier(clientId)
          .startClean()
          .keepAliveFor(20);

      _client = client;

      await client.connect(MqttConfig.username, MqttConfig.password);
    } else {
      final client = MqttServerClient(MqttConfig.host, clientId);

      client.port = MqttConfig.tlsPort;
      client.secure = true;
      client.logging(on: false);
      client.keepAlivePeriod = 20;
      client.autoReconnect = true;
      client.resubscribeOnAutoReconnect = true;
      client.onConnected = _onConnected;
      client.onDisconnected = _onDisconnected;

      client.connectionMessage = MqttConnectMessage()
          .withClientIdentifier(clientId)
          .startClean()
          .keepAliveFor(20);

      _client = client;

      await client.connect(MqttConfig.username, MqttConfig.password);
    }

    final status = _client?.connectionStatus?.state;
    if (status != MqttConnectionState.connected) {
      throw Exception('MQTT chưa kết nối được. Status: $status');
    }

    _client?.updates?.listen((List<MqttReceivedMessage<MqttMessage?>>? events) {
      if (events == null) return;

      for (final event in events) {
        final message = event.payload;
        if (message is! MqttPublishMessage) continue;

        final payloadString = MqttPublishPayload.bytesToStringAsString(
          message.payload.message,
        );

        try {
          final decoded = jsonDecode(payloadString);
          if (decoded is Map<String, dynamic>) {
            _vehicleStateController.add(
              MqttVehicleState(topic: event.topic, payload: decoded),
            );
          }
        } catch (e) {
          debugPrint('MQTT parse error: $e');
        }
      }
    });
  }

  Future<void> subscribeFleetState() async {
    final client = _client;
    if (client == null || !_isConnected) {
      throw Exception('MQTT chưa connect');
    }

    client.subscribe(MqttConfig.fleetStateTopic, MqttQos.atLeastOnce);
  }

  Future<void> publishCommand(
    String vehicleId,
    Map<String, dynamic> payload,
  ) async {
    final client = _client;
    if (client == null || !_isConnected) {
      throw Exception('MQTT chưa connect');
    }

    final builder = MqttClientPayloadBuilder();
    builder.addString(jsonEncode(payload));

    client.publishMessage(
      MqttConfig.commandTopic(vehicleId),
      MqttQos.atLeastOnce,
      builder.payload!,
      retain: false,
    );
  }

  void _onConnected() {
    _isConnected = true;
    debugPrint('MQTT connected');
  }

  void _onDisconnected() {
    _isConnected = false;
    debugPrint('MQTT disconnected');
  }

  Future<void> disconnect() async {
    _client?.disconnect();
    _isConnected = false;
  }

  void dispose() {
    _client?.disconnect();
    _vehicleStateController.close();
  }
}
