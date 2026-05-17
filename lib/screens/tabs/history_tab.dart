// @file       history_tab.dart
// @brief      Tab UI for History.

/* Imports ------------------------------------------------------------ */
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/history_route.dart';
import '../../providers/fleet_provider.dart';
import '../../providers/language_provider.dart';
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
      appBar: AppBar(title: Text(context.tr('Lịch sử (30 ngày)', 'History (30 days)'))),
      body: v == null
          ? Center(child: Text(context.tr('Chưa chọn xe.', 'No vehicle selected.')))
          : StreamBuilder<List<HistoryRouteRecord>>(
              stream: FirebaseRepo.instance.watchHistoryRoutes(
                v.id,
                keepDays: 30,
              ),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snap.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        context.tr('Không đọc được lịch sử lộ trình: ${snap.error}', 'Could not read route history: ${snap.error}'),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                final routes = snap.data ?? const <HistoryRouteRecord>[];
                if (routes.isEmpty) {
                  return Center(
                    child: Text(context.tr('Chưa có dữ liệu lộ trình.', 'No route history yet.')),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: routes.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final route = routes[index];

                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.blueGrey.withOpacity(0.18),
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
                            tooltip: context.tr('Xóa lộ trình', 'Delete route'),
                            icon: const Icon(Icons.close),
                            onPressed: () async {
                              final ok = await showDialog<bool>(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title: Text(context.tr('Xóa lộ trình', 'Delete route')),
                                  content: Text(
                                    context.tr('Bạn muốn xóa "${route.buttonLabel}"?', 'Delete "${route.buttonLabel}"?'),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: Text(context.tr('Hủy', 'Cancel')),
                                    ),
                                    FilledButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: Text(context.tr('Xóa', 'Delete')),
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
                                      SnackBar(
                                        content: Text(context.tr('Đã xóa lộ trình', 'Route deleted.')),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(context.tr('Không xóa được lộ trình: $e', 'Could not delete route: $e')),
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