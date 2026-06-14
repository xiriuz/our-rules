// lib/screens/requests_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/firebase_service.dart';
import '../providers/auth_provider.dart';
import '../models/score_request.dart';

class RequestsScreen extends StatefulWidget {
  const RequestsScreen({super.key});

  @override
  State<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends State<RequestsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
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
            Tab(text: '⏳ 대기 중'),
            Tab(text: '📋 전체 내역'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          _PendingList(),
          _AllRequestsList(),
        ],
      ),
    );
  }
}

class _PendingList extends StatelessWidget {
  const _PendingList();

  @override
  Widget build(BuildContext context) {
    final svc = context.read<FirebaseService>();
    final auth = context.watch<AuthProvider>();

    return StreamBuilder<List<ScoreRequest>>(
      stream: svc.getPendingRequests(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final requests = snap.data ?? [];
        if (requests.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('✅', style: TextStyle(fontSize: 48)),
                SizedBox(height: 12),
                Text('대기 중인 요청이 없어요', style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: requests.length,
          itemBuilder: (_, i) => _RequestCard(
            request: requests[i],
            canApprove: auth.currentMember?.uid != requests[i].requestedBy,
            approverName: auth.currentMember?.name ?? '',
          ),
        );
      },
    );
  }
}

class _AllRequestsList extends StatelessWidget {
  const _AllRequestsList();

  @override
  Widget build(BuildContext context) {
    final svc = context.read<FirebaseService>();

    return StreamBuilder<List<ScoreRequest>>(
      stream: svc.getAllRequests(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final requests = snap.data ?? [];
        if (requests.isEmpty) {
          return const Center(
              child: Text('내역이 없어요', style: TextStyle(color: Colors.grey)));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: requests.length,
          itemBuilder: (_, i) => _RequestCard(
            request: requests[i],
            canApprove: false,
            approverName: '',
            showStatus: true,
          ),
        );
      },
    );
  }
}

class _RequestCard extends StatefulWidget {
  final ScoreRequest request;
  final bool canApprove;
  final String approverName;
  final bool showStatus;

  const _RequestCard({
    required this.request,
    required this.canApprove,
    required this.approverName,
    this.showStatus = false,
  });

  @override
  State<_RequestCard> createState() => _RequestCardState();
}

class _RequestCardState extends State<_RequestCard> {
  bool _processing = false;

  Future<void> _approve() async {
    setState(() => _processing = true);
    final svc = context.read<FirebaseService>();
    await svc.approveRequest(widget.request, widget.approverName);
    if (mounted) setState(() => _processing = false);
  }

  Future<void> _reject() async {
    setState(() => _processing = true);
    final svc = context.read<FirebaseService>();
    await svc.rejectRequest(widget.request, widget.approverName);
    if (mounted) setState(() => _processing = false);
  }

  @override
  Widget build(BuildContext context) {
    final req = widget.request;
    final isReset = req.type == RequestType.resetScore;
    final dateStr = DateFormat('M/d HH:mm').format(req.createdAt);

    Color statusColor = Colors.orange;
    String statusText = '대기 중';
    if (req.status == RequestStatus.approved) {
      statusColor = Colors.green;
      statusText = '승인됨';
    } else if (req.status == RequestStatus.rejected) {
      statusColor = Colors.red;
      statusText = '거절됨';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isReset || req.ruleCategory == 'caution'
                        ? Colors.red.shade50
                        : const Color(0xFFFFE0B2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isReset
                        ? '🔄 초기화 요청'
                        : req.ruleCategory == 'caution'
                            ? '⚠️ 주의 신고'
                            : '✅ 실천 요청',
                    style: TextStyle(
                      color: isReset || req.ruleCategory == 'caution'
                          ? Colors.red
                          : const Color(0xFFE65100),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const Spacer(),
                if (widget.showStatus)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(statusText,
                        style: TextStyle(
                            color: statusColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              isReset
                  ? '${req.requestedByName}이(가) 점수 초기화를 요청했어요'
                  : req.ruleCategory == 'caution'
                      ? '"${req.ruleTitle}" 위반 신고'
                      : '"${req.ruleTitle}" 실천 완료',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 4),
            Text(
              isReset
                  ? '요청자: ${req.requestedByName} · $dateStr'
                  : req.ruleCategory == 'caution'
                      ? '${req.requestedByName} 신고 · 승인 시 다른 구성원 +${req.points}점 · $dateStr'
                      : '${req.requestedByName} · +${req.points}점 · $dateStr',
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
            if (req.approvedBy != null) ...[
              const SizedBox(height: 4),
              Text(
                '${req.status == RequestStatus.approved ? '승인' : '거절'}: ${req.approvedBy}',
                style: TextStyle(
                    color: statusColor, fontSize: 12),
              ),
            ],

            // Approve/Reject buttons
            if (widget.canApprove &&
                req.status == RequestStatus.pending) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _processing ? null : _reject,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('거절'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _processing ? null : _approve,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF7043),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: _processing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : const Text('승인'),
                    ),
                  ),
                ],
              ),
            ],

            // Self-request notice
            if (!widget.canApprove &&
                req.status == RequestStatus.pending &&
                !widget.showStatus) ...[
              const SizedBox(height: 8),
              const Row(
                children: [
                  Icon(Icons.info_outline, size: 14, color: Colors.grey),
                  SizedBox(width: 4),
                  Text('다른 가족이 승인해야 해요',
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
