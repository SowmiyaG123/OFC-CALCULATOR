// models/user.dart

class User {
  final String? id;
  final String email;
  final String name;
  final String phone;
  final String mobileNumber;
  final String networkName;
  final String role; // 'admin', 'staff', 'user'
  final DateTime? createdAt;

  const User({
    this.id,
    required this.email,
    required this.name,
    required this.phone,
    this.mobileNumber = '',
    this.networkName = '',
    this.role = 'user',
    this.createdAt,
  });

  /// Convert User object → JSON (for Supabase DB insert/update)
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'email': email.trim(),
      'name': name.trim(),
      'phone': phone.trim(),
      'mobile_number': mobileNumber.trim(),
      'network_name': networkName.trim(),
      'role': role,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }

  /// Create User object from Supabase DB row or metadata
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id']?.toString(),
      email: json['email']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      mobileNumber: json['mobile_number']?.toString() ?? '',
      networkName: json['network_name']?.toString() ?? '',
      role: json['role']?.toString() ?? 'user',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  /// Create User from Supabase Auth metadata
  factory User.fromAuth({
    required String email,
    required Map<String, dynamic>? metadata,
  }) {
    return User(
      email: email,
      name: metadata?['name']?.toString() ?? 'User',
      phone: metadata?['phone']?.toString() ?? '',
      mobileNumber: metadata?['mobile_number']?.toString() ?? '',
      networkName: metadata?['network_name']?.toString() ?? '',
      role: metadata?['role']?.toString() ?? 'user',
    );
  }

  bool get isAdmin => role == 'admin';
  bool get isStaff => role == 'staff';
  bool get isUser => role == 'user';

  @override
  String toString() {
    return 'User(id: $id, name: $name, email: $email, role: $role)';
  }
}
