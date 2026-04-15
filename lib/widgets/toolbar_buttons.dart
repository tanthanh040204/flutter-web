import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_theme.dart';
import '../providers/bluetooth_provider.dart';
import '../providers/route_provider.dart';
import '../screens/bluetooth_page.dart';
import '../screens/upload_page.dart';
import '../screens/controls_page.dart';

/// ============================================
/// TOOLBAR BUTTONS - Các nút điều khiển trên AppBar
/// ============================================

/// Bluetooth icon button with status indicator
class BluetoothToolbarButton extends StatelessWidget {
  const BluetoothToolbarButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<BluetoothProvider>(
      builder: (context, btProvider, child) {
        final isConnected = btProvider.isConnected;
        final isScanning = btProvider.isScanning;

        return IconButton(
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                isConnected
                    ? Icons.bluetooth_connected
                    : isScanning
                        ? Icons.bluetooth_searching
                        : Icons.bluetooth,
                size: 24,
              ),
              // Status dot
              Positioned(
                right: -4,
                top: -4,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: isConnected
                        ? AppColors.btConnected
                        : isScanning
                            ? AppColors.btScanning
                            : AppColors.btDisconnected,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.white, width: 1.5),
                  ),
                ),
              ),
            ],
          ),
          tooltip: isConnected
              ? 'Bluetooth: Đã kết nối'
              : isScanning
                  ? 'Đang scan...'
                  : 'Bluetooth',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const BluetoothPage()),
          ),
        );
      },
    );
  }
}

/// Upload icon button with data indicator
class UploadToolbarButton extends StatelessWidget {
  const UploadToolbarButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<RouteProvider>(
      builder: (context, routeProvider, child) {
        final hasRoute = routeProvider.points.isNotEmpty;

        return IconButton(
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.upload_file, size: 24),
              // Data indicator dot
              if (hasRoute)
                Positioned(
                  right: -4,
                  top: -4,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.white, width: 1.5),
                    ),
                  ),
                ),
            ],
          ),
          tooltip: hasRoute
              ? 'Route: ${routeProvider.points.length} điểm'
              : 'Upload Route',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const UploadPage()),
          ),
        );
      },
    );
  }
}

/// Controls icon button
class ControlsToolbarButton extends StatelessWidget {
  final VoidCallback? onFitRoute;
  final VoidCallback? onCenterUser;

  const ControlsToolbarButton({
    super.key,
    this.onFitRoute,
    this.onCenterUser,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.tune, size: 24),
      tooltip: 'Điều khiển',
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ControlsPage(
            onFitRoute: onFitRoute,
            onCenterUser: onCenterUser,
          ),
        ),
      ),
    );
  }
}
