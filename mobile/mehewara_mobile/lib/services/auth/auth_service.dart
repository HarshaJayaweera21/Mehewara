import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
import '../../core/storage/token_storage.dart';
import '../../models/user.dart';

const crewRoles = {
  'CREW_LEADER_DRAINAGE',
  'CREW_LEADER_ROAD',
  'CREW_LEADER_WASTE',
  'CREW_LEADER_ELECTRICAL',
  'CREW_LEADER_ENVIRONMENT',
};

class AuthService {
  final ApiClient _api;

  AuthService({ApiClient? api}) : _api = api ?? ApiClient();

  /// Logs in any user (Resident, Crew Leader, Coordinator) and stores session
  Future<String> login(String email, String password) async {
    final response = await _api.post(
      ApiConstants.login,
      body: {
        'email': email.trim(),
        'password': password,
      },
    );

    if (response is Map<String, dynamic>) {
      final token = response['accessToken']?.toString() ?? '';
      final user = response['user'] as Map<String, dynamic>? ?? {};
      final role = (user['role'] ?? 'RESIDENT').toString();
      final userId = (user['id'] ?? user['userId'] ?? '').toString();
      final userName = (user['name'] ?? user['fullName'] ?? '').toString();
      final userEmail = (user['email'] ?? email).toString();

      await TokenStorage.saveSession(
        token: token,
        userId: userId,
        userName: userName,
        email: userEmail,
        role: role,
      );

      _api.token = token;
      return role;
    }

    throw ApiException.named(
      message: 'Invalid response from authentication server.',
      statusCode: 500,
    );
  }

  /// Registers a new Resident and persists session
  Future<String> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    String? phoneNumber,
  }) async {
    final body = {
      'firstName': firstName.trim(),
      'lastName': lastName.trim(),
      'email': email.trim(),
      'password': password,
      if (phoneNumber != null && phoneNumber.trim().isNotEmpty)
        'phoneNumber': phoneNumber.trim(),
    };

    final response = await _api.post(ApiConstants.register, body: body);

    if (response is Map<String, dynamic>) {
      final token = response['accessToken']?.toString() ?? '';
      final user = response['user'] as Map<String, dynamic>? ?? {};
      final role = (user['role'] ?? 'RESIDENT').toString();
      final userId = (user['id'] ?? user['userId'] ?? '').toString();
      final userName = (user['name'] ?? '$firstName $lastName').toString();
      final userEmail = (user['email'] ?? email).toString();

      await TokenStorage.saveSession(
        token: token,
        userId: userId,
        userName: userName,
        email: userEmail,
        role: role,
      );

      _api.token = token;
      return role;
    }

    throw ApiException.named(
      message: 'Failed to create resident account.',
      statusCode: 500,
    );
  }

  /// Fetches the profile details of the authenticated resident
  Future<ResidentUser> getCurrentUser() async {
    final response = await _api.get('/auth/me');
    if (response is Map<String, dynamic>) {
      return ResidentUser.fromJson(response);
    }
    throw ApiException.named(
      message: 'Failed to load user profile.',
      statusCode: 500,
    );
  }

  /// Updates profile details (name, phone)
  Future<ResidentUser> updateProfile({
    required String firstName,
    required String lastName,
    String? phoneNumber,
  }) async {
    final body = {
      'firstName': firstName.trim(),
      'lastName': lastName.trim(),
      if (phoneNumber != null) 'phoneNumber': phoneNumber.trim(),
    };

    final response = await _api.patch('/auth/profile', body: body);
    if (response is Map<String, dynamic>) {
      return ResidentUser.fromJson(response);
    }
    throw ApiException.named(
      message: 'Failed to update profile.',
      statusCode: 500,
    );
  }

  /// Clears stored user session
  Future<void> logout() async {
    await TokenStorage.clearSession();
    _api.token = null;
  }
}

class CrewSession extends ChangeNotifier {
  final ApiClient api;
  final FlutterSecureStorage storage;
  Map<String, dynamic>? user;
  bool restoring = true;
  String? error;

  CrewSession(this.api, {this.storage = const FlutterSecureStorage()}) {
    api.onUnauthorized = expire;
  }

  Future<void> restore() async {
    restoring = true;
    error = null;
    notifyListeners();
    try {
      api.token = await storage.read(key: 'access_token');
      if (api.token != null) {
        final result = await api.send('/Auth/me');
        _validateRole(result);
        user = result;
      }
    } catch (e) {
      error = e.toString();
      if (e is ApiException && (e.status == 401 || e.code == 'CREW_ONLY')) {
        api.token = null;
        await storage.delete(key: 'access_token');
      }
    } finally {
      restoring = false;
      notifyListeners();
    }
  }

  void _validateRole(Map<String, dynamic> result) {
    if (!crewRoles.contains(result['role'])) {
      throw ApiException(
        403,
        'CREW_ONLY',
        'This app is for crew leaders. Sign in with your crew leader account.',
      );
    }
  }

  Future<void> login(String email, String password) async {
    final result = await api.send(
      '/Auth/login',
      method: 'POST',
      authenticated: false,
      body: {'email': email.trim(), 'password': password},
    );
    final account = result['user'] as Map<String, dynamic>;
    _validateRole(account);
    await storage.write(key: 'access_token', value: result['accessToken']);
    api.token = result['accessToken'];
    user = account;
    error = null;
    notifyListeners();
  }

  void expire() {
    api.token = null;
    user = null;
    error = 'Your session expired. Please sign in again.';
    storage.delete(key: 'access_token');
    notifyListeners();
  }

  Future<void> logout() async {
    api.token = null;
    user = null;
    error = null;
    await storage.delete(key: 'access_token');
    notifyListeners();
  }
}
