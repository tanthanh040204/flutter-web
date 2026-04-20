// @file       feature_config.dart
// @brief      Configuration for Feature.

/* Public classes ----------------------------------------------------- */
class FeatureConfig {
  FeatureConfig._();

  // Mqtt
  static const String mqttHost = 'broker.emqx.io';
  // Mqtt port
  static const int mqttWsPort = 8083;
  // WSS for TLS, ws for non-TLS
  static const bool mqttUseSsl = false;
  // Username and password for MQTT authentication (if required by the broker)
  static const String mqttUsername = '';
  static const String mqttPassword = '';

  // Data topic: device -> web
  static const String topicDataSuffix = '/data';
  // Notification topic: device -> web
  static const String topicNotiSuffix = '/noti';
  // Command topic: web -> device
  static const String topicCmdSuffix = '/cmd';
  // Rental request topic: mobile app -> web
  static const String topicAppWebSuffix = '/app_web';
  // Rental response topic: web -> mobile app
  static const String topicWebAppSuffix = '/web_app';
  // Token request topic: external system -> web (credit tokens to a user)
  static const String tokenRequestTopic = 'Q7M4K2P/request';

  // Client ID prefix for MQTT connection
  static const String mqttClientIdPrefix = 'flutter-haq-';
  // Keepalive interval for MQTT connection (seconds)
  static const int mqttKeepalive = 60;
  // Default devices to subscribe to (can be overridden by user settings)
  static const List<String> defaultDevices = ['haq-trk-001'];

  // Color palette for devices (used for route lines and markers on the map)
  static const List<String> deviceColorPalette = [
    '#3498db',
    '#e74c3c',
    '#2ecc71',
    '#9b59b6',
    '#f39c12',
    '#1abc9c',
    '#e67e22',
    '#e91e63',
  ];

  // Features
  static const bool enableMqtt = true;
  static const bool enableFirebase = true;
  static const bool enableNotifications = true;
  // Auto register device when receiving data from an unknown device topic
  static const bool enableAutoRegisterDevice = true;
  static const bool enableOfflineDetection = true;
  static const bool enableFusionData = true;

  // Debug logs
  static const bool debugMqttLog = true;
  static const bool debugParserLog = true;

  // Timeout
  static const int offlineTimeoutMs = 30000;
  // Device keepalive timeout (ms)
  static const int keepaliveTimeoutMs = 60000;
  // Interval for checking offline devices (ms)
  static const int offlineCheckIntervalMs = 5000;

  // Renta;l service
  static const int rentalBlockDurationsMinutes = 30;
  static const int minTokenToRent = 10000; // 10,000 tokens = 30 minutes rental
  static const int outOfZonePenaltyTokens = 5000;
}

/* End of file -------------------------------------------------------- */
