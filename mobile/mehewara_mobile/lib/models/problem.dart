class Problem {
  final String id;
  final String title;
  final String? description;
  final String category;
  final double latitude;
  final double longitude;
  final String? address;
  final String? priority;
  final int? priorityScore;
  final String status;
  final int reportCount;
  final List<RelatedReportSummary> relatedReports;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Problem({
    required this.id,
    required this.title,
    this.description,
    required this.category,
    required this.latitude,
    required this.longitude,
    this.address,
    this.priority,
    this.priorityScore,
    required this.status,
    this.reportCount = 1,
    this.relatedReports = const [],
    required this.createdAt,
    this.updatedAt,
  });

  factory Problem.fromJson(Map<String, dynamic> json) {
    final reportsList = <RelatedReportSummary>[];
    if (json.containsKey('relatedReports') && json['relatedReports'] is List) {
      for (final r in json['relatedReports']) {
        if (r is Map<String, dynamic>) {
          reportsList.add(RelatedReportSummary.fromJson(r));
        }
      }
    }

    int count = 1;
    if (reportsList.isNotEmpty) {
      count = reportsList.length;
    } else if (json.containsKey('relatedReportCount')) {
      count = json['relatedReportCount'] as int? ?? 1;
    } else if (json.containsKey('reportCount')) {
      count = json['reportCount'] as int? ?? 1;
    }

    return Problem(
      id: json['id'] ?? json['problemId'] ?? '',
      title: json['title'] ?? '',
      description: json['description'],
      category: (json['category'] ?? 'OTHER').toString().toUpperCase(),
      latitude: (json['latitude'] as num?)?.toDouble() ??
          double.tryParse(json['latitude']?.toString() ?? '') ??
          0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ??
          double.tryParse(json['longitude']?.toString() ?? '') ??
          0.0,
      address: json['address'],
      priority: json['priority']?.toString().toUpperCase(),
      priorityScore: json['priorityScore'] as int?,
      status: (json['status'] ?? 'PENDING').toString().toUpperCase(),
      reportCount: count,
      relatedReports: reportsList,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt']) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'priority': priority,
      'priorityScore': priorityScore,
      'status': status,
      'reportCount': reportCount,
      'relatedReports': relatedReports.map((r) => r.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }
}

class RelatedReportSummary {
  final String reportId;
  final String description;
  final String category;
  final String status;
  final String? address;
  final double latitude;
  final double longitude;
  final DateTime createdAt;

  RelatedReportSummary({
    required this.reportId,
    required this.description,
    required this.category,
    required this.status,
    this.address,
    required this.latitude,
    required this.longitude,
    required this.createdAt,
  });

  factory RelatedReportSummary.fromJson(Map<String, dynamic> json) {
    return RelatedReportSummary(
      reportId: (json['reportId'] ?? json['id'] ?? '').toString(),
      description: json['description'] ?? '',
      category: (json['category'] ?? 'OTHER').toString().toUpperCase(),
      status: (json['status'] ?? 'PENDING').toString().toUpperCase(),
      address: json['address'],
      latitude: (json['latitude'] as num?)?.toDouble() ??
          double.tryParse(json['latitude']?.toString() ?? '') ??
          0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ??
          double.tryParse(json['longitude']?.toString() ?? '') ??
          0.0,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt']) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'reportId': reportId,
      'description': description,
      'category': category,
      'status': status,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
