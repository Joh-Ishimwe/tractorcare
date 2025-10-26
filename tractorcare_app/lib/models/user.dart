// lib/models/user.dart

class User {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String role;
  final DateTime? createdAt;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    // backend may return full_name instead of name
    final fullName = (json['name'] ?? json['full_name'] ?? '') as String;
    return User(
      id: json['id'] ?? json['_id'] ?? '',
      name: fullName,
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      role: json['role'] ?? 'farmer',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'role': role,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }

  String get displayRole {
    switch (role) {
      case 'farmer':
        return 'Farmer';
      case 'mechanic':
        return 'Mechanic';
      case 'cooperative_manager':
        return 'Cooperative Manager';
      default:
        return role;
    }
  }
}
