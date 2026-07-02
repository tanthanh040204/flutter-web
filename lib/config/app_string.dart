// @file       app_string.dart
// @brief      Centralized title / brand strings (bicycle fleet).

/* Imports ------------------------------------------------------------ */
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../providers/language_provider.dart';

/* Typedef / Function types ------------------------------------------- */
// A bilingual piece of text. Resolve with `context.loc(...)`.
typedef AppText = ({String vi, String en});

/* Public classes ----------------------------------------------------- */
class AppStrings {
  AppStrings._();

  // ---- Brand (monolingual literals, kept as before) ----
  static const String brandShort = 'UTE Bike';
  static const String brandManager = 'Bicycle Manager';
  static const String brandName = 'UTE Bicycles';
  static const String brandSystemVi = 'Hệ thống quản lý xe đạp';

  // ---- Bottom-nav labels ----
  static const AppText navControl = (vi: 'Điều khiển', en: 'Controls');
  static const AppText navStats = (vi: 'Thống kê', en: 'Statistics');
  static const AppText navStations = (vi: 'Bản đồ', en: 'Map');
  static const AppText navHistory = (vi: 'Lịch sử', en: 'History');
  static const AppText navNotifications = (
    vi: 'Thông báo',
    en: 'Notifications',
  );
  static const AppText navUsers = (vi: 'Người dùng', en: 'Users');
  static const AppText navMore = (vi: 'Mở rộng', en: 'More');

  // ---- Screen / AppBar titles ----
  static const AppText titleControl = (vi: 'Điều khiển', en: 'Control');
  static const AppText titleStats = (vi: 'Thống kê', en: 'Stats');
  static const AppText titleLocation = (vi: 'Vị trí', en: 'Location');
  static const AppText titleHistory = (
    vi: 'Lịch sử (30 ngày)',
    en: 'History (30 days)',
  );
  static const AppText titleNotifications = (
    vi: 'Thông báo',
    en: 'Notifications',
  );
  static const AppText titleUsers = (
    vi: 'Người dùng đang thuê xe',
    en: 'Active Users',
  );
  static const AppText titleMore = (vi: 'Mở rộng', en: 'More Options');
  static const AppText titleMaintenance = (vi: 'Bảo trì', en: 'Maintenance');

  // ---- Login ----
  static const AppText loginTagline = (
    vi: 'Quản lý xe đạp thông minh, gọn gàng và trực quan.',
    en: 'Smart, clean and visual bicycle management.',
  );

  // ---- Map ----
  static const AppText locationUpdate = (vi: 'Cập nhật', en: 'Update');
  static const AppText showRoute = (vi: 'Hiển thị chuyến đi', en: 'Show route');
  static const AppText hideRoute = (vi: 'Ẩn chuyến đi', en: 'Hide route');
  static const AppText fitMap = (vi: 'Căn chỉnh bản đồ', en: 'Fit map');
  static const AppText trackAll = (vi: 'Theo dõi tất cả', en: 'Track all ');

  // ---- Device errors (device_error_t reported via NOTI_DEVICE_ERROR) ----
  static const AppText deviceErrorSection = (
    vi: 'Lỗi thiết bị',
    en: 'Device Errors',
  );
  static const AppText deviceErrorPrefix = (vi: 'Lỗi', en: 'Error');

  static const Map<int, AppText> deviceErrorLabels = {
    1: (vi: 'khởi tạo thẻ SD', en: 'SD init'),
    2: (vi: 'gắn thẻ SD', en: 'SD mount'),
    3: (vi: 'tạo thư mục trên thẻ SD', en: 'SD mkdir'),
    4: (vi: 'mở tệp trên thẻ SD', en: 'SD open file'),
    5: (vi: 'khởi tạo SIM', en: 'SIM init'),
    6: (vi: 'SIM gửi dữ liệu Firebase', en: 'SIM send data to Firebase'),
    7: (vi: 'SIM nhận dữ liệu Firebase', en: 'SIM get data from Firebase'),
    8: (vi: 'cảm biến pin', en: 'fuel gauge init'),
    9: (vi: 'cảm biến nhiệt độ, độ ẩm', en: 'temperature/humidity sensor init'),
    10: (vi: 'cảm biến chuyển động (IMU)', en: 'IMU init'),
    11: (vi: 'la bàn', en: 'compass init'),
    12: (vi: 'màn hình', en: 'display init'),
    13: (vi: 'GPS', en: 'GPS init'),
  };
}

String deviceErrorNames(BuildContext context, Iterable<int> codes) {
  return codes
      .map((c) => AppStrings.deviceErrorLabels[c])
      .whereType<AppText>()
      .map((t) => context.tr(t.vi, t.en))
      .join('; ');
}

/* Public extensions -------------------------------------------------- */
extension AppStringContext on BuildContext {
  // Resolves an [AppText] to the active language (watches LanguageProvider).
  String loc(AppText text) => watch<LanguageProvider>().tr(text.vi, text.en);
}

extension AppStringLang on LanguageProvider {
  // Resolves an [AppText] using an already-held LanguageProvider.
  String loc(AppText text) => tr(text.vi, text.en);
}

/* End of file -------------------------------------------------------- */
