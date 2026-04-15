import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/history_route.dart';
import '../../providers/fleet_provider.dart';
import '../../services/firebase_repo.dart';
import '../history_route_map_screen.dart';

class HistoryTab extends StatelessWidget {
  const HistoryTab({super.key});

  @override
  Widget build(BuildContext context) {
    final fleet = context.watch<FleetProvider>();
    final v = fleet.selectedOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Lịch sử (30 ngày)')),
      body: v == null
          ? const Center(child: Text('Chưa có xe nào để hiển thị.'))
          : StreamBuilder<List<HistoryRouteRecord>>(
              stream: FirebaseRepo.instance.watchHistoryRoutes(
                v.id,
                keepDays: 30,
              ),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final routes = snap.data ?? const <HistoryRouteRecord>[];
                if (routes.isEmpty) {
                  return const Center(
                    child: Text('Chưa có dữ liệu hành trình.'),
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
                            tooltip: 'Xóa lộ trình',
                            icon: const Icon(Icons.close),
                            onPressed: () async {
                              final ok = await showDialog<bool>(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title: const Text('Xóa lộ trình'),
                                  content: Text(
                                    'Bạn có muốn xóa "${route.buttonLabel}" không?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('Hủy'),
                                    ),
                                    FilledButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: const Text('Xóa'),
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
                                        content: Text('Đã xóa lộ trình'),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Không thể xóa: $e'),
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
