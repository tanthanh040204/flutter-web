// @file       history_tab.dart
// @brief      Tab UI for History.

/* Imports ------------------------------------------------------------ */
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_string.dart';
import '../../models/history_route.dart';
import '../../providers/fleet_provider.dart';
import '../../providers/language_provider.dart';
import '../../services/firebase_repo.dart';
import '../../widgets/vehicle_picker.dart';
import '../history_route_map_screen.dart';

/* Public classes ----------------------------------------------------- */
class HistoryTab extends StatefulWidget {
  const HistoryTab({super.key});

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

/* Private classes ---------------------------------------------------- */
class _HistoryTabState extends State<HistoryTab> {
  final Set<String> _selectedRouteIds = <String>{};
  final Set<String> _hiddenDeletedRouteIds = <String>{};
  bool _isDeleting = false;

  // Cache the Firestore stream per vehicle so it is not re-created on every
  // rebuild (FleetProvider notifies on each MQTT telemetry tick). Recreating
  // the stream would tear down / re-subscribe the StreamBuilder and flash the
  // loading spinner continuously.
  String? _streamVehicleId;
  Stream<List<HistoryRouteRecord>>? _routesStream;

  Stream<List<HistoryRouteRecord>> _routesStreamFor(String vehicleId) {
    if (_routesStream == null || _streamVehicleId != vehicleId) {
      _streamVehicleId = vehicleId;
      _routesStream =
          FirebaseRepo.instance.watchHistoryRoutes(vehicleId, keepDays: 30);
    }
    return _routesStream!;
  }

  Future<void> _deleteSelected(String vehicleId) async {
    final ids = _selectedRouteIds.toList(growable: false);
    if (ids.isEmpty || _isDeleting) return;

    setState(() {
      _isDeleting = true;
      _hiddenDeletedRouteIds.addAll(ids);
    });

    try {
      await FirebaseRepo.instance.deleteHistoryRoutes(vehicleId, ids);
      if (!mounted) return;
      setState(() {
        _selectedRouteIds.removeAll(ids);
        _isDeleting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              'Đã xóa ${ids.length} lộ trình đã chọn.',
              '${ids.length} selected routes deleted.',
            ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hiddenDeletedRouteIds.removeAll(ids);
        _isDeleting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              'Không xóa được lộ trình: $e',
              'Could not delete routes: $e',
            ),
          ),
        ),
      );
    }
  }

  Widget _buildBulkToolbar(String vehicleId, List<HistoryRouteRecord> routes) {
    final ids = routes.map((route) => route.id).toSet();
    final selectedCount = _selectedRouteIds.where(ids.contains).length;
    final allVisibleSelected = routes.isNotEmpty && selectedCount == routes.length;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                selectedCount == 0
                    ? context.tr('Chọn lộ trình cần xóa', 'Select routes to delete')
                    : context.tr('Đã chọn $selectedCount lộ trình', '$selectedCount routes selected'),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            TextButton.icon(
              onPressed: _isDeleting || routes.isEmpty
                  ? null
                  : () {
                      setState(() {
                        if (allVisibleSelected) {
                          _selectedRouteIds.removeAll(ids);
                        } else {
                          _selectedRouteIds.addAll(ids);
                        }
                      });
                    },
              icon: Icon(allVisibleSelected ? Icons.check_box : Icons.check_box_outline_blank),
              label: Text(
                context.tr(
                  allVisibleSelected ? 'Bỏ chọn' : 'Chọn tất cả',
                  allVisibleSelected ? 'Unselect' : 'Select all',
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: selectedCount == 0 || _isDeleting ? null : () => _deleteSelected(vehicleId),
              icon: const Icon(Icons.delete_outline),
              label: Text(context.tr('Xóa đã chọn', 'Delete selected')),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Only rebuild when the selected vehicle id changes — not on every
    // FleetProvider telemetry notify.
    final vehicleId =
        context.select<FleetProvider, String?>((f) => f.selectedOrNull?.id);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.loc(AppStrings.titleHistory)),
        actions: const [VehiclePicker(), SizedBox(width: 8)],
      ),
      body: vehicleId == null
          ? Center(child: Text(context.tr('Chưa chọn xe.', 'No vehicle selected.')))
          : StreamBuilder<List<HistoryRouteRecord>>(
              stream: _routesStreamFor(vehicleId),
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

                final routes = (snap.data ?? const <HistoryRouteRecord>[])
                    .where((route) => !_hiddenDeletedRouteIds.contains(route.id))
                    .toList();

                _selectedRouteIds.removeWhere(
                  (id) => !routes.any((route) => route.id == id),
                );

                if (routes.isEmpty) {
                  return Center(
                    child: Text(context.tr('Chưa có dữ liệu lộ trình.', 'No route history yet.')),
                  );
                }

                return Stack(
                  children: [
                    ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: routes.length + 1,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return _buildBulkToolbar(vehicleId, routes);
                        }

                        final route = routes[index - 1];
                        final selected = _selectedRouteIds.contains(route.id);

                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.blueGrey.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(14),
                            border: selected
                                ? Border.all(color: Theme.of(context).colorScheme.primary, width: 1.5)
                                : null,
                          ),
                          child: Row(
                            children: [
                              Checkbox(
                                value: selected,
                                onChanged: _isDeleting
                                    ? null
                                    : (value) {
                                        setState(() {
                                          if (value == true) {
                                            _selectedRouteIds.add(route.id);
                                          } else {
                                            _selectedRouteIds.remove(route.id);
                                          }
                                        });
                                      },
                              ),
                              Expanded(
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: _isDeleting
                                      ? null
                                      : () {
                                          if (_selectedRouteIds.isNotEmpty) {
                                            setState(() {
                                              if (selected) {
                                                _selectedRouteIds.remove(route.id);
                                              } else {
                                                _selectedRouteIds.add(route.id);
                                              }
                                            });
                                            return;
                                          }

                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  HistoryRouteMapScreen(route: route),
                                            ),
                                          );
                                        },
                                  onLongPress: _isDeleting
                                      ? null
                                      : () {
                                          setState(() => _selectedRouteIds.add(route.id));
                                        },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
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
                                onPressed: _isDeleting
                                    ? null
                                    : () async {
                                        setState(() {
                                          _isDeleting = true;
                                          _hiddenDeletedRouteIds.add(route.id);
                                        });

                                        try {
                                          await FirebaseRepo.instance.deleteHistoryRoute(
                                            vehicleId,
                                            route.id,
                                          );

                                          if (context.mounted) {
                                            setState(() {
                                              _selectedRouteIds.remove(route.id);
                                              _isDeleting = false;
                                            });
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text(context.tr('Đã xóa lộ trình.', 'Route deleted.')),
                                              ),
                                            );
                                          }
                                        } catch (e) {
                                          if (context.mounted) {
                                            setState(() {
                                              _hiddenDeletedRouteIds.remove(route.id);
                                              _isDeleting = false;
                                            });
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text(context.tr('Không xóa được lộ trình: $e', 'Could not delete route: $e')),
                                              ),
                                            );
                                          }
                                        }
                                      },
                              ),
                              const SizedBox(width: 8),
                            ],
                          ),
                        );
                      },
                    ),
                    if (_isDeleting)
                      Container(
                        color: Colors.black.withOpacity(0.06),
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                  ],
                );
              },
            ),
    );
  }
}

/* End of file -------------------------------------------------------- */
