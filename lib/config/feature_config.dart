/// ================================================================
/// FEATURE CONFIG
/// ================================================================
/// Cấu hình trung tâm cho toàn bộ app:
///   - MQTT broker endpoint (host/port)
///   - Feature flags (bật/tắt từng tính năng)
///   - Debug flags (in log chi tiết)
///
/// ĐỂ CHỈNH SỬA:
///   1. Thay mqttHost / mqttWsPort theo broker của bạn.
///   2. Bật/tắt tính năng qua các flag enableXxx.
///   3. Tắt debug khi release: debugMqttLog = false, debugParserLog = false.
/// ================================================================

class FeatureConfig {
  FeatureConfig._();

  // ----------------------------------------------------------------
  //  MQTT BROKER  ← CHỈNH SỬA TẠI ĐÂY
  // ----------------------------------------------------------------

  /// Hostname hoặc IP của MQTT broker
  static const String mqttHost = 'broker.emqx.io';

  /// WebSocket port của broker
  /// Mosquitto mặc định: 9001  |  EMQX: 8083 (ws), 8084 (wss)
  static const int mqttWsPort = 8083;

  /// true = dùng WSS (TLS),  false = WS thường
  static const bool mqttUseSsl = false;

  /// Xác thực broker — để rỗng nếu không cần
  static const String mqttUsername = '';
  static const String mqttPassword = '';

  // ----------------------------------------------------------------
  //  DEVICE TOPICS  (khớp với web/js/config.js)
  // ----------------------------------------------------------------

  /// Topic nhận dữ liệu telemetry từ MCU:  <deviceId>/data
  static const String topicDataSuffix = '/data';

  /// Topic nhận notification từ MCU:  <deviceId>/noti
  static const String topicNotiSuffix = '/noti';

  /// Topic gửi lệnh đến MCU:  <deviceId>/cmd
  static const String topicCmdSuffix = '/cmd';

  // ----------------------------------------------------------------
  //  MQTT CLIENT
  // ----------------------------------------------------------------

  /// Prefix của clientId  (suffix = 6 ký tự hex ngẫu nhiên)
  static const String mqttClientIdPrefix = 'flutter-haq-';

  /// Keepalive (giây)
  static const int mqttKeepalive = 60;

  // ----------------------------------------------------------------
  //  DEVICES
  // ----------------------------------------------------------------

  /// Danh sách thiết bị mặc định khi chưa có cấu hình nào
  static const List<String> defaultDevices = ['haq-trk-001'];

  /// Bảng màu xoay vòng cho mỗi thiết bị mới
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

  // ----------------------------------------------------------------
  //  FEATURE FLAGS
  // ----------------------------------------------------------------

  /// Kết nối MQTT khi khởi động app
  static const bool enableMqtt = true;

  /// Sử dụng Firebase / Firestore
  static const bool enableFirebase = true;

  /// Xử lý topic /noti  (KEEPALIVE, USER LOCK, …)
  static const bool enableNotifications = true;

  /// Tự động đăng ký thiết bị lạ nhận được từ MQTT
  static const bool enableAutoRegisterDevice = true;

  /// Bật kiểm tra thiết bị offline theo timer
  static const bool enableOfflineDetection = true;

  /// Xử lý các field Fusion  (acc, gyr, cmp, ins/gps)
  static const bool enableFusionData = true;

  // ----------------------------------------------------------------
  //  DEBUG
  // ----------------------------------------------------------------

  /// In log MQTT chi tiết ra console  (connect, subscribe, publish, receive)
  static const bool debugMqttLog = true;

  /// In log DataParser khi parse thất bại
  static const bool debugParserLog = true;

  // ----------------------------------------------------------------
  //  TIMEOUTS
  // ----------------------------------------------------------------

  /// Thiết bị bị đánh dấu offline sau bao lâu không nhận data  (ms)
  static const int offlineTimeoutMs = 30000;

  /// Thiết bị bị đánh dấu offline sau bao lâu không nhận KEEPALIVE  (ms)
  static const int keepaliveTimeoutMs = 45000;

  /// Chu kỳ timer kiểm tra offline  (ms)
  static const int offlineCheckIntervalMs = 5000;
}
