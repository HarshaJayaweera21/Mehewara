class CrewModel {
  final String id;
  final String name;
  final String crewType;
  final String status;
  final String? crewLeaderUserId;
  final String? crewLeaderName;
  final String? description;
  final String? contactNumber;
  final String? activeWorkOrderId;

  CrewModel({
    required this.id,
    required this.name,
    required this.crewType,
    required this.status,
    this.crewLeaderUserId,
    this.crewLeaderName,
    this.description,
    this.contactNumber,
    this.activeWorkOrderId,
  });

  bool get isAvailable => status.toUpperCase() == 'AVAILABLE';
  bool get isBusy => status.toUpperCase() == 'BUSY';
  bool get isUnavailable => status.toUpperCase() == 'UNAVAILABLE';
  bool get canToggleStatus => !isBusy && (activeWorkOrderId == null || activeWorkOrderId!.isEmpty);

  factory CrewModel.fromJson(Map<String, dynamic> json) {
    return CrewModel(
      id: json['id'] ?? json['crewId'] ?? '',
      name: json['name'] ?? json['crewName'] ?? '',
      crewType: (json['crewType'] ?? 'GENERAL').toString().toUpperCase(),
      status: (json['status'] ?? 'AVAILABLE').toString().toUpperCase(),
      crewLeaderUserId: json['crewLeaderUserId'],
      crewLeaderName: json['crewLeaderName'],
      description: json['description'],
      contactNumber: json['contactNumber'],
      activeWorkOrderId: json['activeWorkOrderId'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'crewType': crewType,
      'status': status,
      'crewLeaderUserId': crewLeaderUserId,
      'crewLeaderName': crewLeaderName,
      'description': description,
      'contactNumber': contactNumber,
      'activeWorkOrderId': activeWorkOrderId,
    };
  }

  CrewModel copyWith({
    String? status,
    String? activeWorkOrderId,
  }) {
    return CrewModel(
      id: id,
      name: name,
      crewType: crewType,
      status: status ?? this.status,
      crewLeaderUserId: crewLeaderUserId,
      crewLeaderName: crewLeaderName,
      description: description,
      contactNumber: contactNumber,
      activeWorkOrderId: activeWorkOrderId ?? this.activeWorkOrderId,
    );
  }
}
