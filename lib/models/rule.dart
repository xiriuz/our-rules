// lib/models/rule.dart
enum RuleCategory { practice, caution }

class Rule {
  final String id;
  final String title;
  final String description;
  final int points;
  final RuleCategory category;
  final String createdBy;
  final DateTime createdAt;
  final bool isActive;

  Rule({
    required this.id,
    required this.title,
    required this.description,
    required this.points,
    this.category = RuleCategory.practice,
    required this.createdBy,
    required this.createdAt,
    this.isActive = true,
  });

  bool get isPractice => category == RuleCategory.practice;
  bool get isCaution => category == RuleCategory.caution;

  String get categoryLabel => isPractice ? '실천' : '주의';
  String get categoryEmoji => isPractice ? '✅' : '⚠️';

  factory Rule.fromMap(Map<String, dynamic> map, String id) {
    return Rule(
      id: id,
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      points: map['points'] ?? 0,
      category: map['category'] == 'caution'
          ? RuleCategory.caution
          : RuleCategory.practice,
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
      'category': category.name,
      'createdBy': createdBy,
      'createdAt': createdAt,
      'isActive': isActive,
    };
  }
}
