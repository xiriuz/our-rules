// lib/screens/family_score_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/firebase_service.dart';
import '../providers/auth_provider.dart';
import '../models/family_member.dart';
import '../models/winner.dart';

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

              ...sorted.asMap().entries.map((entry) {
                final rank = entry.key;
                final m = entry.value;
                final isMe = m.uid == auth.currentMember?.uid;
                final medals = ['🥇', '🥈', '🥉'];
                final medal = rank < 3 ? medals[rank] : '${rank + 1}위';

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: isMe ? const Color(0xFFFFE0B2) : Colors.white,
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
                    trailing: Text(
                      '${m.totalScore}점',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: isMe
                            ? const Color(0xFFE65100)
                            : const Color(0xFF3D3D3D),
                      ),
                    ),
                  ),
                );
              }),

              const SizedBox(height: 16),

              // Winner declaration (parent only)
              if (auth.isParent) ...[
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () => _showWinnerDialog(context, sorted),
                    icon: const Icon(Icons.emoji_events),
                    label: const Text('우승자 정하기'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber.shade700,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],

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
                        onPressed: () => _requestReset(context, m),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                        ),
                        child: const Text('초기화 요청'),
                      ),
                    )),
              ],

              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 12),

              // Winner history
              const Text('🏆 역대 우승자',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              _WinnerHistory(),
            ],
          );
        },
      ),
    );
  }

  void _showWinnerDialog(
      BuildContext context, List<FamilyMember> members) {
    String? selectedUid;
    String? selectedName;
    final commentCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Text('🏆 ', style: TextStyle(fontSize: 24)),
              Text('우승자 정하기'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('우승자를 선택해주세요',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: members.map((m) {
                    final selected = selectedUid == m.uid;
                    return GestureDetector(
                      onTap: () => setDialogState(() {
                        selectedUid = m.uid;
                        selectedName = m.name;
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: selected
                              ? Colors.amber.shade700
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: selected
                                ? Colors.amber.shade700
                                : Colors.grey.shade300,
                          ),
                        ),
                        child: Text(
                          '${m.name} (${m.totalScore}점)',
                          style: TextStyle(
                            color: selected
                                ? Colors.white
                                : Colors.grey.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                const Text('한마디 (선택)',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextField(
                  controller: commentCtrl,
                  decoration: InputDecoration(
                    hintText: '축하 메시지를 남겨보세요',
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: Colors.amber),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '승인되면 전체 점수가 초기화되고\n우승 기록이 남아요',
                          style: TextStyle(fontSize: 12, color: Colors.brown),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: selectedUid == null
                  ? null
                  : () async {
                      Navigator.pop(ctx);
                      final svc = context.read<FirebaseService>();
                      final auth = context.read<AuthProvider>();
                      await svc.submitWinnerRequest(
                        requestedByName: auth.currentMember!.name,
                        winnerUid: selectedUid!,
                        winnerName: selectedName!,
                        comment: commentCtrl.text.trim(),
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text(
                                  '$selectedName 우승자 선정 요청을 보냈어요!')),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber.shade700,
                foregroundColor: Colors.white,
              ),
              child: const Text('우승자 요청'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _requestReset(BuildContext context, FamilyMember target) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('점수 초기화 요청'),
        content: Text(
            '${target.name}의 점수(${target.totalScore}점)를 초기화 요청할까요?\n다른 가족의 승인이 필요해요.'),
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

class _WinnerHistory extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final svc = context.read<FirebaseService>();

    return StreamBuilder<List<Winner>>(
      stream: svc.getWinners(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: Padding(
            padding: EdgeInsets.all(20),
            child: CircularProgressIndicator(),
          ));
        }
        final winners = snap.data ?? [];
        if (winners.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: Text('아직 우승 기록이 없어요',
                  style: TextStyle(color: Colors.grey)),
            ),
          );
        }

        return Column(
          children: winners.asMap().entries.map((entry) {
            final idx = entry.key;
            final w = entry.value;
            final dateStr = DateFormat('yyyy.M.d').format(w.createdAt);

            final scoreEntries = w.allScores.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value));

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '#${winners.length - idx}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.amber.shade800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(dateStr,
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 13)),
                        const Spacer(),
                        Text('🏆 ${w.winnerName}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                    if (w.comment.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('"${w.comment}"',
                            style: const TextStyle(
                                fontStyle: FontStyle.italic, fontSize: 13)),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      children: scoreEntries.map((e) {
                        final isWinner = e.key == w.winnerName;
                        return Text(
                          '${e.key}: ${e.value}점',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight:
                                isWinner ? FontWeight.bold : FontWeight.normal,
                            color: isWinner
                                ? Colors.amber.shade800
                                : Colors.grey,
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
