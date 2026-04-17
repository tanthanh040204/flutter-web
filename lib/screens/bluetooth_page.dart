// @file       bluetooth_page.dart
// @brief      Screen UI for Bluetooth.

/* Imports ------------------------------------------------------------ */
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../config/app_theme.dart';
import '../models/bluetooth_device_info.dart';
import '../providers/bluetooth_provider.dart';
import '../providers/route_provider.dart';
import '../providers/streaming_provider.dart';
import '../services/bluetooth_service.dart';

/* Typedef / Function types ------------------------------------------ */
typedef UploadCallback = void Function();

/* Public classes ----------------------------------------------------- */
class BluetoothPage extends StatefulWidget {
  final UploadCallback? onUploadToMap;
  const BluetoothPage({super.key, this.onUploadToMap});

  @override
  State<BluetoothPage> createState() => _BluetoothPageState();
}

/* Private classes ---------------------------------------------------- */
class _BluetoothPageState extends State<BluetoothPage> {
  final List<String> _rawDataLog = [];
  final List<String> _debugLog = [];
  StreamSubscription<String>? _rawDataSubscription;
  StreamSubscription<String>? _debugLogSubscription;
  final ScrollController _scrollController = ScrollController();
  final ScrollController _debugScrollController = ScrollController();
  bool _showDebugPanel = true;

  @override
  void initState() {
    super.initState();
    final bluetoothService = BluetoothService();

    // Subscribe to raw data stream for debugging
    _rawDataSubscription = bluetoothService.rawDataStream.listen((data) {
      setState(() {
        final timestamp = DateTime.now().toString().substring(11, 19);
        _rawDataLog.add('[$timestamp] RAW: $data');
        if (_rawDataLog.length > 50) {
          _rawDataLog.removeAt(0);
        }
      });
      _autoScrollRaw();
    });

    // Subscribe to debug log stream
    _debugLogSubscription = bluetoothService.debugLogStream.listen((log) {
      setState(() {
        final timestamp = DateTime.now().toString().substring(11, 19);
        _debugLog.add('[$timestamp] $log');
        if (_debugLog.length > 100) {
          _debugLog.removeAt(0);
        }
      });
      _autoScrollDebug();
    });
  }

