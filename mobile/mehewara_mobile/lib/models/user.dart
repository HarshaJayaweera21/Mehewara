class ResidentUser {
  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String? phoneNumber;
  final String? role;
  final String? profilePhotoUrl;

  String get name {
    final fullName = '$firstName $lastName'.trim();
    return fullName.isEmpty ? 'Resident' : fullName;
  }

  const ResidentUser({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.phoneNumber,
    this.role,
    this.profilePhotoUrl,
  });

  factory ResidentUser.fromJson(Map<String, dynamic> json) {
    String first = (json['firstName'] ?? '').toString();
    String last = (json['lastName'] ?? '').toString();

    if (first.isEmpty && last.isEmpty) {
      final nameStr = (json['name'] ?? json['fullName'] ?? '').toString().trim();
      if (nameStr.isNotEmpty) {
        final parts = nameStr.split(RegExp(r'\s+'));
        last = parts.length > 1 ? parts.removeLast() : '';
        first = parts.join(' ');
      }
    }

    return ResidentUser(
      id: (json['id'] ?? json['userId'] ?? '').toString(),
      firstName: first,
      lastName: last,
      email: (json['email'] ?? '').toString(),
      phoneNumber: json['phoneNumber'] as String?,
      role: json['role'] as String?,
      profilePhotoUrl: (json['profilePhotoUrl'] ?? json['profileImageUrl']) as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
        'phoneNumber': phoneNumber,
        'role': role,
        'profilePhotoUrl': profilePhotoUrl,
      };
}
