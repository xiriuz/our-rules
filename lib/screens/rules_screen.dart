// lib/screens/rules_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/firebase_service.dart';
import '../providers/auth_provider.dart';
import '../models/rule.dart';

class RulesScreen extends StatefulWidget {
  const RulesScreen({super.key});

  @override
  State<RulesScreen> createState() => _RulesScreenState();
}

class _RulesScreenState extends State<RulesScreen>
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
    final isParent = auth.isParent;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F0),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(48),
        child: TabBar(
          controller: _tabs,
          labelColor: const Color(0xFFFF7043),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFFFF7043),
          tabs: const [
            Tab(text: '✅ 실천'),
            Tab(text: '⚠️ 주의'),
          ],
        ),
      ),
      body: StreamBuilder<List<Rule>>(
        stream: svc.getRules(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final rules = snap.data ?? [];
          final practiceRules =
              rules.where((r) => r.isPractice).toList();
          final cautionRules =
              rules.where((r) => r.isCaution).toList();

          return TabBarView(
            controller: _tabs,
            children: [
              _RuleList(
                rules: practiceRules,
                isParent: isParent,
                emptyMessage: '실천 규칙이 없어요',
                emptyEmoji: '✅',
              ),
              _RuleList(
                rules: cautionRules,
                isParent: isParent,
                emptyMessage: '주의 규칙이 없어요',
                emptyEmoji: '⚠️',
              ),
            ],
          );
        },
      ),
      floatingActionButton: isParent
          ? FloatingActionButton.extended(
              onPressed: () => _showAddRuleSheet(context),
              backgroundColor: const Color(0xFFFF7043),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('규칙 추가'),
            )
          : null,
    );
  }

  void _showAddRuleSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _AddRuleSheet(initialCategory: _tabs.index == 0
          ? RuleCategory.practice
          : RuleCategory.caution),
    );
  }
}

class _RuleList extends StatelessWidget {
  final List<Rule> rules;
  final bool isParent;
  final String emptyMessage;
  final String emptyEmoji;

  const _RuleList({
    required this.rules,
    required this.isParent,
    required this.emptyMessage,
    required this.emptyEmoji,
  });

  @override
  Widget build(BuildContext context) {
    if (rules.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emptyEmoji, style: const TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text(emptyMessage, style: const TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: rules.length,
      itemBuilder: (_, i) => _RuleCard(rule: rules[i], isParent: isParent),
    );
  }
}

class _RuleCard extends StatelessWidget {
  final Rule rule;
  final bool isParent;

  const _RuleCard({required this.rule, required this.isParent});

  @override
  Widget build(BuildContext context) {
    final svc = context.read<FirebaseService>();
    final isCaution = rule.isCaution;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: isCaution ? Colors.red.shade50 : const Color(0xFFFFE0B2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              '+${rule.points}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isCaution ? Colors.red.shade700 : const Color(0xFFE65100),
                fontSize: 16,
              ),
            ),
          ),
        ),
        title: Text(rule.title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (rule.description.isNotEmpty)
              Text(rule.description, maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text(
              isCaution ? '위반 시 다른 구성원 +${rule.points}점' : '실천 시 본인 +${rule.points}점',
              style: TextStyle(
                fontSize: 11,
                color: isCaution ? Colors.red.shade300 : Colors.orange.shade300,
              ),
            ),
          ],
        ),
        trailing: isParent
            ? IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('규칙 삭제'),
                      content: Text('"${rule.title}" 규칙을 삭제하시겠어요?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('취소'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('삭제', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) await svc.deleteRule(rule.id);
                },
              )
            : null,
      ),
    );
  }
}

class _AddRuleSheet extends StatefulWidget {
  final RuleCategory initialCategory;
  const _AddRuleSheet({required this.initialCategory});

  @override
  State<_AddRuleSheet> createState() => _AddRuleSheetState();
}

class _AddRuleSheetState extends State<_AddRuleSheet> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  late RuleCategory _category;
  int _points = 1;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _category = widget.initialCategory;
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    final svc = context.read<FirebaseService>();
    final auth = context.read<AuthProvider>();
    await svc.addRule(Rule(
      id: '',
      title: _titleCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      points: _points,
      category: _category,
      createdBy: auth.currentMember!.name,
      createdAt: DateTime.now(),
    ));
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isCaution = _category == RuleCategory.caution;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 24,
        right: 24,
        top: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('새 규칙 추가',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('분류: ', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              _CategoryChip(
                label: '✅ 실천',
                selected: !isCaution,
                color: const Color(0xFFFF7043),
                onTap: () => setState(() => _category = RuleCategory.practice),
              ),
              const SizedBox(width: 8),
              _CategoryChip(
                label: '⚠️ 주의',
                selected: isCaution,
                color: Colors.red,
                onTap: () => setState(() => _category = RuleCategory.caution),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isCaution
                ? '위반 시 다른 구성원의 점수가 올라가요'
                : '실천하면 본인의 점수가 올라가요',
            style: TextStyle(
              fontSize: 12,
              color: isCaution ? Colors.red.shade300 : Colors.orange.shade300,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _titleCtrl,
            decoration: _deco(isCaution ? '규칙 이름 (예: 때리지 않기) *' : '규칙 이름 (예: 인사하기) *'),
            autofocus: true,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descCtrl,
            decoration: _deco('설명 (선택)'),
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('점수: ', style: TextStyle(fontWeight: FontWeight.bold)),
              Expanded(
                child: Slider(
                  value: _points.toDouble(),
                  min: 1,
                  max: 20,
                  divisions: 19,
                  label: '+$_points점',
                  activeColor: isCaution ? Colors.red : const Color(0xFFFF7043),
                  onChanged: (v) => setState(() => _points = v.round()),
                ),
              ),
              Text('+$_points점',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isCaution ? Colors.red : const Color(0xFFFF7043))),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: isCaution ? Colors.red : const Color(0xFFFF7043),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _saving
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('저장'),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  InputDecoration _deco(String label) => InputDecoration(
        labelText: label,
        filled: true,
        fillColor: const Color(0xFFF5F5F5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      );
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.grey.shade600,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
