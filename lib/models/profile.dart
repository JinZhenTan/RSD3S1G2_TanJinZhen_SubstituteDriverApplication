import 'user_role.dart';

class Profile {
  final String id;
  final String name;
  final UserRole role;
  final String? phone;
  final String? avatarUrl;
  final double rating;
  final double basicSalary;
  final double earningsDeductionRate;

  Profile({
    required this.id,
    required this.name,
    this.role = UserRole.user,
    this.phone,
    this.avatarUrl,
    this.rating = 5.0,
    this.basicSalary = 800.0,
    this.earningsDeductionRate = 0.10,
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'].toString(),
      name: (json['name'] ?? 'Guest') as String,
      role: userRoleFromName(json['role'] as String?),
      phone: json['phone'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      rating: (json['rating'] as num?)?.toDouble() ?? 5.0,
      basicSalary: (json['basic_salary'] as num?)?.toDouble() ?? 800.0,
      earningsDeductionRate:
          (json['earnings_deduction_rate'] as num?)?.toDouble() ?? 0.10,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'role': userRoleToName(role),
      'phone': phone,
      'avatar_url': avatarUrl,
      'rating': rating,
      'basic_salary': basicSalary,
      'earnings_deduction_rate': earningsDeductionRate,
    };
  }

  String get initial => name.isNotEmpty ? name[0].toUpperCase() : 'G';
}
