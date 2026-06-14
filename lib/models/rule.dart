// lib/models/rule.dart
class Rule {
  final String id;
  final String title;
  final String description;
  final int points;
  final String createdBy;
  final DateTime createdAt;
  final bool isActive;

  Rule({
    required this.id,
    required this.title,
    required this.description,
    required this.points,
    required this.createdBy,
    required this.createdAt,
    this.isActive = true,
  });

  factory Rule.fromMap(Map<String, dynamic> map, String id) {
    return Rule(
      id: id,
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      points: map['points'] ?? 0,
      createdBy: map['createdBy'] ?? '',
      createdAt: (map['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
      isActive: map['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'points': points,
      'createdBy': createdBy,
      'createdAt': createdAt,
      'isActive': isActive,
    };
  }
}
