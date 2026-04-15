import 'package:intl/intl.dart';

/// ============================================
/// DATE UTILITIES - Format ngày giờ
/// ============================================

class AppDateUtils {
  AppDateUtils._();

  static final DateFormat _dateTimeFormat = DateFormat('dd/MM/yyyy HH:mm:ss');
  static final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');
  static final DateFormat _timeFormat = DateFormat('HH:mm:ss');

  /// Format DateTime đầy đủ
  static String formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return '--';
    return _dateTimeFormat.format(dateTime);
  }

  /// Format Date
  static String formatDate(DateTime? dateTime) {
    if (dateTime == null) return '--';
    return _dateFormat.format(dateTime);
  }

  /// Format Time
  static String formatTime(DateTime? dateTime) {
    if (dateTime == null) return '--';
    return _timeFormat.format(dateTime);
  }

  /// Tính duration giữa 2 DateTime
  static String formatDuration(DateTime? start, DateTime? end) {
    if (start == null || end == null) return '--';

    final duration = end.difference(start);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    }
    return '${seconds}s';
  }
}
