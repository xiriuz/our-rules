// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'rules_screen.dart';
import 'score_screen.dart';
import 'requests_screen.dart';
import 'family_score_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final member = auth.currentMember!;

    final screens = [
      const RulesScreen(),
      const ScoreScreen(),
      const RequestsScreen(),
      const FamilyScoreScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('🏠 ', style: TextStyle(fontSize: 20)),
            Text(
              '${member.name}님 (${member.isParent ? '부모' : '자녀'})',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFFF7043),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('로그아웃'),
                  content: const Text('로그아웃 하시겠어요?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('취소'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('로그아웃'),
                    ),
                  ],
                ),
              );
              if (confirm == true) auth.signOut();
            },
          ),
        ],
      ),
      body: screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFFFF7043),
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.list_alt), label: '규칙'),
          BottomNavigationBarItem(icon: Icon(Icons.stars), label: '점수요청'),
          BottomNavigationBarItem(icon: Icon(Icons.approval), label: '승인'),
          BottomNavigationBarItem(icon: Icon(Icons.leaderboard), label: '가족점수'),
        ],
      ),
    );
  }
}