  void _autoScrollRaw() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _autoScrollDebug() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_debugScrollController.hasClients) {
        _debugScrollController.animateTo(
          _debugScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _rawDataSubscription?.cancel();
    _debugLogSubscription?.cancel();
    _scrollController.dispose();
    _debugScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bluetooth (MCU)'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _showDebugPanel ? Icons.bug_report : Icons.bug_report_outlined,
            ),
            onPressed: () => setState(() => _showDebugPanel = !_showDebugPanel),
            tooltip: 'Toggle Debug Panel',
          ),
        ],
      ),
      body: Consumer<BluetoothProvider>(
        builder: (context, provider, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Connection status card
                _buildConnectionStatus(provider),
                const SizedBox(height: 24),

                // Action buttons
                _buildActionButtons(context, provider),
                const SizedBox(height: 24),

                // DEBUG PANEL - Raw data log
                if (_showDebugPanel) ...[
                  _buildDebugPanel(),
                  const SizedBox(height: 24),
                ],

                // Device list - always show
                Text(
                  'Thiết bị tìm thấy (${provider.devices.length})',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                _buildDeviceList(context, provider),

                // Received data info
                if (provider.isConnected) ...[
                  const SizedBox(height: 24),
                  _buildReceivedDataCard(context, provider),
                ],

                // Error message
                if (provider.error != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: AppColors.danger,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            provider.error!,
                            style: const TextStyle(color: AppColors.danger),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDebugPanel() {
    return Card(
      color: Colors.black87,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Debug Log Section (Connection info)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.cyan, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Connection Log',
                      style: TextStyle(
                        color: Colors.cyan,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () => setState(() => _debugLog.clear()),
                  child: const Text(
                    'Clear',
                    style: TextStyle(color: Colors.orange),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Container(
              height: 120,
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(4),
              ),
              child: _debugLog.isEmpty
                  ? const Center(
                      child: Text(
                        'Chưa có log...\n(Kết nối BLE để xem services/characteristics)',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.builder(
                      controller: _debugScrollController,
                      itemCount: _debugLog.length,
                      itemBuilder: (context, index) {
                        final log = _debugLog[index];
                        Color color = Colors.cyan;
                        if (log.contains('[ERROR]')) color = Colors.red;
                        if (log.contains('[MATCH]')) color = Colors.yellow;
                        if (log.contains('[SERVICE]')) color = Colors.blue;
                        if (log.contains('[CHAR]')) color = Colors.blueGrey;
                        if (log.contains('[NOTIFY]')) color = Colors.green;
                        return Text(
                          log,
                          style: TextStyle(
                            color: color,
                            fontFamily: 'monospace',
                            fontSize: 10,
                          ),
                        );
                      },
                    ),
            ),

            const Divider(color: Colors.grey, height: 24),

            // Raw Data Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.data_array, color: Colors.green, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Raw Data Received',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () => setState(() => _rawDataLog.clear()),
                  child: const Text(
                    'Clear',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Container(
              height: 100,
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(4),
              ),
              child: _rawDataLog.isEmpty
                  ? const Center(
                      child: Text(
                        'Chờ dữ liệu từ BLE...\n(Sau khi kết nối, gửi data từ MCU)',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      itemCount: _rawDataLog.length,
                      itemBuilder: (context, index) {
                        return Text(
                          _rawDataLog[index],
                          style: const TextStyle(
                            color: Colors.lightGreenAccent,
                            fontFamily: 'monospace',
                            fontSize: 11,
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 8),
            Text(
              'Debug: ${_debugLog.length} | Raw: ${_rawDataLog.length}',
              style: const TextStyle(color: Colors.grey, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionStatus(BluetoothProvider provider) {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (provider.connectionState) {
      case AppBluetoothConnectionState.connected:
        statusColor = AppColors.btConnected;
        statusText =
            'Connected: ${provider.connectedDevice?.displayName ?? ""}';
        statusIcon = Icons.bluetooth_connected;
        break;
      case AppBluetoothConnectionState.connecting:
        statusColor = AppColors.btScanning;
        statusText = 'Connecting...';
        statusIcon = Icons.bluetooth_searching;
        break;
      case AppBluetoothConnectionState.disconnecting:
        statusColor = AppColors.btScanning;
        statusText = 'Disconnecting...';
        statusIcon = Icons.bluetooth_disabled;
        break;
      default:
        statusColor = AppColors.btDisconnected;
        statusText = 'Not connected';
        statusIcon = Icons.bluetooth_disabled;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(statusIcon, size: 32, color: statusColor),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        provider.isConnected ? 'Online' : 'Offline',
                        style: TextStyle(color: AppColors.gray600),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, BluetoothProvider provider) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: provider.isConnected || provider.isConnecting
                ? null
                : () => _startScan(context, provider),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            icon: provider.isScanning
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.search),
            label: Text(provider.isScanning ? 'Scanning...' : 'Scan Devices'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: provider.isConnected
                ? () => provider.disconnect()
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            icon: const Icon(Icons.bluetooth_disabled),
            label: const Text('Disconnect'),
          ),
        ),
      ],
    );
  }

  Widget _buildDeviceList(BuildContext context, BluetoothProvider provider) {
    if (provider.devices.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Icon(
                provider.isScanning
                    ? Icons.bluetooth_searching
                    : Icons.bluetooth_disabled,
                size: 48,
                color: AppColors.gray500,
              ),
              const SizedBox(height: 12),
              Text(
                provider.isScanning
                    ? 'Scanning for devices...'
                    : 'No devices found',
                style: TextStyle(color: AppColors.gray600),
              ),
              if (!provider.isScanning) ...[
                const SizedBox(height: 8),
                Text(
                  'Press "Scan Devices" to start searching',
                  style: TextStyle(color: AppColors.gray500, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: provider.devices.length,
      itemBuilder: (context, index) {
        final device = provider.devices[index];
        return _DeviceTile(
          device: device,
          onTap: () => provider.connect(device),
        );
      },
    );
  }

  Widget _buildReceivedDataCard(
    BuildContext context,
    BluetoothProvider provider,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Received Data',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatColumn(
                  icon: Icons.location_on,
                  value: '${provider.receivedPointsCount}',
                  label: 'Points',
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      final streamingProvider = context
                          .read<StreamingProvider>();
                      final routeProvider = context.read<RouteProvider>();
                      final isStreaming = streamingProvider.isStreaming;
                      final points = isStreaming
                          ? streamingProvider.streamedPoints
                          : provider.receivedPoints;
                      if (points.isNotEmpty) {
                        routeProvider.setPoints(points);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Uploaded ${points.length} points'),
                          ),
                        );
                        if (isStreaming && widget.onUploadToMap != null) {
                          widget.onUploadToMap!();
                        }
                      }
                    },
                    icon: const Icon(Icons.upload),
                    label: const Text('Upload to Map'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: provider.receivedPointsCount > 0
                        ? () => provider.clearBuffer()
                        : null,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                    ),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Clear Buffer'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startScan(
    BuildContext context,
    BluetoothProvider provider,
  ) async {
    // Request permissions first (Android 12+)
    final permissions = await _requestBluetoothPermissions();
    if (!permissions) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bluetooth permissions are required to scan for devices.'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
      return;
    }

    final isAvailable = await provider.checkBluetoothAvailable();
    if (!isAvailable) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Device does not support Bluetooth')),
        );
      }
      return;
    }

    final isOn = await provider.checkBluetoothOn();
    if (!isOn) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Please turn on Bluetooth')));
      }
      return;
    }

    await provider.startScan();
  }

  // Request Bluetooth permissions for Android 12+
  Future<bool> _requestBluetoothPermissions() async {
    // Android 12+ requires these permissions
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();

    // Check if all granted
    bool allGranted = statuses.values.every(
      (status) => status.isGranted || status.isLimited,
    );

    return allGranted;
  }
}

class _DeviceTile extends StatelessWidget {
  final BluetoothDeviceInfo device;
  final VoidCallback onTap;

  const _DeviceTile({required this.device, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.bluetooth, color: AppColors.primary),
        ),
        title: Text(
          device.displayName,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          'RSSI: ${device.rssi ?? "N/A"} dBm • ${device.signalStrength}',
        ),
        trailing: device.isConnecting
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.chevron_right),
        onTap: device.isConnecting ? null : onTap,
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _StatColumn({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: AppColors.primary, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: AppColors.gray500, fontSize: 12)),
      ],
    );
  }
}

/* End of file -------------------------------------------------------- */
