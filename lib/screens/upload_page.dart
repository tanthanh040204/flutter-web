import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_theme.dart';
import '../providers/bluetooth_provider.dart';
import '../providers/route_provider.dart';

/// ============================================
/// UPLOAD PAGE - Trang upload file/dữ liệu
/// ============================================

class UploadPage extends StatelessWidget {
  const UploadPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Route'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Consumer2<RouteProvider, BluetoothProvider>(
        builder: (context, routeProvider, btProvider, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Current route info
                _buildCurrentRouteCard(routeProvider),
                const SizedBox(height: 24),

                // Bluetooth data card
                _buildBluetoothDataCard(context, btProvider, routeProvider),
                const SizedBox(height: 24),

                // Upload options
                const Text(
                  'Chọn nguồn dữ liệu',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),

                _buildUploadOption(
                  context,
                  icon: Icons.folder_open,
                  title: 'Chọn file từ thiết bị',
                  subtitle: 'Hỗ trợ JSON, GPX',
                  onTap: () => _uploadFromFile(context, routeProvider),
                ),

                _buildUploadOption(
                  context,
                  icon: Icons.data_object,
                  title: 'Load Sample Data',
                  subtitle: 'Dữ liệu mẫu để test',
                  onTap: () => _loadSampleData(context, routeProvider),
                ),

                const SizedBox(height: 24),

                // Clear route
                if (routeProvider.points.isNotEmpty)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          _confirmClearRoute(context, routeProvider),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.danger,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Xóa route hiện tại'),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCurrentRouteCard(RouteProvider provider) {
    final hasRoute = provider.points.isNotEmpty;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: (hasRoute ? AppColors.success : AppColors.gray500)
                    .withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                hasRoute ? Icons.route : Icons.map_outlined,
                size: 32,
                color: hasRoute ? AppColors.success : AppColors.gray500,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasRoute ? 'Route đã tải' : 'Chưa có route',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: hasRoute ? AppColors.success : AppColors.gray600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (hasRoute) ...[
                    Text(
                      '${provider.points.length} điểm',
                      style: TextStyle(color: AppColors.gray600),
                    ),
                    if (provider.totalDistance > 0)
                      Text(
                        'Khoảng cách: ${(provider.totalDistance / 1000).toStringAsFixed(2)} km',
                        style: TextStyle(color: AppColors.gray600),
                      ),
                    if (provider.fileName != null)
                      Text(
                        'Nguồn: ${provider.fileName}',
                        style:
                            TextStyle(color: AppColors.gray600, fontSize: 12),
                      ),
                  ] else
                    Text(
                      'Upload file để bắt đầu',
                      style: TextStyle(color: AppColors.gray600),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBluetoothDataCard(
    BuildContext context,
    BluetoothProvider btProvider,
    RouteProvider routeProvider,
  ) {
    final hasData = btProvider.receivedPointsCount > 0;

    return Card(
      color: hasData ? AppColors.primary.withValues(alpha: 0.05) : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.bluetooth,
                  color: hasData ? AppColors.primary : AppColors.gray500,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Dữ liệu từ Bluetooth',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${btProvider.receivedPointsCount} điểm trong buffer',
                        style: TextStyle(
                          color: AppColors.gray600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                if (hasData)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      '${btProvider.receivedPointsCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            if (hasData) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        routeProvider.setPoints(btProvider.receivedPoints);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Đã upload ${btProvider.receivedPointsCount} điểm',
                            ),
                            backgroundColor: AppColors.success,
                          ),
                        );
                      },
                      icon: const Icon(Icons.upload),
                      label: const Text('Upload lên Map'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => btProvider.clearBuffer(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.danger,
                      ),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Xóa buffer'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildUploadOption(
    BuildContext context, {
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

  Future<void> _uploadFromFile(
      BuildContext context, RouteProvider provider) async {
    await provider.loadFromFilePicker();
    if (context.mounted && provider.points.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã upload ${provider.points.length} điểm'),
          backgroundColor: AppColors.success,
        ),
      );
    } else if (context.mounted && provider.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi: ${provider.error}'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  Future<void> _loadSampleData(
      BuildContext context, RouteProvider provider) async {
    await provider.loadSampleData();
    if (context.mounted && provider.points.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã load ${provider.points.length} điểm từ sample'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  void _confirmClearRoute(BuildContext context, RouteProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận'),
        content: const Text('Bạn có chắc muốn xóa route hiện tại?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              provider.clearRoute();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Đã xóa route')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
            ),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
  }
}
