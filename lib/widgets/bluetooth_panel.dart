import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_constants.dart';
import '../config/app_theme.dart';
import '../models/bluetooth_device_info.dart';
import '../providers/bluetooth_provider.dart';
import '../providers/route_provider.dart';

/// ============================================
/// BLUETOOTH PANEL - UI kết nối Bluetooth
/// ============================================

class BluetoothPanel extends StatelessWidget {
  const BluetoothPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<BluetoothProvider>(
      builder: (context, btProvider, child) {
        return Card(
          margin: const EdgeInsets.all(UIConfig.paddingSmall),
          child: Padding(
            padding: const EdgeInsets.all(UIConfig.paddingMedium),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                const Row(
                  children: [
                    Icon(Icons.bluetooth, color: AppColors.primary),
                    SizedBox(width: 8),
                    Text(
                      'Bluetooth (MCU)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: UIConfig.paddingMedium),

                // Connection status
                _buildConnectionStatus(btProvider),
                const SizedBox(height: UIConfig.paddingSmall),

                // Scan/Connect buttons
                _buildButtons(context, btProvider),
                const SizedBox(height: UIConfig.paddingSmall),

                // Device list (when scanning)
                if (btProvider.isScanning || btProvider.devices.isNotEmpty)
                  _buildDeviceList(context, btProvider),

                // Received points info
                if (btProvider.isConnected) ...[
                  const Divider(),
                  _buildReceivedInfo(context, btProvider),
                ],

                // Error message
                if (btProvider.error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      btProvider.error!,
                      style: const TextStyle(color: AppColors.danger),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildConnectionStatus(BluetoothProvider btProvider) {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (btProvider.connectionState) {
      case AppBluetoothConnectionState.connected:
        statusColor = AppColors.btConnected;
        statusText =
            'Đã kết nối: ${btProvider.connectedDevice?.displayName ?? ""}';
        statusIcon = Icons.bluetooth_connected;
        break;
      case AppBluetoothConnectionState.connecting:
        statusColor = AppColors.btScanning;
        statusText = 'Đang kết nối...';
        statusIcon = Icons.bluetooth_searching;
        break;
      case AppBluetoothConnectionState.disconnecting:
        statusColor = AppColors.btScanning;
        statusText = 'Đang ngắt kết nối...';
        statusIcon = Icons.bluetooth_disabled;
        break;
      default:
        statusColor = AppColors.btDisconnected;
        statusText = 'Chưa kết nối';
        statusIcon = Icons.bluetooth_disabled;
    }

    return Container(
      padding: const EdgeInsets.all(UIConfig.paddingSmall),
      decoration: BoxDecoration(
        color: AppColors.gray100,
        borderRadius: BorderRadius.circular(UIConfig.borderRadiusSmall),
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
              boxShadow: btProvider.isConnected
                  ? [
                      BoxShadow(
                        color: statusColor.withValues(alpha: 0.5),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
          ),
          const SizedBox(width: 8),
          Icon(statusIcon, size: 20, color: statusColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              statusText,
              style: const TextStyle(fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButtons(BuildContext context, BluetoothProvider btProvider) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: btProvider.isConnected || btProvider.isConnecting
                ? null
                : () => _startScan(context, btProvider),
            icon: btProvider.isScanning
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.search),
            label: Text(btProvider.isScanning ? 'Đang scan...' : 'Scan'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ElevatedButton.icon(
            onPressed:
                btProvider.isConnected ? () => btProvider.disconnect() : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
            ),
            icon: const Icon(Icons.bluetooth_disabled),
            label: const Text('Ngắt'),
          ),
        ),
      ],
    );
  }

  Widget _buildDeviceList(BuildContext context, BluetoothProvider btProvider) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 150),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: btProvider.devices.length,
        itemBuilder: (context, index) {
          final device = btProvider.devices[index];
          return ListTile(
            dense: true,
            leading: const Icon(Icons.bluetooth),
            title: Text(device.displayName),
            subtitle: Text('RSSI: ${device.rssi ?? "N/A"} dBm'),
            trailing: device.isConnecting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.chevron_right),
            onTap:
                device.isConnecting ? null : () => btProvider.connect(device),
          );
        },
      ),
    );
  }

  Widget _buildReceivedInfo(
      BuildContext context, BluetoothProvider btProvider) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Điểm nhận được:'),
            Text(
              '${btProvider.receivedPointsCount}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: UIConfig.paddingSmall),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: btProvider.receivedPointsCount > 0
                    ? () => _uploadToMap(context, btProvider)
                    : null,
                icon: const Icon(Icons.upload),
                label: const Text('Upload'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: btProvider.receivedPointsCount > 0
                    ? () => btProvider.clearBuffer()
                    : null,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Xóa'),
              ),
            ),
          ],
        ),
        const SizedBox(height: UIConfig.paddingSmall),
        // Realtime mode toggle
        Consumer<RouteProvider>(
          builder: (context, routeProvider, child) {
            return SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('Realtime mode'),
              subtitle: const Text('Vẽ ngay khi nhận'),
              value: routeProvider.realtimeMode,
              onChanged: (value) => routeProvider.setRealtimeMode(value),
            );
          },
        ),
      ],
    );
  }

  Future<void> _startScan(
      BuildContext context, BluetoothProvider btProvider) async {
    final isAvailable = await btProvider.checkBluetoothAvailable();
    if (!isAvailable) {
      _showSnackBar(context, 'Thiết bị không hỗ trợ Bluetooth');
      return;
    }

    final isOn = await btProvider.checkBluetoothOn();
    if (!isOn) {
      _showSnackBar(context, 'Vui lòng bật Bluetooth');
      return;
    }

    await btProvider.startScan();
  }

  void _uploadToMap(BuildContext context, BluetoothProvider btProvider) {
    final routeProvider = context.read<RouteProvider>();
    routeProvider.setPoints(btProvider.receivedPoints);
    _showSnackBar(
        context, 'Đã upload ${btProvider.receivedPointsCount} điểm lên bản đồ');
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: UIConfig.notificationDurationSeconds),
      ),
    );
  }
}
