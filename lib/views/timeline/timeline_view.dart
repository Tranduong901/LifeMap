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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openAddMemoryView([MemoryModel? memory]) async {
    await Navigator.of(context).push(
      MaterialPageRoute<bool>(
        builder: (BuildContext context) => AddMemoryView(initialMemory: memory),
      ),
    );
  }

  Future<void> _deleteMemory(MemoryModel memory) async {
    final bool? agreed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Xóa kỷ niệm'),
          content: Text('Bạn chắc chắn muốn xóa "${memory.title}"?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Xóa'),
            ),
          ],
        );
      },
    );

    if (agreed != true) {
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

  List<MemoryModel> _applyFilters(List<MemoryModel> memories) {
    final String keyword = _searchController.text.trim().toLowerCase();

    return memories.where((MemoryModel memory) {
      final bool keywordMatched =
          keyword.isEmpty ||
          memory.title.toLowerCase().contains(keyword) ||
          memory.description.toLowerCase().contains(keyword);

      final bool monthMatched =
          _selectedMonth == null ||
          (memory.date.year == _selectedMonth!.year &&
              memory.date.month == _selectedMonth!.month);

      return keywordMatched && monthMatched;
    }).toList();
  }

  String _groupKey(MemoryModel memory) {
    final DateTime d = memory.date;
    switch (_groupMode) {
      case TimelineGroupMode.week:
        final int weekday = d.weekday;
        final DateTime start = d.subtract(Duration(days: weekday - 1));
        final DateTime end = start.add(const Duration(days: 6));
        return 'week-${DateFormat('yyyyMMdd').format(start)}|Tuần ${DateFormat('dd/MM').format(start)} - ${DateFormat('dd/MM').format(end)}';
      case TimelineGroupMode.year:
        return 'year-${d.year}|Năm ${d.year}';
      case TimelineGroupMode.month:
        return 'month-${d.year}-${d.month}|Tháng ${DateFormat('MM/yyyy').format(d)}';
    }
  }

  Map<String, List<MemoryModel>> _groupMemories(List<MemoryModel> memories) {
    final Map<String, List<MemoryModel>> groups = <String, List<MemoryModel>>{};
    for (final MemoryModel memory in memories) {
      final String key = _groupKey(memory);
      groups.putIfAbsent(key, () => <MemoryModel>[]).add(memory);
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dòng thời gian'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: <Widget>[
          IconButton(
            onPressed: () => _openAddMemoryView(),
            icon: const Icon(Icons.add),
            tooltip: 'Thêm kỷ niệm',
          ),
        ],
      ),
      body: StreamBuilder<List<MemoryModel>>(
        stream: _memoryService.getMemoriesStream(),
        builder: (BuildContext context, AsyncSnapshot<List<MemoryModel>> snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Không thể tải kỷ niệm: ${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final List<MemoryModel> memories = List<MemoryModel>.from(
            snapshot.data ?? <MemoryModel>[],
          );
          final List<MemoryModel> filtered = _applyFilters(memories);
          final Map<String, List<MemoryModel>> grouped = _groupMemories(
            filtered,
          );
          final List<MapEntry<String, List<MemoryModel>>> entries = grouped
              .entries
              .toList();

          if (memories.isEmpty) {
            return const Center(
              child: Text(
                'Chưa có kỷ niệm nào. Hãy thêm kỷ niệm đầu tiên ở màn hình bản đồ.',
                textAlign: TextAlign.center,
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
                          setState(() {
                            _selectedMonth = DateTime(month.year, month.month);
                          });
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
                    ButtonSegment<TimelineGroupMode>(
                      value: TimelineGroupMode.week,
                      label: Text('Tuần'),
                    ),
                    ButtonSegment<TimelineGroupMode>(
                      value: TimelineGroupMode.month,
                      label: Text('Tháng'),
                    ),
                    ButtonSegment<TimelineGroupMode>(
                      value: TimelineGroupMode.year,
                      label: Text('Năm'),
                    ),
                  ],
                  selected: <TimelineGroupMode>{_groupMode},
                  onSelectionChanged: (Set<TimelineGroupMode> value) {
                    setState(() {
                      _groupMode = value.first;
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
                    itemBuilder: (BuildContext context, int index) {
                      final MapEntry<String, List<MemoryModel>> entry =
                          entries[index];
                      final String groupTitle = entry.key.split('|').last;
                      final List<MemoryModel> groupItems = entry.value;
                      final bool expanded =
                          _expandedGroups.contains(entry.key) || index == 0;

                      return Card(
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
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          children: groupItems.map((MemoryModel memory) {
                            final String formattedDate = DateFormat(
                              'dd/MM/yyyy',
                            ).format(memory.date);
                            final String thumb = memory.imageUrls.isNotEmpty
                                ? memory.imageUrls.first
                                : memory.imageUrl;
                            return AnimatedSize(
                              duration: const Duration(milliseconds: 220),
                              child: ListTile(
                                contentPadding: const EdgeInsets.fromLTRB(
                                  12,
                                  4,
                                  8,
                                  4,
                                ),
                                leading: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    thumb,
                                    width: 58,
                                    height: 58,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (
                                          BuildContext context,
                                          Object error,
                                          StackTrace? stackTrace,
                                        ) {
                                          return Container(
                                            width: 58,
                                            height: 58,
                                            color: Colors.indigo.withValues(
                                              alpha: 0.1,
                                            ),
                                            child: const Icon(Icons.photo),
                                          );
                                        },
                                  ),
                                ),
                                title: Text(
                                  memory.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(formattedDate),
                                    Text(
                                      memory.address.isEmpty
                                          ? 'Chưa cập nhật địa chỉ'
                                          : memory.address,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: MemoryTopic.color(
                                          memory.topic,
                                        ).withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        MemoryTopic.label(memory.topic),
                                        style: TextStyle(
                                          color: MemoryTopic.color(
                                            memory.topic,
                                          ),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: PopupMenuButton<String>(
                                  onSelected: (String value) {
                                    if (value == 'edit') {
                                      _openAddMemoryView(memory);
                                    } else if (value == 'delete') {
                                      _deleteMemory(memory);
                                    } else {
                                      Navigator.of(context).push(
                                        MaterialPageRoute<void>(
                                          builder: (BuildContext context) =>
                                              MemoryDetailView(memory: memory),
                                        ),
                                      );
                                    }
                                  },
                                  itemBuilder: (BuildContext context) {
                                    return const <PopupMenuEntry<String>>[
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
                                    ];
                                  },
                                ),
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (BuildContext context) =>
                                        MemoryDetailView(memory: memory),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
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
