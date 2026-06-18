// @file       auth_provider.dart
// @brief      State provider for Auth.

/* Imports ------------------------------------------------------------ */
import 'package:flutter/foundation.dart';
import '../services/firebase_repo.dart';

/* Public classes ----------------------------------------------------- */
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
      _errorMessage = 'Please enter both employee code and password.';
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
        _errorMessage = 'Invalid employee code or password.';
        return false;
      }

      _employeeCode = code;
      _isLoggedIn = true;

      await FirebaseRepo.instance.addLoginNotification(code);
      return true;
    } catch (e) {
      _errorMessage = 'Login failed: $e';
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
      _errorMessage = 'You are not logged in.';
      notifyListeners();
      return false;
    }

    if (currentPassword.trim().isEmpty ||
        newPassword.trim().isEmpty ||
        confirmPassword.trim().isEmpty) {
      _errorMessage = 'Please fill in all fields to change password.';
      notifyListeners();
      return false;
    }

    if (newPassword.trim().length < 4) {
      _errorMessage = 'New password must be at least 4 characters long.';
      notifyListeners();
      return false;
    }

    if (newPassword.trim() != confirmPassword.trim()) {
      _errorMessage = 'New password and confirm password do not match.';
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
        _errorMessage = 'Current password is incorrect.';
        return false;
      }

      return true;
    } catch (e) {
      _errorMessage = 'Failed to change password: $e';
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

/* End of file -------------------------------------------------------- */
