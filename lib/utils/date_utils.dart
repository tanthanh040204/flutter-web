// @file       date_utils.dart
// @brief      Utility helpers for Date / Time formatting. Single source of
//             truth — feature code should call these instead of rolling its
//             own padLeft/string-interpolation helpers.

/* Imports ------------------------------------------------------------ */
import 'package:intl/intl.dart';

/* Public classes ----------------------------------------------------- */
class AppDateUtils {
  AppDateUtils._();

  static final DateFormat _dateTimeFormat = DateFormat('dd/MM/yyyy HH:mm:ss');
  static final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');
  static final DateFormat _timeFormat = DateFormat('HH:mm:ss');
  // Compact human label, e.g. "20:35 - 05/05/2026" — used in list rows.
  static final DateFormat _shortDateTimeFormat = DateFormat('HH:mm - dd/MM/yyyy');
  // Wall-clock time without seconds, e.g. "20:35".
  static final DateFormat _shortTimeFormat = DateFormat('HH:mm');

  // Format DateTime → "dd/MM/yyyy HH:mm:ss" (full).
  static String formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return '--';
    return _dateTimeFormat.format(dateTime);
  }

  // Format DateTime → "HH:mm - dd/MM/yyyy" (compact label for list rows).
  static String formatShortDateTime(DateTime? dateTime) {
    if (dateTime == null) return '--';
    return _shortDateTimeFormat.format(dateTime);
  }

  // Format Date → "dd/MM/yyyy".
  static String formatDate(DateTime? dateTime) {
    if (dateTime == null) return '--';
    return _dateFormat.format(dateTime);
  }

  // Format Time → "HH:mm:ss".
  static String formatTime(DateTime? dateTime) {
    if (dateTime == null) return '--';
    return _timeFormat.format(dateTime);
  }

  // Format Time → "HH:mm" (no seconds).
  static String formatShortTime(DateTime? dateTime) {
    if (dateTime == null) return '--';
    return _shortTimeFormat.format(dateTime);
  }

  // Format duration between two timestamps as "Hh Mm Ss" / "Mm Ss" / "Ss".
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

/* End of file -------------------------------------------------------- */
