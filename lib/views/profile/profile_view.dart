import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/memory_model.dart';
import '../../services/auth_service.dart';
import '../../services/cloudinary_service.dart';
import '../../services/memory_service.dart';

class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  final MemoryService _memoryService = MemoryService();
  bool _isUploading = false;

  User? get _currentUser => FirebaseAuth.instance.currentUser;

  Future<void> _pickAndUploadAvatar() async {
    final ImagePicker picker = ImagePicker();

    try {
      final XFile? picked = await picker.pickImage(source: ImageSource.gallery);
      if (picked == null) {
        return;
      }

      setState(() => _isUploading = true);
      final String imageUrl = await CloudinaryService().uploadImageFile(
        File(picked.path),
      );
      await _currentUser?.updatePhotoURL(imageUrl);

      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cập nhật ảnh đại diện thành công.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi tải ảnh: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  String _getInitials(String name) {
    final String trimmed = name.trim();
    if (trimmed.isEmpty) {
      return 'U';
    }
    return trimmed[0].toUpperCase();
  }

  List<BarChartGroupData> _buildMonthlyBars(List<MemoryModel> memories) {
    final Map<int, int> countByMonth = <int, int>{};

    for (final MemoryModel memory in memories) {
      countByMonth[memory.date.month] =
          (countByMonth[memory.date.month] ?? 0) + 1;
    }

    return List<BarChartGroupData>.generate(12, (int index) {
      final int month = index + 1;
      final double value = (countByMonth[month] ?? 0).toDouble();

      return BarChartGroupData(
        x: index,
        barRods: <BarChartRodData>[
          BarChartRodData(
            toY: value,
            color: Colors.indigo,
            width: 14,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final User? user = _currentUser;
    final String displayName = user?.displayName?.trim() ?? '';
    final String initials = _getInitials(displayName);
    final String? photoUrl = user?.photoURL;
    final bool hasPhotoUrl = photoUrl != null && photoUrl.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cá nhân'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<MemoryModel>>(
        stream: _memoryService.getMemoriesStream(),
        builder:
            (BuildContext context, AsyncSnapshot<List<MemoryModel>> snapshot) {
              final List<MemoryModel> memories =
                  snapshot.data ?? <MemoryModel>[];
              final List<BarChartGroupData> bars = _buildMonthlyBars(memories);

              return ListView(
                padding: const EdgeInsets.all(20),
                children: <Widget>[
                  Center(
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: <Widget>[
                        CircleAvatar(
                          radius: 42,
                          backgroundColor: Colors.indigo,
                          backgroundImage: hasPhotoUrl
                              ? NetworkImage(photoUrl)
                              : null,
                          child: hasPhotoUrl
                              ? null
                              : Text(
                                  initials,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 30,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
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
                                boxShadow: <BoxShadow>[
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.all(6),
                              child: _isUploading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.edit,
                                      size: 20,
                                      color: Colors.indigo,
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    displayName.isNotEmpty ? displayName : 'Người dùng LifeMap',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    user?.email ?? 'Chưa có email',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 20),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Text(
                            'Thống kê kỷ niệm theo tháng',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 220,
                            child: BarChart(
                              BarChartData(
                                maxY:
                                    (bars
                                                .map(
                                                  (BarChartGroupData group) =>
                                                      group.barRods.first.toY,
                                                )
                                                .fold<double>(
                                                  0,
                                                  (double a, double b) =>
                                                      a > b ? a : b,
                                                ) +
                                            1)
                                        .clamp(4, 100),
                                barGroups: bars,
                                gridData: const FlGridData(show: true),
                                borderData: FlBorderData(show: false),
                                titlesData: FlTitlesData(
                                  topTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
                                  ),
                                  rightTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
                                  ),
                                  leftTitles: const AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      reservedSize: 28,
                                    ),
                                  ),
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      reservedSize: 26,
                                      getTitlesWidget:
                                          (double value, TitleMeta meta) {
                                            final int month = value.toInt() + 1;
                                            return Text(
                                              month.toString(),
                                              style: const TextStyle(
                                                fontSize: 10,
                                              ),
                                            );
                                          },
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text('Tổng kỷ niệm: ${memories.length}'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
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
              );
            },
      ),
    );
  }
}
