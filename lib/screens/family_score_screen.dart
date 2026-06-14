// lib/screens/family_score_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/firebase_service.dart';
import '../providers/auth_provider.dart';
import '../models/family_member.dart';

class FamilyScoreScreen extends StatelessWidget {
  const FamilyScoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final svc = context.read<FirebaseService>();
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F0),
      body: StreamBuilder<List<FamilyMember>>(
        stream: svc.getFamilyMembers(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final members = snap.data ?? [];
          final sorted = [...members]
            ..sort((a, b) => b.totalScore.compareTo(a.totalScore));

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF7043), Color(0xFFFF8A65)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Column(
                  children: [
                    Text('🏆', style: TextStyle(fontSize: 40)),
                    SizedBox(height: 8),
                    Text(
                      '가족 점수 현황',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Leaderboard
              ...sorted.asMap().entries.map((entry) {
                final rank = entry.key;
                final m = entry.value;
                final isMe = m.uid == auth.currentMember?.uid;
                final medals = ['🥇', '🥈', '🥉'];
                final medal = rank < 3 ? medals[rank] : '${rank + 1}위';

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: isMe
                        ? const Color(0xFFFFE0B2)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: isMe
                        ? Border.all(color: const Color(0xFFFF7043), width: 2)
                        : null,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 8),
                    leading: Text(medal, style: const TextStyle(fontSize: 28)),
                    title: Row(
                      children: [
                        Text(
                          m.name,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: isMe
                                ? const Color(0xFFE65100)
                                : const Color(0xFF3D3D3D),
                          ),
                        ),
                        if (isMe) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF7043),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('나',
                                style: TextStyle(
                                    color: Colors.white, fontSize: 11)),
                          ),
                        ],
                        const SizedBox(width: 6),
                        Text(
                          m.isParent ? '👨‍👩' : '👦',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                    subtitle: Text(
                      m.isParent ? '부모' : '자녀',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${m.totalScore}점',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: isMe
                                ? const Color(0xFFE65100)
                                : const Color(0xFF3D3D3D),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),

              const SizedBox(height: 32),
              // Reset request section (parent only)
              if (auth.isParent) ...[
                const Divider(),
                const SizedBox(height: 12),
                const Text('점수 초기화',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                const Text('초기화 요청 후 다른 가족의 승인이 필요해요.',
                    style: TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(height: 12),
                ...sorted.map((m) => ListTile(
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFFFFE0B2),
                        child: Text(m.name[0]),
                      ),
                      title: Text(m.name),
                      subtitle: Text('${m.totalScore}점'),
                      trailing: OutlinedButton(
                        onPressed: () =>
                            _requestReset(context, m),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                        ),
                        child: const Text('초기화 요청'),
                      ),
                    )),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _requestReset(BuildContext context, FamilyMember target) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('점수 초기화 요청'),
        content: Text('${target.name}의 점수(${target.totalScore}점)를 초기화 요청할까요?\n다른 가족의 승인이 필요해요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('요청', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true && context.mounted) {
      final svc = context.read<FirebaseService>();
      final auth = context.read<AuthProvider>();
      await svc.submitResetRequest(
        requestedByName: auth.currentMember!.name,
        targetUserId: target.uid,
        targetUserName: target.name,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${target.name} 점수 초기화 요청을 보냈어요!')),
        );
      }
    }
  }
}
