import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/auth_service.dart';
import '../../services/cloudinary_service.dart';

class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  bool _isUploading = false;

  User? get _currentUser => FirebaseAuth.instance.currentUser;

  Future<void> _pickAndUploadAvatar() async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? picked = await picker.pickImage(source: ImageSource.gallery);
      if (picked == null) return;

      setState(() => _isUploading = true);

      final File file = File(picked.path);
      final String imageUrl = await CloudinaryService().uploadImageFile(file);

      // update FirebaseAuth profile
      try {
        await _currentUser?.updatePhotoURL(imageUrl);
      } catch (e) {
        debugPrint('Không thể cập nhật photoURL trên FirebaseAuth: $e');
      }

      // update Firestore users collection if exists
      final String? uid = _currentUser?.uid;
      if (uid != null) {
        try {
          await FirebaseFirestore.instance.collection('users').doc(uid).set(
            {'photo_url': imageUrl},
            SetOptions(merge: true),
          );
        } catch (e) {
          debugPrint('Không thể cập nhật users doc: $e');
        }
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cập nhật ảnh đại diện thành công')),
        );
      }
    } catch (e) {
      debugPrint('Lỗi khi chọn hoặc upload ảnh: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  String _getInitials(String name) {
    final String trimmed = name.trim();
    if (trimmed.isEmpty) return 'U';
    return trimmed[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final User? user = _currentUser;
    final String displayName = user?.displayName?.trim() ?? '';
    final String initials = _getInitials(displayName);
    final String? photoUrl = user?.photoURL;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cá nhân'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: <Widget>[
          Center(
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
              CircleAvatar(
                radius: 42,
                backgroundColor: Colors.indigo,
                backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                child: photoUrl == null
                    ? Text(
                        initials,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                        ),
                      )
                    : null,
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: InkWell(
                  onTap: _isUploading ? null : _pickAndUploadAvatar,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4,
                        )
                      ],
                    ),
                    padding: const EdgeInsets.all(6),
                    child: _isUploading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(
                            Icons.edit,
                            size: 20,
                            color: Colors.indigo,
                          ),
                  ),
                ),
              )
              ],
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
