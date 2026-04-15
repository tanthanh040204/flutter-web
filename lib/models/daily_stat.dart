class DailyStat {
  final DateTime day; // yyyy-mm-dd
  final double distanceKm;
  final double avgSpeedKmh;
  final double maxSpeedKmh;

  const DailyStat({
    required this.day,
    required this.distanceKm,
    required this.avgSpeedKmh,
    required this.maxSpeedKmh,
  });
}
