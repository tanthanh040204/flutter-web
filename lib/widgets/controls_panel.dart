// @file       controls_panel.dart
// @brief      Widget for Controls Panel.

/* Imports ------------------------------------------------------------ */
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_constants.dart';
import '../config/app_theme.dart';
import '../providers/route_provider.dart';

/* Public classes ----------------------------------------------------- */
class ControlsPanel extends StatelessWidget {
  final VoidCallback? onFitBounds;

  const ControlsPanel({super.key, this.onFitBounds});

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
                    Icon(Icons.settings, color: AppColors.primary),
                    SizedBox(width: 8),
                    Text(
                      'Controls',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: UIConfig.paddingMedium),

                // Buttons row
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: routeProvider.hasRoute ? onFitBounds : null,
                        icon: const Icon(Icons.zoom_out_map),
                        label: const Text('Fit'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: routeProvider.hasRoute
                            ? () => routeProvider.clearRoute()
                            : null,
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Xóa'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: UIConfig.paddingSmall),

                // Toggle markers
                SwitchListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Hiện điểm đánh dấu'),
                  value: routeProvider.showMarkers,
                  onChanged: routeProvider.hasRoute
                      ? (value) => routeProvider.setShowMarkers(value)
                      : null,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/* End of file -------------------------------------------------------- */
