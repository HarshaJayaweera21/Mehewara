import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/network/api_client.dart';

const crewRoles = {
  'CREW_LEADER_DRAINAGE',
  'CREW_LEADER_ROAD',
  'CREW_LEADER_WASTE',
  'CREW_LEADER_ELECTRICAL',
  'CREW_LEADER_ENVIRONMENT',
};

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
