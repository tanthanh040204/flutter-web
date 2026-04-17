// @file       bluetooth_device_info.dart
// @brief      Data model for Bluetooth Device Info.

/* Enums -------------------------------------------------------------- */
enum AppBluetoothConnectionState {
  disconnected,
  connecting,
  connected,
  disconnecting,
}

/* Public classes ----------------------------------------------------- */
class BluetoothDeviceInfo {
  final String id;
  final String name;
  final int? rssi;
  final AppBluetoothConnectionState connectionState;

  const BluetoothDeviceInfo({
    required this.id,
    required this.name,
    this.rssi,
    this.connectionState = AppBluetoothConnectionState.disconnected,
  });

  // Display name (name or ID if name is empty)
  String get displayName => name.isNotEmpty ? name : 'Unknown ($id)';

  // Signal strength description
  String get signalStrength {
    if (rssi == null) return 'N/A';
    if (rssi! >= -50) return 'Excellent';
    if (rssi! >= -60) return 'Good';
    if (rssi! >= -70) return 'Fair';
    return 'Weak';
  }

  // Is connected
  bool get isConnected =>
      connectionState == AppBluetoothConnectionState.connected;

  // Is connecting
  bool get isConnecting =>
      connectionState == AppBluetoothConnectionState.connecting;

  // Copy with new values
  BluetoothDeviceInfo copyWith({
    String? id,
    String? name,
    int? rssi,
    AppBluetoothConnectionState? connectionState,
  }) {
    return BluetoothDeviceInfo(
      id: id ?? this.id,
      name: name ?? this.name,
      rssi: rssi ?? this.rssi,
      connectionState: connectionState ?? this.connectionState,
    );
  }

  @override
  String toString() => 'BluetoothDeviceInfo($displayName, $connectionState)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BluetoothDeviceInfo && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/* End of file -------------------------------------------------------- */
