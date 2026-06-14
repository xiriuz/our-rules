// lib/models/score_request.dart
enum RequestType { scoreAdd, resetScore }
enum RequestStatus { pending, approved, rejected }

class ScoreRequest {
  final String id;
  final String requestedBy;
  final String requestedByName;
  final String? ruleId;
  final String? ruleTitle;
  final int? points;
  final RequestType type;
  final RequestStatus status;
  final DateTime createdAt;
  final String? approvedBy;
  final DateTime? approvedAt;
  final String? targetUserId; // for reset: who to reset

  ScoreRequest({
    required this.id,
    required this.requestedBy,
    required this.requestedByName,
    this.ruleId,
    this.ruleTitle,
    this.points,
    required this.type,
    required this.status,
    required this.createdAt,
    this.approvedBy,
    this.approvedAt,
    this.targetUserId,
  });

  factory ScoreRequest.fromMap(Map<String, dynamic> map, String id) {
    return ScoreRequest(
      id: id,
      requestedBy: map['requestedBy'] ?? '',
      requestedByName: map['requestedByName'] ?? '',
      ruleId: map['ruleId'],
      ruleTitle: map['ruleTitle'],
      points: map['points'],
      type: RequestType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => RequestType.scoreAdd,
      ),
      status: RequestStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => RequestStatus.pending,
      ),
      createdAt: (map['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
      approvedBy: map['approvedBy'],
      approvedAt: (map['approvedAt'] as dynamic)?.toDate(),
      targetUserId: map['targetUserId'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'requestedBy': requestedBy,
      'requestedByName': requestedByName,
      'ruleId': ruleId,
      'ruleTitle': ruleTitle,
      'points': points,
      'type': type.name,
      'status': status.name,
      'createdAt': createdAt,
      'approvedBy': approvedBy,
      'approvedAt': approvedAt,
      'targetUserId': targetUserId,
    };
  }
}
