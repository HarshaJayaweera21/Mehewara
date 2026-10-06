import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../../core/constants/api_constants.dart';
import '../../core/storage/token_storage.dart';
import '../../models/problem.dart';

class ProblemService {
  final String baseUrl;

  ProblemService({String? baseUrl})
      : baseUrl = baseUrl ??
            (dotenv.isInitialized &&
                    dotenv.env['API_BASE_URL'] != null &&
                    dotenv.env['API_BASE_URL']!.isNotEmpty
                ? dotenv.env['API_BASE_URL']!
                : ApiConstants.baseUrl);

  /// Fetch problems from backend, falling back to realistic initial dataset
  Future<List<Problem>> getProblems({
    String? category,
    String? status,
    String? search,
  }) async {
    try {
      final cleanBase = baseUrl.replaceFirst(RegExp(r'/$'), '');
      final queryParams = <String, String>{};
      if (category != null && category != 'ALL') {
        queryParams['category'] = category;
      }
      if (status != null && status != 'ALL') {
        queryParams['status'] = status;
      }
      if (search != null && search.trim().isNotEmpty) {
        queryParams['search'] = search.trim();
      }

      final uri = Uri.parse('$cleanBase/problems').replace(
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      final token = await TokenStorage.getToken();
      final headers = <String, String>{
        'Content-Type': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

      final response = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List items = data is Map && data.containsKey('items')
            ? data['items']
            : (data is List ? data : []);

        if (items.isNotEmpty) {
          return items.map((j) => Problem.fromJson(j)).toList();
        }
      }
    } catch (_) {
      // Backend not running or timeout; return curated initial problems matching Stitch UI
    }

    return _getInitialSeededProblems(category: category, search: search);
  }

  /// Fetch a single problem with full details and related reports
  Future<Problem> getProblemById(String id) async {
    try {
      final cleanBase = baseUrl.replaceFirst(RegExp(r'/$'), '');
      final uri = Uri.parse('$cleanBase/problems/$id');
      final token = await TokenStorage.getToken();
      final headers = <String, String>{
        'Content-Type': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };
      final response = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map<String, dynamic>) {
          return Problem.fromJson(data);
        }
      }
    } catch (_) {
      // Fallback
    }

    final seededList = _getInitialSeededProblems();
    return seededList.firstWhere(
      (p) => p.id == id,
      orElse: () => seededList.first,
    );
  }

  /// Initial problems matching Stitch Community Incidents map
  List<Problem> _getInitialSeededProblems({String? category, String? search}) {
    final list = [
      Problem(
        id: 'b0000000-0000-0000-0000-000000000001',
        title: 'Road Flooding near Central College',
        description:
            'Heavy stormwater accumulation covering roadway, blocking vehicular traffic near college gate. Subsurface culvert clogged with seasonal debris.',
        category: 'DRAINAGE',
        latitude: 6.9271,
        longitude: 79.8612,
        address: 'Main Galle Road, Ward 4 • Colombo Central',
        priority: 'HIGH',
        priorityScore: 78,
        status: 'PROCESSING',
        reportCount: 4,
        relatedReports: [
          RelatedReportSummary(
            reportId: 'd0000000-0000-0000-0000-000000001047',
            description: 'Heavy water accumulation on street',
            category: 'DRAINAGE',
            status: 'PENDING',
            address: 'Main Galle Road, Ward 4',
            latitude: 6.9271,
            longitude: 79.8612,
            createdAt: DateTime.now().subtract(const Duration(hours: 18)),
          ),
          RelatedReportSummary(
            reportId: 'd0000000-0000-0000-0000-000000001039',
            description: 'Drain overflowing near college gate',
            category: 'DRAINAGE',
            status: 'PENDING',
            address: 'Central College Gate, Ward 4',
            latitude: 6.9272,
            longitude: 79.8613,
            createdAt: DateTime.now().subtract(const Duration(hours: 20)),
          ),
          RelatedReportSummary(
            reportId: 'd0000000-0000-0000-0000-000000001021',
            description: 'Water blocking pedestrian sidewalk',
            category: 'DRAINAGE',
            status: 'PENDING',
            address: 'Ward 4 Walkway',
            latitude: 6.9270,
            longitude: 79.8611,
            createdAt: DateTime.now().subtract(const Duration(days: 1)),
          ),
          RelatedReportSummary(
            reportId: 'd0000000-0000-0000-0000-000000001015',
            description: 'Subsurface culvert clogged with seasonal debris',
            category: 'DRAINAGE',
            status: 'PENDING',
            address: 'Ward 4 North Corner',
            latitude: 6.9273,
            longitude: 79.8614,
            createdAt: DateTime.now().subtract(const Duration(days: 1, hours: 4)),
          ),
        ],
        createdAt: DateTime.now().subtract(const Duration(hours: 18)),
      ),
      Problem(
        id: 'b0000000-0000-0000-0000-000000000002',
        title: 'Deep Pothole & Road Surface Hazard',
        description:
            'Severe asphalt deformation causing vehicle damage and traffic bottleneck during peak hours.',
        category: 'ROAD',
        latitude: 6.9295,
        longitude: 79.8632,
        address: 'Baseline Corridor, Ward 4',
        priority: 'HIGH',
        priorityScore: 70,
        status: 'IDENTIFIED',
        reportCount: 2,
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
      Problem(
        id: 'b0000000-0000-0000-0000-000000000003',
        title: 'Commercial Waste Accumulation',
        description:
            'Overflowing municipal collection bins on public walkway attracting pests.',
        category: 'WASTE',
        latitude: 6.9265,
        longitude: 79.8638,
        address: 'Ward 04 Greenway, Colombo',
        priority: 'MEDIUM',
        priorityScore: 50,
        status: 'IDENTIFIED',
        reportCount: 3,
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
      Problem(
        id: 'b0000000-0000-0000-0000-000000000004',
        title: 'Damaged Streetlight Pole & Wiring',
        description:
            'Damaged lamppost casing exposing active electrical cables near pedestrian sidewalk.',
        category: 'ELECTRICAL',
        latitude: 6.9248,
        longitude: 79.8596,
        address: 'Near Substation 9, Colombo',
        priority: 'CRITICAL',
        priorityScore: 88,
        status: 'IDENTIFIED',
        reportCount: 1,
        createdAt: DateTime.now().subtract(const Duration(hours: 6)),
      ),
    ];

    return list.where((p) {
      if (category != null && category != 'ALL' && p.category != category) {
        return false;
      }
      if (search != null && search.trim().isNotEmpty) {
        final query = search.trim().toLowerCase();
        final matchesTitle = p.title.toLowerCase().contains(query);
        final matchesAddress = p.address?.toLowerCase().contains(query) ?? false;
        if (!matchesTitle && !matchesAddress) return false;
      }
      return true;
    }).toList();
  }
}
