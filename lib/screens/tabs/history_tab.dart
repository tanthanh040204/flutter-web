// @file       history_tab.dart
// @brief      Tab UI for History.

/* Imports ------------------------------------------------------------ */
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/feature_config.dart';
import '../../models/history_route.dart';
import '../../providers/fleet_provider.dart';
import '../../services/firebase_repo.dart';
import '../history_route_map_screen.dart';

/* Public classes ----------------------------------------------------- */
class HistoryTab extends StatelessWidget {
  const HistoryTab({super.key});

  @override
  Widget build(BuildContext context) {
    final fleet = context.watch<FleetProvider>();
    final v = fleet.selectedOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('History (${FeatureConfig.historyKeepDays} days)'),
      ),
      body: v == null
          ? const Center(child: Text('No vehicle selected.'))
          : StreamBuilder<List<HistoryRouteRecord>>(
              stream: FirebaseRepo.instance.watchHistoryRoutes(
                v.id,
                keepDays: FeatureConfig.historyKeepDays,
              ),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final routes = snap.data ?? const <HistoryRouteRecord>[];
                if (routes.isEmpty) {
                  return const Center(child: Text('No route data available.'));
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: routes.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final route = routes[index];

                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.blueGrey.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        HistoryRouteMapScreen(route: route),
                                  ),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 18,
                                ),
                                child: Text(
                                  route.buttonLabel,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Delete route',
                            icon: const Icon(Icons.close),
                            onPressed: () async {
                              final ok = await showDialog<bool>(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title: const Text('Delete route'),
                                  content: Text(
                                    'Do you want to delete "${route.buttonLabel}"?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('Cancel'),
                                    ),
                                    FilledButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                ),
                              );

                              if (ok == true) {
                                try {
                                  await FirebaseRepo.instance
                                      .deleteHistoryRoute(
                                        route.vehicleId,
                                        route.id,
                                      );

                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Route deleted successfully',
                                        ),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Failed to delete route: $e',
                                        ),
                                      ),
                                    );
                                  }
                                }
                              }
                            },
                          ),
                          const SizedBox(width: 8),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}

/* End of file -------------------------------------------------------- */
