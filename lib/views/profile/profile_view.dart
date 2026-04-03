import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../services/auth_service.dart';

class ProfileView extends StatelessWidget {
  const ProfileView({super.key});

  User? _safeCurrentUser() {
    try {
      return FirebaseAuth.instance.currentUser;
    } catch (e) {
      debugPrint('Không thể lấy currentUser: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final User? user = _safeCurrentUser();
    final String displayName = user?.displayName?.trim() ?? '';
    final String initials = displayName.isNotEmpty
        ? displayName[0].toUpperCase()
        : 'U';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cá nhân'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: <Widget>[
          CircleAvatar(
            radius: 42,
            backgroundColor: Colors.indigo,
            child: Text(
              initials,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            displayName.isNotEmpty ? displayName : 'Người dùng LifeMap',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            user?.email ?? 'Chưa có email',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade700),
          ),
          const SizedBox(height: 24),
          Card(
            child: ListTile(
              leading: const Icon(Icons.collections_bookmark_outlined),
              title: const Text('Kỷ niệm của tôi'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                debugPrint('Mở danh sách kỷ niệm cá nhân');
              },
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Cài đặt'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                debugPrint('Mở cài đặt tài khoản');
              },
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: () async {
              try {
                await AuthService().signOut();
              } catch (e) {
                debugPrint('Đăng xuất thất bại: $e');
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('$e')));
                }
              }
            },
            icon: const Icon(Icons.logout),
            label: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
  }
}
