// lib/screens/score_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/firebase_service.dart';
import '../providers/auth_provider.dart';
import '../models/rule.dart';

class ScoreScreen extends StatelessWidget {
  const ScoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final svc = context.read<FirebaseService>();
    final auth = context.watch<AuthProvider>();
    final member = auth.currentMember!;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F0),
      body: Column(
        children: [
          // Current score banner
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF7043), Color(0xFFFF8A65)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('내 점수',
                        style: TextStyle(color: Colors.white70, fontSize: 14)),
                    Text(
                      '${member.totalScore}점',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const Text('⭐', style: TextStyle(fontSize: 48)),
              ],
            ),
          ),

          // Rules list to request score
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Text('규칙 완료 요청',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const Spacer(),
                if (auth.isParent)
                  TextButton.icon(
                    onPressed: () => _showResetDialog(context),
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('점수 초기화 요청'),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          Expanded(
            child: StreamBuilder<List<Rule>>(
              stream: svc.getRules(),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final rules = snap.data ?? [];
                if (rules.isEmpty) {
                  return const Center(
                      child: Text('등록된 규칙이 없어요', style: TextStyle(color: Colors.grey)));
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: rules.length,
                  itemBuilder: (_, i) => _RuleRequestCard(rule: rules[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showResetDialog(BuildContext context) async {
    final svc = context.read<FirebaseService>();
    final auth = context.read<AuthProvider>();

    // Get family members to select target
    showDialog(
      context: context,
      builder: (_) => StreamBuilder(
        stream: svc.getFamilyMembers(),
        builder: (ctx, snap) {
          final members = snap.data ?? [];
          return AlertDialog(
            title: const Text('점수 초기화 요청'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('누구의 점수를 초기화할까요?'),
                const SizedBox(height: 12),
                ...members.map((m) => ListTile(
                      title: Text(m.name),
                      subtitle: Text('현재 ${m.totalScore}점'),
                      onTap: () async {
                        Navigator.pop(ctx);
                        await svc.submitResetRequest(
                          requestedByName: auth.currentMember!.name,
                          targetUserId: m.uid,
                          targetUserName: m.name,
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('초기화 요청을 보냈어요!')),
                          );
                        }
                      },
                    )),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('취소'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RuleRequestCard extends StatefulWidget {
  final Rule rule;
  const _RuleRequestCard({required this.rule});

  @override
  State<_RuleRequestCard> createState() => _RuleRequestCardState();
}

class _RuleRequestCardState extends State<_RuleRequestCard> {
  bool _submitting = false;

  Future<void> _submit() async {
    setState(() => _submitting = true);
    final svc = context.read<FirebaseService>();
    final auth = context.read<AuthProvider>();
    await svc.submitScoreRequest(
      ruleId: widget.rule.id,
      ruleTitle: widget.rule.title,
      points: widget.rule.points,
      requestedByName: auth.currentMember!.name,
    );
    if (mounted) {
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"${widget.rule.title}" 완료 요청을 보냈어요!'),
          backgroundColor: const Color(0xFFFF7043),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.rule.title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  if (widget.rule.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(widget.rule.description,
                        style: const TextStyle(color: Colors.grey, fontSize: 13)),
                  ],
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFE0B2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '+${widget.rule.points}점',
                      style: const TextStyle(
                          color: Color(0xFFE65100), fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF7043),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('완료!'),
            ),
          ],
        ),
      ),
    );
  }
}
