import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_constants.dart';
import '../config/app_theme.dart';
import '../providers/route_provider.dart';
import '../utils/geo_utils.dart';
import '../utils/date_utils.dart';

/// ============================================
/// ROUTE INFO PANEL - Hiển thị thông tin route
/// ============================================

class RouteInfoPanel extends StatelessWidget {
  const RouteInfoPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<RouteProvider>(
      builder: (context, routeProvider, child) {
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
                    Icon(Icons.info_outline, color: AppColors.primary),
                    SizedBox(width: 8),
                    Text(
                      'Thông Tin Lộ Trình',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: UIConfig.paddingMedium),

                // Info items
                _buildInfoItem(
                  'Tổng điểm',
                  '${routeProvider.pointCount}',
                  Icons.location_on,
                ),
                _buildInfoItem(
                  'Khoảng cách',
                  GeoUtils.formatDistance(routeProvider.totalDistance),
                  Icons.straighten,
                ),
                _buildInfoItem(
                  'Thời gian bắt đầu',
                  AppDateUtils.formatDateTime(routeProvider.startTime),
                  Icons.play_arrow,
                ),
                _buildInfoItem(
                  'Thời gian kết thúc',
                  AppDateUtils.formatDateTime(routeProvider.endTime),
                  Icons.flag,
                ),

                if (routeProvider.fileName != null) ...[
                  const Divider(),
                  _buildInfoItem(
                    'File',
                    routeProvider.fileName!,
                    Icons.insert_drive_file,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoItem(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.gray500),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: AppColors.gray500),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
