import 'package:flutter/foundation.dart';

import '../../services/auth/auth_service.dart';

class AuthViewModel extends ChangeNotifier {
  AuthViewModel({AuthService? service}) : _service = service ?? AuthService();

  final AuthService _service;
  bool _isBusy = false;
  String? _error;

  bool get isBusy => _isBusy;
  String? get error => _error;

  Future<String?> signIn(String email, String password) => _run(
        () => _service.login(email, password),
      );

  Future<String?> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    String? phoneNumber,
  }) =>
      _run(() => _service.register(
            firstName: firstName,
            lastName: lastName,
            email: email,
            password: password,
            phoneNumber: phoneNumber,
          ));

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  Future<String?> _run(Future<String> Function() operation) async {
    if (_isBusy) return null;
    _isBusy = true;
    _error = null;
    notifyListeners();
    try {
      return await operation();
    } catch (error) {
      _error = error.toString();
      return null;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }
}
