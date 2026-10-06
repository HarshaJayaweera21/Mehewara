import 'dart:convert';

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

  AiTriageInfo? get parsedAiAnalysis {
    final raw = aiAnalysis?.trim();
    if (raw == null || raw.isEmpty) return null;
    return AiTriageInfo.parse(raw);
  }
}

class AiTriageInfo {
  final bool isUncertain;
  final String title;
  final String summary;
  final String? badgeText;
  final String? observedIssue;
  final String? affectedAsset;
  final String? inferredCategory;
  final double? categoryConfidence;
  final String? priority;
  final List<String> hazards;
  final List<String> missingInformation;
  final List<String> evidence;

  const AiTriageInfo({
    required this.isUncertain,
    required this.title,
    required this.summary,
    this.badgeText,
    this.observedIssue,
    this.affectedAsset,
    this.inferredCategory,
    this.categoryConfidence,
    this.priority,
    this.hazards = const [],
    this.missingInformation = const [],
    this.evidence = const [],
  });

  factory AiTriageInfo.parse(String raw) {
    final trimmed = raw.trim();
    if (!trimmed.startsWith('{') && !trimmed.startsWith('[')) {
      return AiTriageInfo(
        isUncertain: false,
        title: 'AI Triage & Assessment',
        summary: trimmed,
        badgeText: 'Assessment',
      );
    }

    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map<String, dynamic>) {
        final structured = (decoded['structured_report'] ??
            decoded['structuredReport'] ??
            decoded['report_analysis'] ??
            decoded['reportAnalysis']) as Map<String, dynamic>?;

        final problem = (decoded['problem_analysis'] ??
            decoded['problemAnalysis']) as Map<String, dynamic>?;

        final priorityMap = (decoded['priority_analysis'] ??
            decoded['priorityAnalysis']) as Map<String, dynamic>?;

        final decision = (problem?['decision'] ?? decoded['decision'])
            ?.toString()
            .toUpperCase();

        final isUncertain = decision == 'UNCERTAIN' ||
            decoded['isUncertain'] == true ||
            decoded['aiUncertaintyReason'] != null ||
            (decoded['status']?.toString().toUpperCase() == 'UNCERTAIN');

        final observed = (structured?['observedIssue'] ??
                structured?['observed_issue'] ??
                decoded['observedIssue'] ??
                decoded['observed_issue'])
            ?.toString();

        final asset = (structured?['affectedAsset'] ??
                structured?['affected_asset'] ??
                decoded['affectedAsset'])
            ?.toString();

        final inferredCat = (structured?['inferredCategory'] ??
                structured?['inferred_category'] ??
                decoded['inferredCategory'])
            ?.toString();

        double? confidence;
        final confRaw = structured?['categoryConfidence'] ??
            structured?['category_confidence'] ??
            decoded['categoryConfidence'];
        if (confRaw is num) {
          confidence = confRaw.toDouble();
        }

        final priority =
            (priorityMap?['priority'] ?? decoded['priority'])?.toString();

        final hazards = <String>[];
        final hazardsRaw = structured?['hazards'] ?? decoded['hazards'];
        if (hazardsRaw is List) {
          for (final h in hazardsRaw) {
            if (h != null && h.toString().trim().isNotEmpty) {
              hazards.add(h.toString().trim());
            }
          }
        }

        final missingInfo = <String>[];
        final missingRaw = structured?['missingInformation'] ??
            structured?['missing_information'] ??
            decoded['missingInformation'];
        if (missingRaw is List) {
          for (final m in missingRaw) {
            if (m != null && m.toString().trim().isNotEmpty) {
              missingInfo.add(m.toString().trim());
            }
          }
        }

        final evidence = <String>[];
        final evidenceRaw = problem?['evidence'] ?? decoded['evidence'];
        if (evidenceRaw is List) {
          for (final e in evidenceRaw) {
            if (e != null && e.toString().trim().isNotEmpty) {
              evidence.add(e.toString().trim());
            }
          }
        }

        String? summaryText;
        if (isUncertain) {
          summaryText = (problem?['summary'] ??
                  decoded['aiUncertaintyReason'] ??
                  decoded['uncertaintyReason'] ??
                  decoded['summary'])
              ?.toString();
          if (summaryText == null || summaryText.trim().isEmpty) {
            summaryText =
                'This report was flagged for manual verification by a municipal coordinator because key details require confirmation before crew dispatch.';
          }
        } else {
          summaryText = (problem?['summary'] ??
                  structured?['observedIssue'] ??
                  decoded['summary'] ??
                  decoded['observedIssue'] ??
                  decoded['analysis'] ??
                  decoded['message'])
              ?.toString();

          if (summaryText == null || summaryText.trim().isEmpty) {
            if (observed != null && observed.trim().isNotEmpty) {
              summaryText = observed;
            } else {
              summaryText =
                  'Report successfully triaged by the municipal AI service and assigned for dispatch preparation.';
            }
          }
        }

        final badge = isUncertain
            ? 'Coordinator Review'
            : (confidence != null
                ? '${(confidence * 100).round()}% Match'
                : 'Automated');

        return AiTriageInfo(
          isUncertain: isUncertain,
          title: isUncertain
              ? 'Flagged for Staff Verification'
              : 'AI Triage & Assessment',
          summary: summaryText,
          badgeText: badge,
          observedIssue: observed != summaryText ? observed : null,
          affectedAsset: asset,
          inferredCategory: inferredCat,
          categoryConfidence: confidence,
          priority: priority,
          hazards: hazards,
          missingInformation: missingInfo,
          evidence: evidence,
        );
      }
    } catch (_) {
      // In case json decoding throws
    }

    // Safety fallback: NEVER dump raw JSON
    if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
      return const AiTriageInfo(
        isUncertain: false,
        title: 'AI Triage & Assessment',
        summary:
            'Report is currently undergoing automated municipal triage and dispatch review.',
        badgeText: 'In Progress',
      );
    }

    return AiTriageInfo(
      isUncertain: false,
      title: 'AI Triage & Assessment',
      summary: trimmed,
      badgeText: 'Assessment',
    );
  }
}

