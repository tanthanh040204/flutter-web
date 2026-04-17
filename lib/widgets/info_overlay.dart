// @file       info_overlay.dart
// @brief      Widget for Info Overlay.

/* Imports ------------------------------------------------------------ */
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_theme.dart';
import '../providers/bluetooth_provider.dart';
import '../providers/route_provider.dart';
import '../providers/streaming_provider.dart';

/* Public classes ----------------------------------------------------- */
class InfoOverlay extends StatelessWidget {
  const InfoOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer3<BluetoothProvider, RouteProvider, StreamingProvider>(
      builder: (context, btProvider, routeProvider, streamingProvider, child) {
        return Stack(
          children: [
            // Top-left: Connection status
            Positioned(
              top: 8,
              left: 8,
              child: _ConnectionChip(btProvider: btProvider),
            ),

            // Top-right: Route info
            if (routeProvider.hasRoute)
              Positioned(
                top: 8,
                right: 8,
                child: _RouteInfoChip(routeProvider: routeProvider),
              ),

            // Bottom-left: Streaming info (when active or has current point)
            if (streamingProvider.isStreaming ||
                streamingProvider.currentPoint != null)
              Positioned(
                bottom: 8,
                left: 8,
                right: 8,
                child: _StreamingPanel(streamingProvider: streamingProvider),
              ),
          ],
        );
      },
    );
  }
}

// Connection status chip
/* Private classes ---------------------------------------------------- */
class _ConnectionChip extends StatelessWidget {
  final BluetoothProvider btProvider;

  const _ConnectionChip({required this.btProvider});

  @override
  Widget build(BuildContext context) {
    final isConnected = btProvider.isConnected;
    final isScanning = btProvider.isScanning;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: isConnected
                  ? AppColors.btConnected
                  : isScanning
                  ? AppColors.btScanning
                  : AppColors.btDisconnected,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Icon(
            isConnected
                ? Icons.bluetooth_connected
                : isScanning
                ? Icons.bluetooth_searching
                : Icons.bluetooth_disabled,
            size: 16,
            color: isConnected ? AppColors.btConnected : AppColors.gray600,
          ),
          const SizedBox(width: 4),
          Text(
            isConnected
                ? 'BT: ${btProvider.connectedDevice?.name ?? "MCU"}'
                : isScanning
                ? 'Scanning...'
                : 'Offline',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isConnected ? AppColors.btConnected : AppColors.gray600,
            ),
          ),
          if (btProvider.receivedPointsCount > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${btProvider.receivedPointsCount}',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// Route info chip
class _RouteInfoChip extends StatelessWidget {
  final RouteProvider routeProvider;

  const _RouteInfoChip({required this.routeProvider});

  @override
  Widget build(BuildContext context) {
    final distance = routeProvider.totalDistance;
    final pointCount = routeProvider.pointCount;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.route, size: 16, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            distance >= 1
                ? '${distance.toStringAsFixed(2)} km'
                : '${(distance * 1000).toStringAsFixed(0)} m',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 8),
          Container(width: 1, height: 12, color: AppColors.gray300),
          const SizedBox(width: 8),
          Icon(Icons.location_on, size: 14, color: AppColors.gray600),
          const SizedBox(width: 4),
          Text(
            '$pointCount',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

// Streaming panel (shows current position, speed, etc.)
class _StreamingPanel extends StatelessWidget {
  final StreamingProvider streamingProvider;

  const _StreamingPanel({required this.streamingProvider});

  @override
  Widget build(BuildContext context) {
    final currentPoint = streamingProvider.currentPoint;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with streaming indicator
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.danger,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'LIVE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppColors.danger,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (streamingProvider.streamDuration != null)
                Text(
                  _formatDuration(streamingProvider.streamDuration!),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.gray600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Main stats row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _StreamingStat(
                icon: Icons.speed,
                value: currentPoint?.speed != null
                    ? '${currentPoint!.speed!.toStringAsFixed(1)}'
                    : '--',
                unit: 'km/h',
                label: 'Speed',
              ),
              _StreamingStat(
                icon: Icons.terrain,
                value: currentPoint?.altitude != null
                    ? '${currentPoint!.altitude!.toStringAsFixed(0)}'
                    : '--',
                unit: 'm',
                label: 'Altitude',
              ),
              _StreamingStat(
                icon: Icons.explore,
                value: currentPoint?.heading != null
                    ? '${currentPoint!.heading!.toStringAsFixed(0)}°'
                    : '--',
                unit: '',
                label: 'Heading',
              ),
              _StreamingStat(
                icon: Icons.gps_fixed,
                value: currentPoint?.accuracy != null
                    ? '±${currentPoint!.accuracy!.toStringAsFixed(0)}'
                    : '--',
                unit: 'm',
                label: 'Accuracy',
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Current position
          if (currentPoint != null)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.gray100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.my_location,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      currentPoint.formattedCoords,
                      style: const TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Stats summary
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Max: ${streamingProvider.maxSpeed.toStringAsFixed(1)} km/h',
                style: TextStyle(fontSize: 11, color: AppColors.gray600),
              ),
              Text(
                'Avg: ${streamingProvider.avgSpeed.toStringAsFixed(1)} km/h',
                style: TextStyle(fontSize: 11, color: AppColors.gray600),
              ),
              Text(
                'Dist: ${streamingProvider.totalDistance.toStringAsFixed(2)} km',
                style: TextStyle(fontSize: 11, color: AppColors.gray600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }
}

class _StreamingStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String unit;
  final String label;

  const _StreamingStat({
    required this.icon,
    required this.value,
    required this.unit,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(height: 4),
        RichText(
          text: TextSpan(
            style: TextStyle(color: AppColors.gray900),
            children: [
              TextSpan(
                text: value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (unit.isNotEmpty)
                TextSpan(text: ' $unit', style: const TextStyle(fontSize: 10)),
            ],
          ),
        ),
        Text(label, style: TextStyle(fontSize: 10, color: AppColors.gray600)),
      ],
    );
  }
}

/* End of file -------------------------------------------------------- */
