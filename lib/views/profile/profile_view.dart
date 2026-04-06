import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/memory_model.dart';
import '../../models/memory_topic.dart';
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
  DateTime _selectedMonth = DateTime.now();
  int _selectedYear = DateTime.now().year;

  User? get _currentUser => FirebaseAuth.instance.currentUser;

  Future<void> _pickAndUploadAvatar() async {
    final ImagePicker picker = ImagePicker();

    try {
      final XFile? picked = await picker.pickImage(source: ImageSource.gallery);
      if (picked == null) return;

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
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi tải ảnh: $e')));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  String _getInitials(String name) {
    final String trimmed = name.trim();
    if (trimmed.isEmpty) return 'U';
    return trimmed[0].toUpperCase();
  }

  List<BarChartGroupData> _buildMonthlyBars(
    List<MemoryModel> memories,
    Color barColor,
  ) {
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
            color: barColor,
            width: 14,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      );
    });
  }

  Map<String, int> _countsForMonth(List<MemoryModel> memories, DateTime month) {
    final Map<String, int> counts = <String, int>{};
    for (final MemoryModel m in memories) {
      if (m.date.year == month.year && m.date.month == month.month) {
        final String topic = m.topic.trim().isEmpty
            ? MemoryTopic.citywalk
            : m.topic;
        counts[topic] = (counts[topic] ?? 0) + 1;
      }
    }
    return counts;
  }

  Map<String, int> _countsForYear(List<MemoryModel> memories, int year) {
    final Map<String, int> counts = <String, int>{};
    for (final MemoryModel m in memories) {
      if (m.date.year == year) {
        final String topic = m.topic.trim().isEmpty
            ? MemoryTopic.citywalk
            : m.topic;
        counts[topic] = (counts[topic] ?? 0) + 1;
      }
    }
    return counts;
  }

  Widget _buildCategoryPieFromCounts(Map<String, int> counts) {
    final int total = counts.values.fold<int>(0, (int a, int b) => a + b);
    if (total == 0)
      return const SizedBox(
        height: 140,
        child: Center(child: Text('Chưa có dữ liệu')),
      );

    final List<PieChartSectionData> sections = <PieChartSectionData>[];
    final List<Widget> legend = <Widget>[];
    counts.forEach((String topic, int cnt) {
      final double value = cnt.toDouble();
      final Color color = MemoryTopic.color(topic);
      sections.add(
        PieChartSectionData(
          value: value,
          color: color,
          radius: 48,
          title: '${((value / total) * 100).toStringAsFixed(0)}%',
          titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      );
      legend.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(width: 12, height: 12, color: color),
            const SizedBox(width: 6),
            Text('${MemoryTopic.label(topic)} ($cnt)'),
          ],
        ),
      );
    });

    return Column(
      children: <Widget>[
        SizedBox(
          height: 140,
          child: PieChart(
            PieChartData(
              sections: sections,
              centerSpaceRadius: 24,
              sectionsSpace: 4,
              borderData: FlBorderData(show: false),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 6, children: legend),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final TextTheme tt = Theme.of(context).textTheme;
    final User? user = _currentUser;
    final String displayName = user?.displayName?.trim() ?? '';
    final String initials = _getInitials(displayName);
    final String? photoUrl = user?.photoURL;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        // Gradient flexibleSpace to match the provided header style
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: <Color>[
                Color(0xFF3B82F6), // blue
                Color(0xFF7C3AED), // purple
              ],
            ),
          ),
        ),
        // Custom title row with a small calendar icon and bold white text
        title: Row(
          children: <Widget>[
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Center(
                child: Icon(Icons.person, color: Colors.white, size: 18),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Cá nhân',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Đăng xuất',
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              try {
                await AuthService().signOut();
              } catch (e) {
                if (context.mounted)
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('$e')));
              }
            },
          ),
        ],
      ),
      body: StreamBuilder<List<MemoryModel>>(
        stream: _memoryService.getMemoriesStream(),
        builder:
            (BuildContext context, AsyncSnapshot<List<MemoryModel>> snapshot) {
              final List<MemoryModel> memories =
                  snapshot.data ?? <MemoryModel>[];
              final List<BarChartGroupData> bars = _buildMonthlyBars(
                memories,
                cs.primary,
              );
              final double bottomSafe =
                  MediaQuery.of(context).padding.bottom +
                  kBottomNavigationBarHeight +
                  24;

              return ListView(
                padding: EdgeInsets.fromLTRB(20, 20, 20, bottomSafe),
                children: <Widget>[
                  Center(
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: <Widget>[
                        CircleAvatar(
                          radius: 42,
                          backgroundColor: cs.primary,
                          backgroundImage:
                              (photoUrl != null && photoUrl.trim().isNotEmpty)
                              ? NetworkImage(photoUrl)
                              : null,
                          child:
                              (photoUrl != null && photoUrl.trim().isNotEmpty)
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
                                    color: Color.fromRGBO(0, 0, 0, 0.2),
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
                                  : Icon(
                                      Icons.edit,
                                      size: 20,
                                      color: cs.primary,
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
                    style:
                        tt.titleMedium?.copyWith(fontWeight: FontWeight.w600) ??
                        const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    user?.email ?? 'Chưa có email',
                    textAlign: TextAlign.center,
                    style:
                        tt.bodySmall?.copyWith(
                          color: Color.fromRGBO(
                            ((cs.onSurface.r * 255.0).round().clamp(
                              0,
                              255,
                            )).toInt(),
                            ((cs.onSurface.g * 255.0).round().clamp(
                              0,
                              255,
                            )).toInt(),
                            ((cs.onSurface.b * 255.0).round().clamp(
                              0,
                              255,
                            )).toInt(),
                            0.7,
                          ),
                        ) ??
                        TextStyle(color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 20),

                  Card(
                    color: cs.surfaceContainerHighest,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Thống kê kỷ niệm theo tháng',
                            style:
                                tt.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ) ??
                                const TextStyle(fontWeight: FontWeight.w700),
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
                                              style:
                                                  tt.bodySmall ??
                                                  const TextStyle(fontSize: 10),
                                            );
                                          },
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tổng kỷ niệm: ${memories.length}',
                            style: tt.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Controls: month & year selectors for the pie charts
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Tháng',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              isExpanded: true,
                              value: _selectedMonth.month,
                              items: List<DropdownMenuItem<int>>.generate(12, (
                                int i,
                              ) {
                                final int m = i + 1;
                                return DropdownMenuItem<int>(
                                  value: m,
                                  child: Text('Tháng $m'),
                                );
                              }),
                              onChanged: (int? v) {
                                if (v == null) return;
                                setState(
                                  () => _selectedMonth = DateTime(
                                    _selectedMonth.year,
                                    v,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 140,
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Năm',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              isExpanded: true,
                              value: _selectedYear,
                              items: List<DropdownMenuItem<int>>.generate(6, (
                                int i,
                              ) {
                                final int year = DateTime.now().year - i;
                                return DropdownMenuItem<int>(
                                  value: year,
                                  child: Text(year.toString()),
                                );
                              }),
                              onChanged: (int? v) {
                                if (v == null) return;
                                setState(() {
                                  _selectedYear = v;
                                  _selectedMonth = DateTime(
                                    v,
                                    _selectedMonth.month,
                                  );
                                });
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  Card(
                    color: cs.surfaceContainerHighest,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Phân bố kỷ niệm theo chuyên mục (Tháng đã chọn)',
                            style:
                                tt.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ) ??
                                const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          _buildCategoryPieFromCounts(
                            _countsForMonth(memories, _selectedMonth),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  Card(
                    color: cs.surfaceContainerHighest,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Phân bố kỷ niệm theo chuyên mục (Năm đã chọn)',
                            style:
                                tt.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ) ??
                                const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          _buildCategoryPieFromCounts(
                            _countsForYear(memories, _selectedYear),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              );
            },
      ),
    );
  }
}
