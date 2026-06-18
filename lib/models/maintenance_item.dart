// @file       maintenance_item.dart
// @brief      Data model for Maintenance Item.

/* Public classes ----------------------------------------------------- */
class MaintenanceItem {
  final String id;
  final String name;

  // Total km at last maintenance.
  final double maintanceKm;
  // Maintenance cycle in km (0 if no maintenance needed).
  final double cycleKm;

  const MaintenanceItem({
    required this.id,
    required this.name,
    required this.maintanceKm,
    required this.cycleKm,
  });

  bool get isDue => cycleKm > 0 && maintanceKm >= cycleKm;

  MaintenanceItem copyWith({
    String? name,
    double? maintanceKm,
    double? cycleKm,
  }) {
    return MaintenanceItem(
      id: id,
      name: name ?? this.name,
      maintanceKm: maintanceKm ?? this.maintanceKm,
      cycleKm: cycleKm ?? this.cycleKm,
    );
  }

  Map<String, dynamic> toMap() {
    return {'name': name, 'maintanceKm': maintanceKm, 'cycleKm': cycleKm};
  }

  factory MaintenanceItem.fromMap(String id, Map<String, dynamic> map) {
    double asDouble(dynamic value) {
      if (value is num) return value.toDouble();
      return double.tryParse('${value ?? 0}') ?? 0;
    }

    return MaintenanceItem(
      id: id,
      name: (map['name'] ?? id).toString(),
      maintanceKm: asDouble(map['maintanceKm'] ?? map['maintenanceKm']),
      cycleKm: asDouble(map['cycleKm'] ?? map['intervalKm']),
    );
  }

  // Default seed list — used by both `MaintenanceProvider.ensureDefaults`
  // and `FirebaseRepo.ensureDefaultMaintenanceItems`. Keep them in sync
  // by always referencing this constant rather than duplicating literals.
  static const List<MaintenanceItem> defaultSeed = <MaintenanceItem>[
    MaintenanceItem(
      id: 'oil',
      name: 'Oil change',
      maintanceKm: 0,
      cycleKm: 2000,
    ),
    MaintenanceItem(
      id: 'brake',
      name: 'Brake fluid service',
      maintanceKm: 0,
      cycleKm: 4000,
    ),
    MaintenanceItem(
      id: 'battery',
      name: 'Battery check / replacement',
      maintanceKm: 0,
      cycleKm: 12000,
    ),
  ];
}

/* End of file -------------------------------------------------------- */
