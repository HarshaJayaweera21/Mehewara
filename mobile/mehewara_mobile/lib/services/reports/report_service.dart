import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
import '../../core/storage/token_storage.dart';
import '../../models/report_model.dart';

class ReportService {
  final ApiClient _api;

  ReportService({ApiClient? api}) : _api = api ?? ApiClient();

  /// Uploads a photo to Cloudinary via backend multipart endpoint
  Future<ReportPhoto> uploadPhoto(String filePath) async {
    final uri = Uri.parse('${_api.baseUrl.replaceFirst(RegExp(r'/$'), '')}${ApiConstants.reports}/photos');
    final request = http.MultipartRequest('POST', uri);

    final token = await TokenStorage.getToken();
    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    request.files.add(await http.MultipartFile.fromPath('file', filePath));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final json = jsonDecode(response.body);
      if (json is Map<String, dynamic>) {
        return ReportPhoto.fromJson(json);
      }
    }

    throw ApiException.named(
      message: 'Failed to upload photo (Status: ${response.statusCode}).',
      statusCode: response.statusCode,
    );
  }

  /// Submits a new municipal incident report
  Future<ResidentReport> createReport({
    required String description,
    required String category,
    required double latitude,
    required double longitude,
    String? address,
    List<ReportPhoto> photos = const [],
  }) async {
    final body = {
      'description': description.trim(),
      'category': category,
      'latitude': latitude,
      'longitude': longitude,
      if (address != null && address.trim().isNotEmpty) 'address': address.trim(),
      if (photos.isNotEmpty)
        'photos': photos
            .map((p) => {
                  'photoUrl': p.url,
                  'fileName': p.fileName,
                  'mimeType': null,
                })
            .toList(),
    };

    final response = await _api.post(ApiConstants.reports, body: body);
    if (response is Map<String, dynamic>) {
      return ResidentReport.fromJson(response);
    }
    throw ApiException.named(
      message: 'Report submission returned an invalid response.',
      statusCode: 500,
    );
  }

  /// Fetches reports submitted by the logged-in resident
  Future<List<ResidentReport>> getMyReports({
    int page = 1,
    int pageSize = 100,
    String? status,
  }) async {
    final queryParams = {
      'page': page.toString(),
      'pageSize': pageSize.toString(),
      if (status != null && status.isNotEmpty && status != 'All') 'status': status,
    };

    final response = await _api.get(
      ApiConstants.residentReports,
      queryParams: queryParams,
    );

    if (response is Map<String, dynamic>) {
      final items = response['items'] as List<dynamic>? ?? const [];
      return items.whereType<Map<String, dynamic>>().map(ResidentReport.fromJson).toList();
    }
    return const [];
  }

  /// Fetches a specific report by UUID
  Future<ResidentReport> getReport(String id) async {
    final response = await _api.get('${ApiConstants.reports}/$id');
    if (response is Map<String, dynamic>) {
      return ResidentReport.fromJson(response);
    }
    throw ApiException.named(
      message: 'Report details returned an invalid response.',
      statusCode: 500,
    );
  }
}
