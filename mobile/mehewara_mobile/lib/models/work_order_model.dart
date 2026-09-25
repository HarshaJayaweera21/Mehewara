class WorkOrderModel {
  final String id;
  final String problemId;
  final String title;
  final String problemTitle;
  final String? problemCategory;
  final String? problemAddress;
  final String priority;
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
    this.problemCategory,
    this.problemAddress,
    required this.priority,
    required this.status,
    this.instructions,
    this.assignedAt,
    this.startedAt,
    this.completedAt,
    this.completionNotes,
    required this.createdAt,
  });

  bool get isActive => status == 'ASSIGNED' || status == 'IN_PROGRESS';
  bool get isCompleted => status == 'COMPLETED';

  factory WorkOrderModel.fromJson(Map<String, dynamic> json) {
    return WorkOrderModel(
      id: json['id'] ?? json['workOrderId'] ?? '',
      problemId: json['problemId'] ?? '',
      title: json['title'] ?? '',
      problemTitle: json['problemTitle'] ?? json['title'] ?? '',
      problemCategory: json['problemCategory'],
      problemAddress: json['problemAddress'],
      priority: (json['priority'] ?? 'MEDIUM').toString().toUpperCase(),
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
