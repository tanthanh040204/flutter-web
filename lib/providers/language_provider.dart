// @file       language_provider.dart
// @brief      Simple app language state for Vietnamese / English UI.

/* Imports ------------------------------------------------------------ */
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/* Public enums ------------------------------------------------------- */
enum AppLanguage { vi, en }

/* Public classes ----------------------------------------------------- */
class LanguageProvider extends ChangeNotifier {
  AppLanguage _language = AppLanguage.vi;

  AppLanguage get language => _language;
  bool get isVietnamese => _language == AppLanguage.vi;
  bool get isEnglish => _language == AppLanguage.en;
  String get code => isVietnamese ? 'vi' : 'en';
  String get displayName => isVietnamese ? 'Tiếng Việt' : 'English';

  String tr(String vi, String en) => isVietnamese ? vi : en;

  void setLanguage(AppLanguage value) {
    if (_language == value) return;
    _language = value;
    notifyListeners();
  }

  void toggle() {
    setLanguage(isVietnamese ? AppLanguage.en : AppLanguage.vi);
  }
}

/* Public extensions -------------------------------------------------- */
extension LanguageBuildContext on BuildContext {
  String tr(String vi, String en) => watch<LanguageProvider>().tr(vi, en);
  String trRead(String vi, String en) => read<LanguageProvider>().tr(vi, en);
}

/* End of file -------------------------------------------------------- */
