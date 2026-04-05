import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/memory_model.dart';
import '../../models/memory_topic.dart';
import '../../services/memory_service.dart';
import 'add_memory_view.dart';
import 'memory_detail_view.dart';

enum TimelineGroupMode { week, month, year }

class TimelineView extends StatefulWidget {
  const TimelineView({super.key});

  @override
  State<TimelineView> createState() => _TimelineViewState();
}

class _TimelineViewState extends State<TimelineView> {
  final MemoryService _memoryService = MemoryService();
  final TextEditingController _searchController = TextEditingController();
  DateTime? _selectedMonth;
  TimelineGroupMode _groupMode = TimelineGroupMode.month;
  final Set<String> _expandedGroups = <String>{};
  String? _highlightedMemoryId;
  // Toggle this for quick debugging: render a simplified list to avoid complex layout
  // Set to false to show the redesigned timeline UI.
  final bool _debugSimpleTimeline = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openAddMemoryView([MemoryModel? memory]) async {
    await Navigator.of(context).push(
      MaterialPageRoute<bool>(
        builder: (BuildContext c) => AddMemoryView(initialMemory: memory),
      ),
    );
  }

  Future<void> _deleteMemory(MemoryModel memory) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext c) => AlertDialog(
        title: const Text('Xóa kỷ niệm'),
        content: Text('Bạn chắc chắn muốn xóa "${memory.title}"?'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(c).pop(true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (ok != true) {
      return;
    }
    try {
      await _memoryService.deleteMemory(docId: memory.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã xóa kỷ niệm thành công.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Không thể xóa kỷ niệm: $e')));
      }
    }
  }

  String _groupKey(MemoryModel memory) {
    final d = memory.date;
    switch (_groupMode) {
      case TimelineGroupMode.week:
        final weekday = d.weekday;
        final start = d.subtract(Duration(days: weekday - 1));
        final end = start.add(const Duration(days: 6));
        return 'week-${DateFormat('yyyyMMdd').format(start)}|Tuần ${DateFormat('dd/MM').format(start)} - ${DateFormat('dd/MM').format(end)}';
      case TimelineGroupMode.year:
        return 'year-${d.year}|Năm ${d.year}';
      case TimelineGroupMode.month:
        return 'month-${d.year}-${d.month}|Tháng ${DateFormat('MM/yyyy').format(d)}';
    }
  }

  Map<String, List<MemoryModel>> _groupMemories(List<MemoryModel> memories) {
    final Map<String, List<MemoryModel>> m = <String, List<MemoryModel>>{};
    for (final MemoryModel mem in memories) {
      final k = _groupKey(mem);
      m.putIfAbsent(k, () => <MemoryModel>[]).add(mem);
    }
    return m;
  }

  List<MemoryModel> _applyFilters(List<MemoryModel> memories) {
    final kw = _searchController.text.trim().toLowerCase();
    return memories.where((MemoryModel memory) {
      final bool matchesKeyword =
          kw.isEmpty ||
          memory.title.toLowerCase().contains(kw) ||
          memory.description.toLowerCase().contains(kw);
      final bool matchesMonth =
          _selectedMonth == null ||
          (memory.date.year == _selectedMonth!.year &&
              memory.date.month == _selectedMonth!.month);
      return matchesKeyword && matchesMonth;
    }).toList();
  }

  Widget _buildMemoryItem(MemoryModel memory) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 56,
            child: Column(
              children: <Widget>[
                const SizedBox(height: 8),
                SizedBox(
                  height: 92,
                  child: Container(
                    width: 3,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF2196F3), Color(0xFF7C4DFF)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
          Expanded(
            child: AnimatedScale(
              duration: const Duration(milliseconds: 220),
              scale: _highlightedMemoryId == memory.id ? 1.03 : 1.0,
              child: InkWell(
                borderRadius: BorderRadius.circular(22),
                onTapDown: (_) =>
                    setState(() => _highlightedMemoryId = memory.id),
                onTapCancel: () => setState(() => _highlightedMemoryId = null),
                onTap: () {
                  setState(() => _highlightedMemoryId = null);
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (BuildContext c) =>
                          MemoryDetailView(memory: memory),
                    ),
                  );
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: const <BoxShadow>[
                      BoxShadow(
                        color: Color(0x1F000000),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: <Widget>[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Stack(
                          children: <Widget>[
                            Image.network(
                              memory.imageUrls.isNotEmpty
                                  ? memory.imageUrls.first
                                  : memory.imageUrl,
                              width: 92,
                              height: 92,
                              fit: BoxFit.cover,
                              errorBuilder:
                                  (BuildContext c, Object e, StackTrace? st) =>
                                      Container(
                                        width: 92,
                                        height: 92,
                                        color: Colors.indigo.withAlpha(20),
                                        child: const Icon(Icons.photo),
                                      ),
                            ),
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 0,
                              height: 36,
                              child: Container(
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      Colors.black45,
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 6,
                              right: 6,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.white70,
                                  shape: BoxShape.circle,
                                ),
                                child: const Text(
                                  '📍',
                                  style: TextStyle(fontSize: 14),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              memory.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              DateFormat('dd/MM/yyyy').format(memory.date),
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              memory.address.isEmpty
                                  ? 'Chưa cập nhật địa chỉ'
                                  : memory.address,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: Colors.grey[700]),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: MemoryTopic.color(
                                  memory.topic,
                                ).withAlpha(31),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                MemoryTopic.label(memory.topic),
                                style: TextStyle(
                                  color: MemoryTopic.color(memory.topic),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuButton<String>(
                        onSelected: (String v) {
                          if (v == 'edit') {
                            _openAddMemoryView(memory);
                          } else if (v == 'delete') {
                            _deleteMemory(memory);
                          } else {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (BuildContext c) =>
                                    MemoryDetailView(memory: memory),
                              ),
                            );
                          }
                        },
                        itemBuilder: (BuildContext c) =>
                            const <PopupMenuEntry<String>>[
                              PopupMenuItem<String>(
                                value: 'view',
                                child: Text('Xem chi tiết'),
                              ),
                              PopupMenuItem<String>(
                                value: 'edit',
                                child: Text('Chỉnh sửa'),
                              ),
                              PopupMenuItem<String>(
                                value: 'delete',
                                child: Text('Xóa'),
                              ),
                            ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 56,
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF2196F3), Color(0xFF7C4DFF)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
        ),
        title: Row(
          children: const <Widget>[
            Text('📅', style: TextStyle(fontSize: 20)),
            SizedBox(width: 8),
            Text(
              'Dòng thời gian',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 18,
              ),
            ),
          ],
        ),
        actions: <Widget>[],
      ),
      body: StreamBuilder<List<MemoryModel>>(
        stream: _memoryService.getMemoriesStream(),
        builder: (BuildContext context, AsyncSnapshot<List<MemoryModel>> snap) {
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Không thể tải kỷ niệm: ${snap.error}'),
              ),
            );
          }
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final List<MemoryModel> memories = List<MemoryModel>.from(
            snap.data ?? <MemoryModel>[],
          );
          final List<MemoryModel> filtered = _applyFilters(memories);
          final grouped = _groupMemories(filtered);
          final entries = grouped.entries.toList();
          // Debug: show counts
          debugPrint(
            'TimelineView: server=${memories.length}, filtered=${filtered.length}, groups=${entries.length}',
          );

          if (memories.isEmpty) {
            return const Center(
              child: Text(
                'Chưa có kỷ niệm nào. Hãy thêm kỷ niệm đầu tiên ở màn hình bản đồ.',
                textAlign: TextAlign.center,
              ),
            );
          }

          if (_debugSimpleTimeline) {
            if (filtered.isEmpty) {
              return const Expanded(
                child: Center(
                  child: Text('Không tìm thấy kỷ niệm phù hợp bộ lọc.'),
                ),
              );
            }
            return Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: filtered.length,
                itemBuilder: (BuildContext c, int i) {
                  final MemoryModel m = filtered[i];
                  return ListTile(
                    title: Text(m.title.isEmpty ? '(Không tiêu đề)' : m.title),
                    subtitle: Text(DateFormat('dd/MM/yyyy').format(m.date)),
                    trailing: PopupMenuButton<String>(
                      onSelected: (String v) {
                        if (v == 'edit') {
                          _openAddMemoryView(m);
                        } else if (v == 'delete') {
                          _deleteMemory(m);
                        }
                      },
                      itemBuilder: (BuildContext c) =>
                          const <PopupMenuEntry<String>>[
                            PopupMenuItem<String>(
                              value: 'edit',
                              child: Text('Chỉnh sửa'),
                            ),
                            PopupMenuItem<String>(
                              value: 'delete',
                              child: Text('Xóa'),
                            ),
                          ],
                    ),
                  );
                },
              ),
            );
          }

          return Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: 'Tìm theo tên/nội dung kỷ niệm',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final DateTime? month = await showDatePicker(
                          context: context,
                          initialDate: _selectedMonth ?? DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                          initialDatePickerMode: DatePickerMode.year,
                        );
                        if (month != null) {
                          setState(
                            () => _selectedMonth = DateTime(
                              month.year,
                              month.month,
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.filter_alt_outlined),
                      label: Text(
                        _selectedMonth == null
                            ? 'Lọc thời gian'
                            : DateFormat('MM/yyyy').format(_selectedMonth!),
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: SegmentedButton<TimelineGroupMode>(
                  segments: const <ButtonSegment<TimelineGroupMode>>[
                    ButtonSegment(
                      value: TimelineGroupMode.week,
                      label: Text('Tuần'),
                    ),
                    ButtonSegment(
                      value: TimelineGroupMode.month,
                      label: Text('Tháng'),
                    ),
                    ButtonSegment(
                      value: TimelineGroupMode.year,
                      label: Text('Năm'),
                    ),
                  ],
                  selected: <TimelineGroupMode>{_groupMode},
                  onSelectionChanged: (Set<TimelineGroupMode> v) {
                    setState(() {
                      _groupMode = v.first;
                      _expandedGroups.clear();
                    });
                  },
                ),
              ),

              if (_selectedMonth != null)
                TextButton(
                  onPressed: () => setState(() => _selectedMonth = null),
                  child: const Text('Xóa bộ lọc thời gian'),
                ),

              if (filtered.isEmpty)
                const Expanded(
                  child: Center(
                    child: Text('Không tìm thấy kỷ niệm phù hợp bộ lọc.'),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: entries.length,
                    itemBuilder: (BuildContext ctx, int index) {
                      final entry = entries[index];
                      final groupTitle = entry.key.split('|').last;
                      final groupItems = entry.value;
                      final bool expanded =
                          _expandedGroups.contains(entry.key) || index == 0;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          // group header with timeline marker
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                            child: Row(
                              children: <Widget>[
                                SizedBox(
                                  width: 56,
                                  child: Column(
                                    children: <Widget>[
                                      Container(
                                        width: 16,
                                        height: 16,
                                        decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: LinearGradient(
                                            colors: [
                                              Color(0xFF7C4DFF),
                                              Color(0xFF2196F3),
                                            ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFF7C4DFF,
                                        ).withAlpha(20),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Text(
                                        groupTitle,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          Card(
                            elevation: 1.5,
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: ExpansionTile(
                              key: ValueKey<String>('group-${entry.key}'),
                              initiallyExpanded: expanded,
                              onExpansionChanged: (bool isExpanded) {
                                setState(() {
                                  if (isExpanded) {
                                    _expandedGroups.add(entry.key);
                                  } else {
                                    _expandedGroups.remove(entry.key);
                                  }
                                });
                              },
                              title: Text(
                                '$groupTitle (${groupItems.length})',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              children: <Widget>[
                                for (final MemoryModel memory in groupItems)
                                  _buildMemoryItem(memory),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
