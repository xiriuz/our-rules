// lib/models/family_member.dart
class FamilyMember {
  final String uid;
  final String name;
  final String role; // 'parent' or 'child'
  final int totalScore;
  final String? email;

  FamilyMember({
    required this.uid,
    required this.name,
    required this.role,
    this.totalScore = 0,
    this.email,
  });

  bool get isParent => role == 'parent';

  factory FamilyMember.fromMap(Map<String, dynamic> map, String uid) {
    return FamilyMember(
      uid: uid,
      name: map['name'] ?? '',
      role: map['role'] ?? 'child',
      totalScore: map['totalScore'] ?? 0,
      email: map['email'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'role': role,
      'totalScore': totalScore,
      'email': email,
    };
  }

  FamilyMember copyWith({int? totalScore}) {
    return FamilyMember(
      uid: uid,
      name: name,
      role: role,
      totalScore: totalScore ?? this.totalScore,
      email: email,
    );
  }
}
