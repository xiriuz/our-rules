// lib/providers/auth_provider.dart
import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import '../models/family_member.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseService _service;
  FamilyMember? _currentMember;
  bool _loading = true;

  AuthProvider(this._service) {
    _service.authStateChanges.listen((user) async {
      if (user != null) {
        try {
          _currentMember = await _service.getMember(user.uid);
          if (_currentMember == null) {
            _lastError = 'Firestore에 멤버 문서가 없습니다 (UID: ${user.uid})';
          }
        } catch (e) {
          _lastError = 'Firestore 연결 실패: $e';
          _currentMember = null;
        }
      } else {
        _currentMember = null;
      }
      _loading = false;
      notifyListeners();
    });
  }

  FamilyMember? get currentMember => _currentMember;
  bool get loading => _loading;
  bool get isLoggedIn => _currentMember != null;
  bool get isParent => _currentMember?.isParent ?? false;

  String? _lastError;
  String? get lastError => _lastError;

  Future<bool> signIn(String email, String password) async {
    try {
      _lastError = null;
      await _service.signIn(email, password);
      return true;
    } catch (e) {
      _lastError = e.toString();
      return false;
    }
  }

  Future<void> signOut() async {
    await _service.signOut();
  }

  Future<void> refreshMember() async {
    final user = _service.currentUser;
    if (user != null) {
      _currentMember = await _service.getMember(user.uid);
      notifyListeners();
    }
  }
}
