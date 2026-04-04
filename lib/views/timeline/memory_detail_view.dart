import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/memory_model.dart';
import '../../models/memory_topic.dart';
import 'add_memory_view.dart';

class MemoryDetailView extends StatefulWidget {
  const MemoryDetailView({required this.memory, super.key});

  final MemoryModel memory;

  @override
  State<MemoryDetailView> createState() => _MemoryDetailViewState();
}

class _MemoryDetailViewState extends State<MemoryDetailView> {
  int _currentImageIndex = 0;

  @override
  Widget build(BuildContext context) {
    final MemoryModel memory = widget.memory;
    final List<String> photos = memory.imageUrls.isNotEmpty
        ? memory.imageUrls
        : <String>[memory.imageUrl];
    final String formattedDate = DateFormat('dd/MM/yyyy').format(memory.date);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết kỷ niệm'),
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: const Color(0xFF0F172A),
        actions: <Widget>[
          IconButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<bool>(
                builder: (BuildContext context) =>
                    AddMemoryView(initialMemory: memory),
              ),
            ),
            icon: const Icon(Icons.edit),
            tooltip: 'Chỉnh sửa',
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFFF7FAFF), Colors.white],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 18),
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                children: <Widget>[
                  SizedBox(
                    height: 250,
                    child: PageView.builder(
                      itemCount: photos.length,
                      onPageChanged: (int index) {
                        setState(() => _currentImageIndex = index);
                      },
                      itemBuilder: (BuildContext context, int index) {
                        return Image.network(
                          photos[index],
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder:
                              (
                                BuildContext context,
                                Object error,
                                StackTrace? stackTrace,
                              ) {
                                return Container(
                                  alignment: Alignment.center,
                                  color: Colors.indigo.withValues(alpha: 0.1),
                                  child: const Icon(
                                    Icons.broken_image_outlined,
                                    size: 52,
                                  ),
                                );
                              },
                        );
                      },
                    ),
                  ),
                  if (photos.length > 1)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${_currentImageIndex + 1}/${photos.length}',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(14, 20, 14, 12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: <Color>[
                            Colors.black.withValues(alpha: 0),
                            Colors.black.withValues(alpha: 0.62),
                          ],
                        ),
                      ),
                      child: Text(
                        memory.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 21,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                Chip(
                  avatar: Icon(
                    Icons.circle,
                    size: 12,
                    color: MemoryTopic.color(memory.topic),
                  ),
                  label: Text('Chủ đề: ${MemoryTopic.label(memory.topic)}'),
                ),
                Chip(
                  avatar: const Icon(Icons.calendar_month, size: 18),
                  label: Text('Ngày: $formattedDate'),
                ),
                Chip(
                  avatar: const Icon(Icons.pin_drop_outlined, size: 18),
                  label: Text(
                    '${memory.lat.toStringAsFixed(5)}, ${memory.lng.toStringAsFixed(5)}',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 0,
              color: const Color(0xFFF1F6FF),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Icon(Icons.place_outlined, color: Color(0xFF3353A4)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        memory.address.isEmpty
                            ? 'Bạn chưa thêm địa chỉ cho kỷ niệm này.'
                            : memory.address,
                        style: const TextStyle(height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Card(
              elevation: 0,
              color: const Color(0xFFFFF6EC),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Nhật ký kỷ niệm',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      memory.description,
                      style: const TextStyle(height: 1.55),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
