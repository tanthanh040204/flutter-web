class MaintenanceItem {
  final String id;
  final String name;

  /// Số km đã đi kể từ lần bảo dưỡng gần nhất.
  /// Giữ đúng tên field theo yêu cầu của bạn: maintanceKm.
  final double maintanceKm;

  /// Chu kỳ bảo dưỡng (km).
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
    return {
      'name': name,
      'maintanceKm': maintanceKm,
      'cycleKm': cycleKm,
    };
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
}
