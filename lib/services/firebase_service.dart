// lib/services/firebase_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/rule.dart';
import '../models/score_request.dart';
import '../models/family_member.dart';
import '../models/winner.dart';

class FirebaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ── Auth ──────────────────────────────────────────────
  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signIn(String email, String password) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> signOut() => _auth.signOut();

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ── Family Members ────────────────────────────────────
  Stream<List<FamilyMember>> getFamilyMembers() {
    return _db.collection('members').snapshots().map(
          (snap) => snap.docs
              .map((d) => FamilyMember.fromMap(d.data(), d.id))
              .toList(),
        );
  }

  Future<FamilyMember?> getMember(String uid) async {
    final doc = await _db.collection('members').doc(uid).get();
    if (!doc.exists) return null;
    return FamilyMember.fromMap(doc.data()!, doc.id);
  }

  // ── Rules ─────────────────────────────────────────────
  Stream<List<Rule>> getRules() {
    return _db
        .collection('rules')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snap) {
      final list =
          snap.docs.map((d) => Rule.fromMap(d.data(), d.id)).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  Future<void> addRule(Rule rule) async {
    await _db.collection('rules').add(rule.toMap());
  }

  Future<void> deleteRule(String ruleId) async {
    await _db.collection('rules').doc(ruleId).update({'isActive': false});
  }

  // ── Score Requests ────────────────────────────────────
  Stream<List<ScoreRequest>> getPendingRequests() {
    return _db
        .collection('requests')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map((d) => ScoreRequest.fromMap(d.data(), d.id))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  Stream<List<ScoreRequest>> getAllRequests() {
    return _db
        .collection('requests')
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map((d) => ScoreRequest.fromMap(d.data(), d.id))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list.take(50).toList();
    });
  }

  Future<void> submitPracticeRequest({
    required String ruleId,
    required String ruleTitle,
    required int points,
    required String requestedByName,
    required List<String> targetUserIds,
    required List<String> targetUserNames,
  }) async {
    final uid = currentUser!.uid;
    await _db.collection('requests').add({
      'requestedBy': uid,
      'requestedByName': requestedByName,
      'ruleId': ruleId,
      'ruleTitle': ruleTitle,
      'points': points,
      'type': RequestType.scoreAdd.name,
      'status': RequestStatus.pending.name,
      'createdAt': FieldValue.serverTimestamp(),
      'approvedBy': null,
      'approvedAt': null,
      'ruleCategory': 'practice',
      'targetUserIds': targetUserIds,
      'targetUserNames': targetUserNames,
    });
  }

  Future<void> submitCautionReport({
    required String ruleId,
    required String ruleTitle,
    required int points,
    required String requestedByName,
    required List<String> violatorIds,
    required List<String> violatorNames,
  }) async {
    final uid = currentUser!.uid;
    await _db.collection('requests').add({
      'requestedBy': uid,
      'requestedByName': requestedByName,
      'ruleId': ruleId,
      'ruleTitle': ruleTitle,
      'points': points,
      'type': RequestType.scoreAdd.name,
      'status': RequestStatus.pending.name,
      'createdAt': FieldValue.serverTimestamp(),
      'approvedBy': null,
      'approvedAt': null,
      'ruleCategory': 'caution',
      'targetUserIds': violatorIds,
      'targetUserNames': violatorNames,
    });
  }

  Future<void> submitResetRequest({
    required String requestedByName,
    required String targetUserId,
    required String targetUserName,
  }) async {
    final uid = currentUser!.uid;
    await _db.collection('requests').add({
      'requestedBy': uid,
      'requestedByName': requestedByName,
      'ruleId': null,
      'ruleTitle': null,
      'points': null,
      'type': RequestType.resetScore.name,
      'status': RequestStatus.pending.name,
      'createdAt': FieldValue.serverTimestamp(),
      'approvedBy': null,
      'approvedAt': null,
      'targetUserId': targetUserId,
      'targetUserName': targetUserName,
    });
  }

  Future<void> approveRequest(ScoreRequest request, String approverName) async {
    final reqRef = _db.collection('requests').doc(request.id);

    // 우승 선정·승인 취소·주의 신고는 전체 구성원을 다뤄야 하므로
    // 트랜잭션에 들어가기 전에 멤버 문서 참조를 미리 확보한다.
    // (클라이언트 트랜잭션 안에서는 컬렉션 쿼리를 실행할 수 없다.)
    final touchesAllMembers = request.type == RequestType.declareWinner ||
        request.type == RequestType.cancelRequest ||
        (request.type == RequestType.scoreAdd &&
            request.ruleCategory == 'caution');
    List<DocumentReference<Map<String, dynamic>>> memberRefs = [];
    if (touchesAllMembers) {
      final snap = await _db.collection('members').get();
      memberRefs = snap.docs.map((d) => d.reference).toList();
    }

    await _db.runTransaction((tx) async {
      final reqSnap = await tx.get(reqRef);
      if (!reqSnap.exists) return;
      // 이미 처리된 요청(중복 탭·동시 승인)이면 점수를 다시 적용하지 않는다.
      if (reqSnap.data()!['status'] != RequestStatus.pending.name) return;

      // ── 읽기 단계 (모든 tx.get 은 쓰기보다 먼저) ──
      // 우승 선정: 전원 점수 스냅샷을 위해 멤버 문서를 읽는다.
      final winnerScores = <String, int>{};
      if (request.type == RequestType.declareWinner) {
        for (final ref in memberRefs) {
          final m = await tx.get(ref);
          final name = (m.data()?['name'] ?? ref.id) as String;
          winnerScores[name] = (m.data()?['totalScore'] ?? 0) as int;
        }
      }

      // 승인 취소: 원본 요청 상태를 확인한다.
      DocumentSnapshot<Map<String, dynamic>>? origSnap;
      if (request.type == RequestType.cancelRequest &&
          request.originalRequestId != null) {
        origSnap = await tx
            .get(_db.collection('requests').doc(request.originalRequestId!));
      }

      // ── 쓰기 단계 ──
      tx.update(reqRef, {
        'status': RequestStatus.approved.name,
        'approvedBy': approverName,
        'approvedAt': FieldValue.serverTimestamp(),
      });

      if (request.type == RequestType.resetScore) {
        tx.update(
            _db.collection('members').doc(request.targetUserId),
            {'totalScore': 0});
        return;
      }

      if (request.type == RequestType.cancelRequest) {
        if (origSnap == null || !origSnap.exists) return;
        final orig = ScoreRequest.fromMap(origSnap.data()!, origSnap.id);
        // 원본이 이미 취소·거절된 상태면 점수를 다시 되돌리지 않는다.
        if (orig.status != RequestStatus.approved) return;
        tx.update(origSnap.reference,
            {'status': RequestStatus.cancelled.name});
        final pts = orig.points ?? 0;
        if (orig.ruleCategory == 'practice') {
          for (final uid in orig.targetUserIds) {
            tx.update(_db.collection('members').doc(uid),
                {'totalScore': FieldValue.increment(-pts)});
          }
        } else if (orig.ruleCategory == 'caution') {
          final violators = orig.targetUserIds.toSet();
          for (final ref in memberRefs) {
            if (!violators.contains(ref.id)) {
              tx.update(ref, {'totalScore': FieldValue.increment(-pts)});
            }
          }
        }
        return;
      }

      if (request.type == RequestType.declareWinner) {
        for (final ref in memberRefs) {
          tx.update(ref, {'totalScore': 0});
        }
        final winnerRef = _db.collection('winners').doc();
        tx.set(winnerRef, {
          'winnerUid': request.targetUserId,
          'winnerName': request.targetNamesText,
          'winnerScore': winnerScores[request.targetNamesText] ?? 0,
          'comment': request.winnerComment ?? '',
          'declaredByName': request.requestedByName,
          'createdAt': FieldValue.serverTimestamp(),
          'allScores': winnerScores,
        });
        return;
      }

      // 기본: 점수 추가 (scoreAdd)
      final pts = request.points ?? 0;
      if (request.ruleCategory == 'practice') {
        for (final uid in request.targetUserIds) {
          tx.update(_db.collection('members').doc(uid),
              {'totalScore': FieldValue.increment(pts)});
        }
      } else if (request.ruleCategory == 'caution') {
        final violators = request.targetUserIds.toSet();
        for (final ref in memberRefs) {
          if (!violators.contains(ref.id)) {
            tx.update(ref, {'totalScore': FieldValue.increment(pts)});
          }
        }
      }
    });
  }

  Future<void> rejectRequest(ScoreRequest request, String approverName) async {
    await _db.collection('requests').doc(request.id).update({
      'status': RequestStatus.rejected.name,
      'approvedBy': approverName,
      'approvedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> submitCancelRequest({
    required ScoreRequest originalRequest,
    required String requestedByName,
  }) async {
    final uid = currentUser!.uid;
    await _db.collection('requests').add({
      'requestedBy': uid,
      'requestedByName': requestedByName,
      'ruleId': originalRequest.ruleId,
      'ruleTitle': originalRequest.ruleTitle,
      'points': originalRequest.points,
      'type': RequestType.cancelRequest.name,
      'status': RequestStatus.pending.name,
      'createdAt': FieldValue.serverTimestamp(),
      'approvedBy': null,
      'approvedAt': null,
      'ruleCategory': originalRequest.ruleCategory,
      'targetUserIds': originalRequest.targetUserIds,
      'targetUserNames': originalRequest.targetUserNames,
      'originalRequestId': originalRequest.id,
    });
  }

  Future<void> submitWinnerRequest({
    required String requestedByName,
    required String winnerUid,
    required String winnerName,
    required String comment,
  }) async {
    final uid = currentUser!.uid;
    await _db.collection('requests').add({
      'requestedBy': uid,
      'requestedByName': requestedByName,
      'ruleId': null,
      'ruleTitle': null,
      'points': null,
      'type': RequestType.declareWinner.name,
      'status': RequestStatus.pending.name,
      'createdAt': FieldValue.serverTimestamp(),
      'approvedBy': null,
      'approvedAt': null,
      'targetUserId': winnerUid,
      'targetUserIds': [winnerUid],
      'targetUserNames': [winnerName],
      'winnerComment': comment,
    });
  }

  // ── Winners ──────────────────────────────────────────
  Stream<List<Winner>> getWinners() {
    return _db.collection('winners').snapshots().map((snap) {
      final list = snap.docs
          .map((d) => Winner.fromMap(d.data(), d.id))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }
}
