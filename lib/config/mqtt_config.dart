import 'feature_config.dart';

/// MqttConfig – re-export từ FeatureConfig để backward-compat.
///
/// Sửa MQTT endpoint tại [FeatureConfig]:
///   static const String mqttHost  = '...';
///   static const int    mqttWsPort = ...;
class MqttConfig {
  MqttConfig._();

  static String get host => FeatureConfig.mqttHost;
  static int get tlsPort => FeatureConfig.mqttWsPort;

  static String get wsUrl {
    final proto = FeatureConfig.mqttUseSsl ? 'wss' : 'ws';
    return '$proto://${FeatureConfig.mqttHost}:${FeatureConfig.mqttWsPort}/mqtt';
  }

  static String get username => FeatureConfig.mqttUsername;
  static String get password => FeatureConfig.mqttPassword;

  // Topic helpers (backward-compat)
  static String commandTopic(String vehicleId) =>
      '$vehicleId${FeatureConfig.topicCmdSuffix}';
  static String dataTopic(String vehicleId) =>
      '$vehicleId${FeatureConfig.topicDataSuffix}';
  static String notiTopic(String vehicleId) =>
      '$vehicleId${FeatureConfig.topicNotiSuffix}';
}
