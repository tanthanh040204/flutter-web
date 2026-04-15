import 'package:flutter/foundation.dart';

import '../services/firebase_repo.dart';

class AuthProvider extends ChangeNotifier {
  bool _isLoggedIn = false;
  bool _isLoading = false;
  String? _employeeCode;
  String? _errorMessage;

  bool get isLoggedIn => _isLoggedIn;
  bool get isLoading => _isLoading;
  String? get employeeCode => _employeeCode;
  String? get errorMessage => _errorMessage;

  Future<bool> login({
    required String employeeCode,
    required String password,
  }) async {
    final code = employeeCode.trim();
    final pass = password.trim();

    if (code.isEmpty || pass.isEmpty) {
      _errorMessage = 'Vui lòng nhập đầy đủ mã nhân viên và mật khẩu.';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final ok = await FirebaseRepo.instance.verifyEmployeeLogin(
        employeeCode: code,
        password: pass,
      );

      if (!ok) {
        _errorMessage = 'Mã nhân viên hoặc mật khẩu không đúng.';
        return false;
      }

      _employeeCode = code;
      _isLoggedIn = true;

      await FirebaseRepo.instance.addLoginNotification(code);
      return true;
    } catch (e) {
      _errorMessage = 'Đăng nhập thất bại: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    final code = _employeeCode;
    if (code == null || !_isLoggedIn) {
      _errorMessage = 'Bạn chưa đăng nhập.';
      notifyListeners();
      return false;
    }

    if (currentPassword.trim().isEmpty ||
        newPassword.trim().isEmpty ||
        confirmPassword.trim().isEmpty) {
      _errorMessage = 'Vui lòng nhập đầy đủ thông tin đổi mật khẩu.';
      notifyListeners();
      return false;
    }

    if (newPassword.trim().length < 4) {
      _errorMessage = 'Mật khẩu mới phải có ít nhất 4 ký tự.';
      notifyListeners();
      return false;
    }

    if (newPassword.trim() != confirmPassword.trim()) {
      _errorMessage = 'Mật khẩu mới và xác nhận mật khẩu chưa khớp.';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final ok = await FirebaseRepo.instance.changeEmployeePassword(
        employeeCode: code,
        currentPassword: currentPassword.trim(),
        newPassword: newPassword.trim(),
      );

      if (!ok) {
        _errorMessage = 'Mật khẩu hiện tại không đúng.';
        return false;
      }

      return true;
    } catch (e) {
      _errorMessage = 'Đổi mật khẩu thất bại: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void logout() {
    _isLoggedIn = false;
    _employeeCode = null;
    _errorMessage = null;
    notifyListeners();
  }

  void clearError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    notifyListeners();
  }
}
