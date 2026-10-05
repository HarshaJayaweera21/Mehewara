class ReportPhoto {
  final String id;
  final String url;
  final String? fileName;

  const ReportPhoto({required this.id, required this.url, this.fileName});

  factory ReportPhoto.fromJson(Map<String, dynamic> json) => ReportPhoto(
        id: (json['photoId'] ?? json['id'] ?? '').toString(),
        url: (json['photoUrl'] ?? json['url'] ?? '').toString(),
        fileName: json['fileName'] as String?,
      );
}

class ResidentReport {
  final String id;
  final String description;
  final String? title;
  final String category;
  final double latitude;
  final double longitude;
  final String? address;
  final String status;
  final DateTime createdAt;
  final List<ReportPhoto> photos;
  final String? aiAnalysis;
  final int linkedProblemCount;

  const ResidentReport({
    required this.id,
    required this.description,
    this.title,
    required this.category,
    required this.latitude,
    required this.longitude,
    required this.status,
    required this.createdAt,
    this.address,
    this.photos = const [],
    this.aiAnalysis,
    this.linkedProblemCount = 0,
  });

  factory ResidentReport.fromJson(Map<String, dynamic> json) {
    final rawPhotos = json['photos'] as List<dynamic>? ?? const [];
    return ResidentReport(
      id: (json['id'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      title: json['title'] as String?,
      category: (json['category'] ?? '').toString(),
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      address: json['address'] as String?,
      status: (json['status'] ?? 'PENDING').toString(),
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()) ?? DateTime.now(),
      photos: rawPhotos.whereType<Map<String, dynamic>>().map(ReportPhoto.fromJson).toList()
        ..insertAll(0, _summaryPhoto(json)),
      aiAnalysis: json['aiAnalysis'] as String?,
      linkedProblemCount: (json['linkedProblemCount'] as num?)?.toInt() ??
          ((json['linkedProblems'] as List<dynamic>?)?.length ?? 0),
    );
  }

  static List<ReportPhoto> _summaryPhoto(Map<String, dynamic> json) {
    final url = (json['firstPhotoUrl'] ?? '').toString();
    return url.isEmpty ? const [] : [ReportPhoto(id: '', url: url)];
  }

  String get displayTitle {
    final explicitTitle = title?.trim();
    if (explicitTitle != null && explicitTitle.isNotEmpty) return explicitTitle;
    final firstLine = description.split('\n').first.trim();
    if (firstLine.isEmpty) return 'Community issue';
    return firstLine.length > 90 ? '${firstLine.substring(0, 87)}…' : firstLine;
  }
}
