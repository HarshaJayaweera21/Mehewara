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

  /// Start working on an assigned work order (transitions ASSIGNED -> IN_PROGRESS)
  Future<WorkOrderModel> startWorkOrder(String workOrderId) async {
    final response = await _apiClient.post('/work-orders/$workOrderId/start');
    if (response is Map<String, dynamic>) {
      return WorkOrderModel.fromJson(response);
    }
    throw ApiException(
      message: 'Invalid response from starting work order',
      statusCode: 500,
    );
  }

  /// Complete an in-progress work order with mandatory remediation notes
  Future<WorkOrderModel> completeWorkOrder(String workOrderId, String completionNotes) async {
    final response = await _apiClient.post(
      '/work-orders/$workOrderId/complete',
      body: {
        'completionNotes': completionNotes.trim(),
      },
    );
    if (response is Map<String, dynamic>) {
      return WorkOrderModel.fromJson(response);
    }
    throw ApiException(
      message: 'Invalid response from completing work order',
      statusCode: 500,
    );
  }

  /// Report an impediment, blocker, or cancellation on a work order
  Future<WorkOrderModel> reportWorkOrderIssue(String workOrderId, String reason, {String action = 'FAIL'}) async {
    final response = await _apiClient.post(
      '/work-orders/$workOrderId/report-issue',
      body: {
        'reason': reason.trim(),
        'action': action,
      },
    );
    if (response is Map<String, dynamic>) {
      return WorkOrderModel.fromJson(response);
    }
    throw ApiException(
      message: 'Invalid response from reporting work order issue',
      statusCode: 500,
    );
  }

  /// Fetch full problem details including linked resident reports
  Future<Map<String, dynamic>> getProblemDetails(String problemId) async {
    final response = await _apiClient.get('/problems/$problemId');
    if (response is Map<String, dynamic>) {
      return response;
    }
    throw ApiException(
      message: 'Invalid response from fetching problem details',
      statusCode: 500,
    );
  }
}

