class WorkOrderModel {
  final String id;
  final String problemId;
  final String title;
  final String problemTitle;
  final String? problemDescription;
  final String? problemCategory;
  final String? problemAddress;
  final double latitude;
  final double longitude;
  final int reportCount;
  final String priority;
  final int priorityScore;
  final String status;
  final String? instructions;
  final DateTime? assignedAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String? completionNotes;
  final DateTime createdAt;

  WorkOrderModel({
    required this.id,
    required this.problemId,
    required this.title,
    required this.problemTitle,
    this.problemDescription,
    this.problemCategory,
    this.problemAddress,
    this.latitude = 0.0,
    this.longitude = 0.0,
    this.reportCount = 0,
    required this.priority,
    this.priorityScore = 0,
    required this.status,
    this.instructions,
    this.assignedAt,
    this.startedAt,
    this.completedAt,
    this.completionNotes,
    required this.createdAt,
  });

  bool get isActive => status == 'ASSIGNED' || status == 'IN_PROGRESS';
  bool get isInProgress => status == 'IN_PROGRESS';
  bool get isQueued => status == 'ASSIGNED';
  bool get isCompleted => status == 'COMPLETED';
  bool get isClosed => status == 'COMPLETED' || status == 'CANCELLED' || status == 'FAILED';
  bool get hasValidCoordinates => latitude != 0.0 && longitude != 0.0;

  int get priorityWeight {
    switch (priority.toUpperCase()) {
      case 'CRITICAL':
        return 4;
      case 'HIGH':
        return 3;
      case 'MEDIUM':
        return 2;
      case 'LOW':
        return 1;
      default:
        return 0;
    }
  }

  factory WorkOrderModel.fromJson(Map<String, dynamic> json) {
    return WorkOrderModel(
      id: json['id'] ?? json['workOrderId'] ?? '',
      problemId: json['problemId'] ?? '',
      title: json['title'] ?? '',
      problemTitle: json['problemTitle'] ?? json['title'] ?? '',
      problemDescription: json['problemDescription'] ?? json['description'],
      problemCategory: json['problemCategory'],
      problemAddress: json['problemAddress'],
      latitude: json['latitude'] is num
          ? (json['latitude'] as num).toDouble()
          : double.tryParse(json['latitude']?.toString() ?? '0') ?? 0.0,
      longitude: json['longitude'] is num
          ? (json['longitude'] as num).toDouble()
          : double.tryParse(json['longitude']?.toString() ?? '0') ?? 0.0,
      reportCount: json['reportCount'] is int
          ? json['reportCount']
          : int.tryParse(json['reportCount']?.toString() ?? '0') ?? 0,
      priority: (json['priority'] ?? 'MEDIUM').toString().toUpperCase(),
      priorityScore: json['priorityScore'] is int
          ? json['priorityScore']
          : int.tryParse(json['priorityScore']?.toString() ?? '0') ?? 0,
      status: (json['status'] ?? 'ASSIGNED').toString().toUpperCase(),
      instructions: json['instructions'],
      assignedAt: json['assignedAt'] != null ? DateTime.tryParse(json['assignedAt']) : null,
      startedAt: json['startedAt'] != null ? DateTime.tryParse(json['startedAt']) : null,
      completedAt: json['completedAt'] != null ? DateTime.tryParse(json['completedAt']) : null,
      completionNotes: json['completionNotes'],
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt']) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

