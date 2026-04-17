// @file       app_constants.dart
// @brief      Configuration for App Constants.

// Map Configuration
/* Public classes ----------------------------------------------------- */
class MapConfig {
  MapConfig._();

  // Default center position (HCM city)
  static const double defaultLatitude = 10.8231;
  static const double defaultLongitude = 106.6297;

  // Zoom levels
  static const double defaultZoom = 13.0;
  static const double minZoom = 3.0;
  static const double maxZoom = 19.0;
  static const double detailZoom = 16.0;

  // Tile URL (OpenStreetMap - FREE)
  static const String osmTileUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const String cartoDbTileUrl =
      'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png';

  // Subdomains
  static const List<String> subdomains = ['a', 'b', 'c'];

  // Attribution
  static const String attribution = '© OpenStreetMap contributors';
}

// Route Configuration
class RouteConfig {
  RouteConfig._();

  // Route line style
  static const double lineWidth = 4.0;
  static const double lineOpacity = 0.8;

  // Animation
  static const int animationDurationMs = 3000;
  static const int animationSteps = 100;
  static const int realtimeUpdateIntervalMs = 1000;
}

// Marker Configuration
class MarkerConfig {
  MarkerConfig._();

  // Marker sizes
  static const double normalSize = 16.0;
  static const double startEndSize = 20.0;
  static const double highlightSize = 30.0;

  // Border
  static const double borderWidth = 2.0;
}

// Bluetooth Configuration
class BluetoothConfig {
  BluetoothConfig._();

  // Scan settings
  static const int scanTimeoutSeconds = 10;
  static const int connectionTimeoutSeconds = 15;

  // BLE setting
  static const String serviceUuid = "0000ffe0-0000-1000-8000-00805f9b34fb";
  static const String characteristicUuid =
      "0000ffe1-0000-1000-8000-00805f9b34fb";

  // Buffer settings
  static const int maxBufferSize = 10000;

  // Data delimiters
  static const String lineDelimiter = '\n';
  static const String fieldDelimiter = ',';
}

// File Configuration
class FileConfig {
  FileConfig._();

  // Supported formats
  static const List<String> supportedExtensions = ['json', 'csv', 'txt'];

  // Default file path
  static const String defaultFilePath = 'assets/data/sample_route.json';

  // Max file size (bytes)
  static const int maxFileSizeBytes = 10 * 1024 * 1024; // 10 MB
}

// UI Configuration
class UIConfig {
  UIConfig._();

  // Sidebar
  static const double sidebarWidth = 350.0;
  static const double sidebarWidthMobile = 0.85; // 85% of screen

  // Padding & Margin
  static const double paddingSmall = 8.0;
  static const double paddingMedium = 16.0;
  static const double paddingLarge = 24.0;

  // Border radius
  static const double borderRadiusSmall = 4.0;
  static const double borderRadiusMedium = 8.0;
  static const double borderRadiusLarge = 12.0;

  // Animation duration
  static const int animationDurationMs = 300;

  // Points list
  static const int maxDisplayPoints = 100;

  // Notification duration
  static const int notificationDurationSeconds = 3;
}

// Earth radius for distance calculation (km)
class GeoConfig {
  GeoConfig._();

  static const double earthRadiusKm = 6371.0;
}

/* End of file -------------------------------------------------------- */
