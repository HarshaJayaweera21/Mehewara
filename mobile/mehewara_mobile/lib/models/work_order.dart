class WorkOrderActivity {
  final String id, action, actorUserId;
  final String? note;
  final DateTime createdAt;
  WorkOrderActivity.fromJson(Map<String, dynamic> json)
    : id = json['id'],
      action = json['action'],
      actorUserId = json['actorUserId'],
      note = json['note'],
      createdAt = DateTime.parse(json['createdAt']);
}

class WorkOrder {
  final String id,
      problemId,
      crewId,
      crewName,
      problemTitle,
      title,
      priority,
      status;
  final String? recommendationId, instructions, address, completionNotes;
  final double latitude, longitude;
  final DateTime? assignedAt, startedAt, completedAt;
  final DateTime createdAt, updatedAt;
  final List<WorkOrderActivity> history;
  WorkOrder.fromJson(Map<String, dynamic> json)
    : id = json['id'],
      problemId = json['problemId'],
      crewId = json['crewId'],
      crewName = json['crewName'],
      problemTitle = json['problemTitle'],
      title = json['title'],
      priority = json['priority'],
      status = json['status'],
      recommendationId = json['recommendationId'],
      instructions = json['instructions'],
      address = json['address'],
      completionNotes = json['completionNotes'],
      latitude = (json['latitude'] as num).toDouble(),
      longitude = (json['longitude'] as num).toDouble(),
      assignedAt = _date(json['assignedAt']),
      startedAt = _date(json['startedAt']),
      completedAt = _date(json['completedAt']),
      createdAt = DateTime.parse(json['createdAt']),
      updatedAt = DateTime.parse(json['updatedAt']),
      history = (json['history'] as List? ?? [])
          .map((a) => WorkOrderActivity.fromJson(a))
          .toList();
  static DateTime? _date(String? value) =>
      value == null ? null : DateTime.parse(value);
}

class WorkOrderPage {
  final List<WorkOrder> items;
  final int page, pageSize, totalItems, totalPages;
  WorkOrderPage.fromJson(Map<String, dynamic> json)
    : items = (json['items'] as List)
          .map((item) => WorkOrder.fromJson(item))
          .toList(),
      page = json['page'],
      pageSize = json['pageSize'],
      totalItems = json['totalItems'],
      totalPages = json['totalPages'];
}
