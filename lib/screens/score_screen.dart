// lib/screens/score_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/firebase_service.dart';
import '../providers/auth_provider.dart';
import '../models/rule.dart';
import '../models/family_member.dart';

class ScoreScreen extends StatefulWidget {
  const ScoreScreen({super.key});

  @override
  State<ScoreScreen> createState() => _ScoreScreenState();
}

class _ScoreScreenState extends State<ScoreScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    final svc = context.read<FirebaseService>();
    final auth = context.watch<AuthProvider>();
    final member = auth.currentMember!;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F0),
      body: Column(
        children: [
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
                    StreamBuilder<List<FamilyMember>>(
                      stream: svc.getFamilyMembers(),
                      builder: (ctx, snap) {
                        // 로그인 시 1회 로드된 캐시(currentMember) 대신
                        // 실시간 점수를 반영한다.
                        final matches = (snap.data ?? [])
                            .where((m) => m.uid == member.uid);
                        final score = matches.isNotEmpty
                            ? matches.first.totalScore
                            : member.totalScore;
                        return Text(
                          '$score점',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 36,
                              fontWeight: FontWeight.bold),
                        );
                      },
                    ),
                  ],
                ),
                const Text('⭐', style: TextStyle(fontSize: 48)),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Text('점수 요청',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const Spacer(),
                if (auth.isParent)
                  TextButton.icon(
                    onPressed: () => _showResetDialog(context),
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('초기화'),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                  ),
              ],
            ),
          ),

          TabBar(
            controller: _tabs,
            labelColor: const Color(0xFFFF7043),
            unselectedLabelColor: Colors.grey,
            indicatorColor: const Color(0xFFFF7043),
            tabs: const [
              Tab(text: '✅ 실천'),
              Tab(text: '⚠️ 주의'),
            ],
          ),

          Expanded(
            child: StreamBuilder<List<FamilyMember>>(
              stream: svc.getFamilyMembers(),
              builder: (ctx, memberSnap) {
                final members = memberSnap.data ?? [];
                return StreamBuilder<List<Rule>>(
                  stream: svc.getRules(),
                  builder: (ctx, ruleSnap) {
                    if (ruleSnap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final rules = ruleSnap.data ?? [];
                    final practiceRules = rules.where((r) => r.isPractice).toList();
                    final cautionRules = rules.where((r) => r.isCaution).toList();

                    return TabBarView(
                      controller: _tabs,
                      children: [
                        _RuleRequestList(
                          rules: practiceRules,
                          members: members,
                          isPractice: true,
                          emptyText: '실천 규칙이 없어요',
                        ),
                        _RuleRequestList(
                          rules: cautionRules,
                          members: members,
                          isPractice: false,
                          emptyText: '주의 규칙이 없어요',
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showResetDialog(BuildContext context) {
    final svc = context.read<FirebaseService>();
    final auth = context.read<AuthProvider>();

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

class _RuleRequestList extends StatelessWidget {
  final List<Rule> rules;
  final List<FamilyMember> members;
  final bool isPractice;
  final String emptyText;

  const _RuleRequestList({
    required this.rules,
    required this.members,
    required this.isPractice,
    required this.emptyText,
  });

  @override
  Widget build(BuildContext context) {
    if (rules.isEmpty) {
      return Center(child: Text(emptyText, style: const TextStyle(color: Colors.grey)));
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: rules.length,
      itemBuilder: (_, i) => _RuleRequestCard(
        rule: rules[i],
        members: members,
        isPractice: isPractice,
      ),
    );
  }
}

class _RuleRequestCard extends StatefulWidget {
  final Rule rule;
  final List<FamilyMember> members;
  final bool isPractice;

  const _RuleRequestCard({
    required this.rule,
    required this.members,
    required this.isPractice,
  });

  @override
  State<_RuleRequestCard> createState() => _RuleRequestCardState();
}

class _RuleRequestCardState extends State<_RuleRequestCard> {
  final Set<String> _selectedIds = {};
  bool _submitting = false;
  bool _expanded = false;

  Future<void> _submit() async {
    if (_selectedIds.isEmpty) return;
    setState(() => _submitting = true);

    final svc = context.read<FirebaseService>();
    final auth = context.read<AuthProvider>();

    final selectedMembers = widget.members
        .where((m) => _selectedIds.contains(m.uid))
        .toList();
    final ids = selectedMembers.map((m) => m.uid).toList();
    final names = selectedMembers.map((m) => m.name).toList();

    if (widget.isPractice) {
      await svc.submitPracticeRequest(
        ruleId: widget.rule.id,
        ruleTitle: widget.rule.title,
        points: widget.rule.points,
        requestedByName: auth.currentMember!.name,
        targetUserIds: ids,
        targetUserNames: names,
      );
    } else {
      await svc.submitCautionReport(
        ruleId: widget.rule.id,
        ruleTitle: widget.rule.title,
        points: widget.rule.points,
        requestedByName: auth.currentMember!.name,
        violatorIds: ids,
        violatorNames: names,
      );
    }

    if (mounted) {
      setState(() {
        _submitting = false;
        _expanded = false;
        _selectedIds.clear();
      });
      final namesStr = names.join(', ');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.isPractice
              ? '$namesStr의 "${widget.rule.title}" 실천 요청!'
              : '$namesStr의 "${widget.rule.title}" 위반 신고!'),
          backgroundColor: widget.isPractice ? const Color(0xFFFF7043) : Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = widget.isPractice ? const Color(0xFFFF7043) : Colors.red;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => setState(() {
          _expanded = !_expanded;
          if (!_expanded) _selectedIds.clear();
        }),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
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
                            color: widget.isPractice
                                ? const Color(0xFFFFE0B2)
                                : Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            widget.isPractice
                                ? '실천 +${widget.rule.points}점'
                                : '위반 시 다른 구성원 +${widget.rule.points}점',
                            style: TextStyle(
                                color: widget.isPractice
                                    ? const Color(0xFFE65100)
                                    : Colors.red.shade700,
                                fontWeight: FontWeight.bold,
                                fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.grey,
                  ),
                ],
              ),

              if (_expanded) ...[
                const SizedBox(height: 12),
                Text(
                  widget.isPractice ? '누가 실천했나요?' : '누가 위반했나요?',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.grey.shade700),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: widget.members.map((m) {
                    final selected = _selectedIds.contains(m.uid);
                    return GestureDetector(
                      onTap: () => setState(() {
                        if (selected) {
                          _selectedIds.remove(m.uid);
                        } else {
                          _selectedIds.add(m.uid);
                        }
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: selected ? accentColor : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: selected ? accentColor : Colors.grey.shade300,
                          ),
                        ),
                        child: Text(
                          m.name,
                          style: TextStyle(
                            color: selected ? Colors.white : Colors.grey.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: _selectedIds.isEmpty || _submitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.shade300,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _submitting
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : Text(
                            _selectedIds.isEmpty
                                ? '구성원을 선택하세요'
                                : widget.isPractice
                                    ? '${_selectedIds.length}명 실천 요청 보내기'
                                    : '${_selectedIds.length}명 위반 신고하기',
                          ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
