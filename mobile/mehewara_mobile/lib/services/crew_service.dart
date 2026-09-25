import '../core/constants/api_constants.dart';
import '../core/network/api_client.dart';
import '../core/storage/token_storage.dart';
import '../models/crew_model.dart';
import '../models/work_order_model.dart';

class CrewService {
  final ApiClient _apiClient;

  CrewService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  /// Authenticate user and persist session token
  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await _apiClient.post(
      ApiConstants.login,
      body: {
        'email': email.trim(),
        'password': password,
      },
    );

    if (response is Map<String, dynamic>) {
      final token = response['accessToken'] as String? ?? '';
      final user = response['user'] as Map<String, dynamic>? ?? {};

      await TokenStorage.saveSession(
        token: token,
        userId: user['id'] ?? '',
        userName: user['name'] ?? '${user['firstName']} ${user['lastName']}'.trim(),
        email: user['email'] ?? email,
        role: user['role'] ?? '',
      );

      return response;
    }

    throw ApiException(
      message: 'Unexpected login response from server',
      statusCode: 500,
    );
  }

  /// Get authenticated crew leader's crew profile
  Future<CrewModel> getCrewProfile() async {
    final response = await _apiClient.get(ApiConstants.crewProfile);
    if (response is Map<String, dynamic>) {
      return CrewModel.fromJson(response);
    }
    throw ApiException(
      message: 'Invalid crew profile response payload',
      statusCode: 500,
    );
  }

  /// Toggle or update crew availability status (AVAILABLE or UNAVAILABLE)
  Future<CrewModel> updateCrewStatus(String newStatus) async {
    final response = await _apiClient.patch(
      ApiConstants.crewStatus,
      body: {
        'status': newStatus.toUpperCase(),
      },
    );

    if (response is Map<String, dynamic>) {
      return CrewModel.fromJson(response);
    }
    throw ApiException(
      message: 'Invalid crew status response payload',
      statusCode: 500,
    );
  }

  /// Get active and past work orders assigned to this crew
  Future<List<WorkOrderModel>> getCrewWorkOrders() async {
    final response = await _apiClient.get(ApiConstants.crewWorkOrders);
    if (response is List) {
      return response
          .map((item) => WorkOrderModel.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    return [];
  }
}
