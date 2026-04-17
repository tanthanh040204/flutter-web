// @file       points_list_panel.dart
// @brief      Widget for Points List Panel.

/* Imports ------------------------------------------------------------ */
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_constants.dart';
import '../config/app_theme.dart';
import '../models/route_point.dart';
import '../providers/route_provider.dart';


/* Public classes ----------------------------------------------------- */
class PointsListPanel extends StatelessWidget {
  final Function(RoutePoint point, int index)? onPointTap;

  const PointsListPanel({super.key, this.onPointTap});

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
                Row(
                  children: [
                    const Icon(Icons.list, color: AppColors.primary),
                    const SizedBox(width: 8),
                    const Text(
                      'Points List',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const Spacer(),
                    if (routeProvider.hasRoute)
                      Text(
                        '${routeProvider.pointCount} points',
                        style: const TextStyle(color: AppColors.gray500),
                      ),
                  ],
                ),
                const SizedBox(height: UIConfig.paddingSmall),

                // Points list
                if (routeProvider.hasRoute)
                  _buildPointsList(routeProvider.points)
                else
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(UIConfig.paddingLarge),
                      child: Text(
                        'No data available',
                        style: TextStyle(
                          color: AppColors.gray500,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPointsList(List<RoutePoint> points) {
    // Limit display points
    final displayPoints = points.length > UIConfig.maxDisplayPoints
        ? points.sublist(0, UIConfig.maxDisplayPoints)
        : points;

    return Container(
      constraints: const BoxConstraints(maxHeight: 200),
      decoration: BoxDecoration(
        color: AppColors.gray100,
        borderRadius: BorderRadius.circular(UIConfig.borderRadiusSmall),
      ),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount:
            displayPoints.length +
            (points.length > UIConfig.maxDisplayPoints ? 1 : 0),
        itemBuilder: (context, index) {
          // Show "more" item
          if (index >= displayPoints.length) {
            return ListTile(
              dense: true,
              title: Text(
                '... and ${points.length - UIConfig.maxDisplayPoints} more points',
                style: const TextStyle(
                  color: AppColors.gray500,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            );
          }

          final point = displayPoints[index];
          final isFirst = index == 0;
          final isLast = index == points.length - 1;

          return ListTile(
            dense: true,
            leading: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: isFirst
                    ? AppColors.startMarker
                    : isLast
                    ? AppColors.endMarker
                    : AppColors.normalMarker,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            title: Text(point.displayName, overflow: TextOverflow.ellipsis),
            subtitle: point.name != null
                ? Text(
                    point.formattedCoords,
                    style: const TextStyle(fontSize: 11),
                  )
                : null,
            onTap: () => onPointTap?.call(point, index),
          );
        },
      ),
    );
  }
}

/* End of file -------------------------------------------------------- */
