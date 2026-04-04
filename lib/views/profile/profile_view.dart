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
  static const Color _primaryColor = Color(0xFF1A237E);
  static const Color _accentColor = Color(0xFFFFC107);
  static const Color _appBackground = Color(0xFFF5F5F7);

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

      try {
        await _currentUser?.updatePhotoURL(imageUrl);
      } catch (e) {
        debugPrint('Không thể cập nhật photoURL trên FirebaseAuth: $e');
      }

      final String? uid = _currentUser?.uid;
      if (uid != null) {
        try {
          await FirebaseFirestore.instance.collection('users').doc(uid).set(
            <String, dynamic>{'photo_url': imageUrl},
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
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

  Widget _buildStatCard(String title, String value) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 6,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
        child: Column(
          children: <Widget>[
            Text(
              value,
              style: const TextStyle(
                color: _primaryColor,
                fontWeight: FontWeight.w700,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(color: Colors.black87, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 6,
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: Icon(icon, color: _primaryColor),
        title: Text(title),
        trailing: const Icon(Icons.chevron_right, color: Colors.black87),
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final User? user = _currentUser;
    final String displayName = user?.displayName?.trim() ?? '';
    final String initials = _getInitials(displayName);
    final String? photoUrl = user?.photoURL;

    return Scaffold(
      backgroundColor: _appBackground,
      body: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: SizedBox(
              height: 280,
              child: Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  Material(
                    elevation: 12,
                    borderRadius: BorderRadius.circular(30),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(30),
                      child: Container(
                        height: 220,
                        width: double.infinity,
                        color: _primaryColor,
                        child: const Padding(
                          padding: EdgeInsets.fromLTRB(24, 30, 24, 20),
                          child: Align(
                            alignment: Alignment.topLeft,
                            child: Text(
                              'Cá nhân',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const Align(
                    alignment: Alignment(0, 0.37),
                    child: SizedBox(
                      width: 84,
                      height: 32,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: _accentColor,
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(40),
                            bottom: Radius.circular(40),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Align(
                    alignment: const Alignment(0, 0.6),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: <Widget>[
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(50),
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.22),
                                blurRadius: 14,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(4),
                          child: CircleAvatar(
                            radius: 46,
                            backgroundColor: _primaryColor,
                            backgroundImage: photoUrl != null
                                ? NetworkImage(photoUrl)
                                : null,
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
                        ),
                        Positioned(
                          right: -4,
                          bottom: -4,
                          child: InkWell(
                            onTap: _isUploading ? null : _pickAndUploadAvatar,
                            borderRadius: BorderRadius.circular(22),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: _accentColor,
                                borderRadius: BorderRadius.circular(22),
                                boxShadow: <BoxShadow>[
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.25),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: _isUploading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: _primaryColor,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.edit,
                                      size: 20,
                                      color: _primaryColor,
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              displayName.isNotEmpty ? displayName : 'Người dùng LifeMap',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              user?.email ?? 'Chưa có email',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('memories')
                  .where('userId', isEqualTo: user?.uid ?? '')
                  .snapshots(),
              builder:
                  (
                    BuildContext context,
                    AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
                  ) {
                    final int memoryCount = snapshot.data?.docs.length ?? 0;
                    return Row(
                      children: <Widget>[
                        Expanded(
                          child: _buildStatCard('Kỷ niệm', '$memoryCount'),
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: _buildStatCard('Ảnh', '$memoryCount')),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildStatCard(
                            'Năm nay',
                            '${DateTime.now().year}',
                          ),
                        ),
                      ],
                    );
                  },
            ),
          ),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: <Widget>[
                _buildSettingTile(
                  icon: Icons.collections_bookmark_outlined,
                  title: 'Kỷ niệm của tôi',
                  onTap: () {
                    debugPrint('Mở danh sách kỷ niệm cá nhân');
                  },
                ),
                const SizedBox(height: 10),
                _buildSettingTile(
                  icon: Icons.settings_outlined,
                  title: 'Cài đặt',
                  onTap: () {
                    debugPrint('Mở cài đặt tài khoản');
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                elevation: 12,
                shadowColor: Colors.black.withValues(alpha: 0.28),
                backgroundColor: _accentColor,
                foregroundColor: _primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: const StadiumBorder(),
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
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
