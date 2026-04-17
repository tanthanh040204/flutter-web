// @file       controls_page.dart
// @brief      Screen UI for Controls.

/* Imports ------------------------------------------------------------ */
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_theme.dart';
import '../providers/bluetooth_provider.dart';
import '../providers/route_provider.dart';
import '../providers/streaming_provider.dart';

/* Public classes ----------------------------------------------------- */
class ControlsPage extends StatelessWidget {
  final VoidCallback? onFitRoute;
  final VoidCallback? onCenterUser;

  const ControlsPage({super.key, this.onFitRoute, this.onCenterUser});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Controls'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Consumer3<RouteProvider, StreamingProvider, BluetoothProvider>(
        builder:
            (context, routeProvider, streamingProvider, btProvider, child) {
              final isConnected = btProvider.isConnected;
              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Map controls
                    const Text(
                      'Map Controls',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),

                    _buildControlItem(
                      icon: Icons.fit_screen,
                      title: 'Fit Route',
                      subtitle: 'Zoom to display entire route',
                      onTap: routeProvider.points.isNotEmpty
                          ? () {
                              Navigator.pop(context);
                              onFitRoute?.call();
                            }
                          : null,
                    ),

                    _buildControlItem(
                      icon: Icons.my_location,
                      title: 'Current Location',
                      subtitle: 'Center on GPS location',
                      onTap: () {
                        Navigator.pop(context);
                        onCenterUser?.call();
                      },
                    ),

                    const SizedBox(height: 24),

                    // Streaming controls
                    const Text(
                      'Streaming GPS',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),

                    _buildStreamingStatus(streamingProvider),
                    const SizedBox(height: 12),

                    // Warning nếu chưa kết nối
                    if (!isConnected)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.warning.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.warning_amber, color: AppColors.warning),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Connect Bluetooth MCU to use streaming',
                                style: TextStyle(color: AppColors.warning),
                              ),
                            ),
                          ],
                        ),
                      ),

                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed:
                                !isConnected || streamingProvider.isStreaming
                                ? null
                                : () => streamingProvider.startStreaming(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.success,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('Start'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: streamingProvider.isStreaming
                                ? () => streamingProvider.stopStreaming()
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.danger,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            icon: const Icon(Icons.stop),
                            label: const Text('Stop'),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Statistics
                    if (streamingProvider.streamedPoints.isNotEmpty) ...[
                      const Text(
                        'Statistics',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildStatisticsCard(streamingProvider),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              _confirmClearStream(context, streamingProvider),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.danger,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Xóa dữ liệu streaming'),
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Route statistics
                    if (routeProvider.points.isNotEmpty) ...[
                      const Text(
                        'Route Info',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildRouteInfoCard(routeProvider),
                    ],
                  ],
                ),
              );
            },
      ),
    );
  }

  Widget _buildControlItem({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    final isEnabled = onTap != null;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        enabled: isEnabled,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: (isEnabled ? AppColors.primary : AppColors.gray500)
                .withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: isEnabled ? AppColors.primary : AppColors.gray500,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: isEnabled ? null : AppColors.gray500,
          ),
        ),
        subtitle: Text(subtitle),
        trailing: Icon(
          Icons.chevron_right,
          color: isEnabled ? null : AppColors.gray500,
        ),
        onTap: onTap,
      ),
    );
  }

  Widget _buildStreamingStatus(StreamingProvider provider) {
    final isStreaming = provider.isStreaming;

    return Card(
      color: isStreaming
          ? AppColors.success.withValues(alpha: 0.1)
          : AppColors.gray100,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: isStreaming ? AppColors.success : AppColors.gray500,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isStreaming ? 'Streaming...' : 'Paused',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isStreaming
                          ? AppColors.success
                          : AppColors.gray600,
                    ),
                  ),
                  Text(
                    '${provider.streamedPoints.length} points recorded',
                    style: TextStyle(fontSize: 12, color: AppColors.gray600),
                  ),
                ],
              ),
            ),
            if (isStreaming && provider.currentSpeed != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${provider.currentSpeed!.toStringAsFixed(1)} km/h',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Speed',
                    style: TextStyle(fontSize: 12, color: AppColors.gray600),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatisticsCard(StreamingProvider provider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                _StatTile(
                  icon: Icons.straighten,
                  value:
                      '${(provider.totalDistance / 1000).toStringAsFixed(2)}',
                  unit: 'km',
                  label: 'Distance',
                ),
                const SizedBox(width: 16),
                _StatTile(
                  icon: Icons.speed,
                  value: provider.averageSpeed?.toStringAsFixed(1) ?? '--',
                  unit: 'km/h',
                  label: 'Average Speed',
                ),
                const SizedBox(width: 16),
                _StatTile(
                  icon: Icons.trending_up,
                  value: provider.maxSpeed > 0
                      ? provider.maxSpeed.toStringAsFixed(1)
                      : '--',
                  unit: 'km/h',
                  label: 'Max Speed',
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                _StatTile(
                  icon: Icons.location_on,
                  value: '${provider.streamedPoints.length}',
                  unit: '',
                  label: 'Points',
                ),
                const SizedBox(width: 16),
                _StatTile(
                  icon: Icons.timer,
                  value: _formatDuration(provider.streamingDuration),
                  unit: '',
                  label: 'Duration',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteInfoCard(RouteProvider provider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _StatTile(
              icon: Icons.location_on,
              value: '${provider.points.length}',
              unit: '',
              label: 'Points',
            ),
            _StatTile(
              icon: Icons.straighten,
              value: '${(provider.totalDistance / 1000).toStringAsFixed(2)}',
              unit: 'km',
              label: 'Distance',
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration? duration) {
    if (duration == null) return '--:--';

    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void _confirmClearStream(BuildContext context, StreamingProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm'),
        content: const Text('Delete all streaming data?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              provider.clearStreamedPoints();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

/* Private classes ---------------------------------------------------- */
class _StatTile extends StatelessWidget {
  final IconData icon;
  final String value;
  final String unit;
  final String label;

  const _StatTile({
    required this.icon,
    required this.value,
    required this.unit,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: AppColors.primary, size: 24),
          const SizedBox(height: 8),
          RichText(
            text: TextSpan(
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              children: [
                TextSpan(text: value),
                if (unit.isNotEmpty)
                  TextSpan(
                    text: ' $unit',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.normal,
                      color: AppColors.gray600,
                    ),
                  ),
              ],
            ),
          ),
          Text(label, style: TextStyle(fontSize: 12, color: AppColors.gray600)),
        ],
      ),
    );
  }
}

/* End of file -------------------------------------------------------- */
