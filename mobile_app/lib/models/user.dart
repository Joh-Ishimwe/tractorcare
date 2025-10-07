class User {
  final int userId;
  final String username;
  final String email;
  final String fullName;
  final String role;
  final String? coopId;
  
  User({
    required this.userId,
    required this.username,
    required this.email,
    required this.fullName,
    required this.role,
    this.coopId,
  });
  
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      userId: json['user_id'],
      username: json['username'],
      email: json['email'],
      fullName: json['full_name'],
      role: json['role'],
      coopId: json['coop_id'],
    );
  }
}