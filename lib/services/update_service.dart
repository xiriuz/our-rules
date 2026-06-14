// lib/services/update_service.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateService {
  static const _repo = 'xiriuz/our-rules';

  static Future<void> checkForUpdate(BuildContext context) async {
    try {
      final info = await PackageInfo.fromPlatform();
      final currentVersion = info.version;

      final response = await http.get(
        Uri.parse('https://api.github.com/repos/$_repo/releases/latest'),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) return;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final latestTag = (data['tagName'] ?? data['tag_name'] ?? '') as String;
      final latestVersion = latestTag.replaceFirst('v', '');

      if (!_isNewer(latestVersion, currentVersion)) return;

      final assets = data['assets'] as List<dynamic>? ?? [];
      String downloadUrl = data['html_url'] ?? '';
      for (final asset in assets) {
        final name = asset['name'] as String? ?? '';
        if (name.endsWith('.apk')) {
          downloadUrl = asset['browser_download_url'] as String? ?? downloadUrl;
          break;
        }
      }

      if (!context.mounted) return;

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.system_update, color: Color(0xFFFF7043)),
              SizedBox(width: 8),
              Text('업데이트 알림'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('새 버전이 있어요!'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('현재: v$currentVersion',
                        style: const TextStyle(color: Colors.grey)),
                    const Icon(Icons.arrow_forward, size: 16, color: Colors.grey),
                    Text('최신: v$latestVersion',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFFF7043))),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('나중에'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                launchUrl(
                  Uri.parse(downloadUrl),
                  mode: LaunchMode.externalApplication,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF7043),
                foregroundColor: Colors.white,
              ),
              child: const Text('업데이트'),
            ),
          ],
        ),
      );
    } catch (_) {}
  }

  static bool _isNewer(String latest, String current) {
    final lParts = latest.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    final cParts = current.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    while (lParts.length < 3) lParts.add(0);
    while (cParts.length < 3) cParts.add(0);

    for (var i = 0; i < 3; i++) {
      if (lParts[i] > cParts[i]) return true;
      if (lParts[i] < cParts[i]) return false;
    }
    return false;
  }
}
