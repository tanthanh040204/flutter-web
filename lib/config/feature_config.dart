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
  static const bool parkingZonesLocal = true;
  static const bool enableNotifications = true;
  // Auto register device when receiving data from an unknown device topic
  static const bool enableAutoRegisterDevice = true;
  static const bool enableOfflineDetection = true;
  static const bool enableFusionData = true;

  // Trip route history (web-built per-rental routes) — save + display toggles.
  // Saving: write each finished rental route to the target.
  static const bool saveTripLocal = true; // local storage (survives reload)
  static const bool saveTripFirestore = true; // Firestore history_routes/rental_<id>
  // Display: include this source in the History tab.
  static const bool showTripLocal = true; // local/session routes
  static const bool showTripFirestore = true; // Firestore stream routes

  // Debug logs
  static const bool debugMqttLog = true;
  static const bool debugParserLog = true;

  // Timeout
  static const int offlineTimeoutMs = 30000;
  // Device keepalive timeout (ms)
  static const int keepaliveTimeoutMs = 60000;
  // Interval for checking offline devices (ms)
  static const int offlineCheckIntervalMs = 5000;
  // Start rental interval (ms)
  static const int rentalStartIntervalMs = 15 * 1000; // 15 seconds

  // Rental service
  static const int rentalBlockDurationsSeconds =
      3600; // 1 hour block for rentals
  static const int minTokenToRent = 10000; // 10k VND
  static const int outOfZonePenaltyTokens = 5000;
  static const int rentalDebtMaxTokens = 50000; // 50k VND
  static const int rentalDebtMaxDays = 7;
  // Time the user has after running out of balance to return the bike to a
  // valid parking zone. Past this, the rental ends with a penalty.
  static const int outOfBalanceGraceMinutes = 15;
  // Polling cadence for GPS while the user is in the out-of-balance grace
  // window — drives how quickly we detect a successful return-to-zone.
  static const int outOfBalanceGracePollSeconds = 30;
  // Enable the pause time limit. When false, a paused rental is never
  // force-ended by the pause timeout (pauseTimeoutHours is ignored).
  static const bool enablePauseTimeLimit = true;
  // Maximum time a rental may stay paused before being force-ended.
  static const int pauseTimeoutHours = 1;

  // Device command service
  // Timeout for commands like UNLOCK / LOCK before considering it failed.
  static const int unlockCommandTimeoutSeconds = 30;

  // History retention
  // History routes and daily-usage docs older than this are filtered out
  // (and pruned from Firestore for daily_usage).
  static const int historyKeepDays = 30;
}

/* End of file -------------------------------------------------------- */
