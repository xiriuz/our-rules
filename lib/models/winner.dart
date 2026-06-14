// lib/models/winner.dart
class Winner {
  final String id;
  final String winnerUid;
  final String winnerName;
  final int winnerScore;
  final String comment;
  final String declaredByName;
  final DateTime createdAt;
  final Map<String, int> allScores;

  Winner({
    required this.id,
    required this.winnerUid,
    required this.winnerName,
    required this.winnerScore,
    required this.comment,
    required this.declaredByName,
    required this.createdAt,
    required this.allScores,
  });

  factory Winner.fromMap(Map<String, dynamic> map, String id) {
    return Winner(
      id: id,
      winnerUid: map['winnerUid'] ?? '',
      winnerName: map['winnerName'] ?? '',
      winnerScore: map['winnerScore'] ?? 0,
      comment: map['comment'] ?? '',
      declaredByName: map['declaredByName'] ?? '',
      createdAt: (map['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
      allScores: Map<String, int>.from(map['allScores'] ?? {}),
    );
  }
}
