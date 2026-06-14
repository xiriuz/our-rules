// lib/services/firebase_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/rule.dart';
import '../models/score_request.dart';
import '../models/family_member.dart';

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

  Future<void> updateMemberScore(String uid, int delta) async {
    await _db.collection('members').doc(uid).update({
      'totalScore': FieldValue.increment(delta),
    });
  }

  Future<void> resetMemberScore(String uid) async {
    await _db.collection('members').doc(uid).update({'totalScore': 0});
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

  Future<void> updateRule(String ruleId, Rule rule) async {
    await _db.collection('rules').doc(ruleId).update(rule.toMap());
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

  Future<void> submitScoreRequest({
    required String ruleId,
    required String ruleTitle,
    required int points,
    required String requestedByName,
    String ruleCategory = 'practice',
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
      'targetUserId': uid,
      'ruleCategory': ruleCategory,
    });
  }

  Future<void> submitCautionReport({
    required String ruleId,
    required String ruleTitle,
    required int points,
    required String requestedByName,
    required String violatorId,
    required String violatorName,
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
      'targetUserId': violatorId,
      'targetUserName': violatorName,
      'ruleCategory': 'caution',
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
    if (request.type == RequestType.scoreAdd &&
        request.ruleCategory == 'caution') {
      // Caution rule: give points to all members EXCEPT the violator
      final membersSnap = await _db.collection('members').get();
      final violatorId = request.targetUserId ?? request.requestedBy;
      final batch = _db.batch();

      final reqRef = _db.collection('requests').doc(request.id);
      batch.update(reqRef, {
        'status': RequestStatus.approved.name,
        'approvedBy': approverName,
        'approvedAt': FieldValue.serverTimestamp(),
      });

      for (final doc in membersSnap.docs) {
        if (doc.id != violatorId) {
          batch.update(doc.reference, {
            'totalScore': FieldValue.increment(request.points ?? 0),
          });
        }
      }

      await batch.commit();
    } else {
      final batch = _db.batch();

      final reqRef = _db.collection('requests').doc(request.id);
      batch.update(reqRef, {
        'status': RequestStatus.approved.name,
        'approvedBy': approverName,
        'approvedAt': FieldValue.serverTimestamp(),
      });

      if (request.type == RequestType.scoreAdd) {
        final memberRef =
            _db.collection('members').doc(request.targetUserId ?? request.requestedBy);
        batch.update(memberRef, {
          'totalScore': FieldValue.increment(request.points ?? 0),
        });
      } else if (request.type == RequestType.resetScore) {
        final memberRef =
            _db.collection('members').doc(request.targetUserId);
        batch.update(memberRef, {'totalScore': 0});
      }

      await batch.commit();
    }
  }

  Future<void> rejectRequest(ScoreRequest request, String approverName) async {
    await _db.collection('requests').doc(request.id).update({
      'status': RequestStatus.rejected.name,
      'approvedBy': approverName,
      'approvedAt': FieldValue.serverTimestamp(),
    });
  }
}
