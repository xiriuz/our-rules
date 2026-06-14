// lib/screens/rules_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/firebase_service.dart';
import '../providers/auth_provider.dart';
import '../models/rule.dart';

class RulesScreen extends StatelessWidget {
  const RulesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final svc = context.read<FirebaseService>();
    final auth = context.watch<AuthProvider>();
    final isParent = auth.isParent;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F0),
      body: StreamBuilder<List<Rule>>(
        stream: svc.getRules(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final rules = snap.data ?? [];
          if (rules.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('📋', style: TextStyle(fontSize: 48)),
                  SizedBox(height: 12),
                  Text('아직 등록된 규칙이 없어요', style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: rules.length,
            itemBuilder: (_, i) => _RuleCard(rule: rules[i], isParent: isParent),
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
      builder: (_) => const _AddRuleSheet(),
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
            color: const Color(0xFFFFE0B2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              '+${rule.points}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFFE65100),
                fontSize: 16,
              ),
            ),
          ),
        ),
        title: Text(rule.title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: rule.description.isNotEmpty
            ? Text(rule.description, maxLines: 2, overflow: TextOverflow.ellipsis)
            : null,
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
  const _AddRuleSheet();

  @override
  State<_AddRuleSheet> createState() => _AddRuleSheetState();
}

class _AddRuleSheetState extends State<_AddRuleSheet> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  int _points = 1;
  bool _saving = false;

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
      createdBy: auth.currentMember!.name,
      createdAt: DateTime.now(),
    ));
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
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
          const SizedBox(height: 20),
          TextField(
            controller: _titleCtrl,
            decoration: _deco('규칙 이름 *'),
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
                  activeColor: const Color(0xFFFF7043),
                  onChanged: (v) => setState(() => _points = v.round()),
                ),
              ),
              Text('+$_points점',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Color(0xFFFF7043))),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF7043),
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
