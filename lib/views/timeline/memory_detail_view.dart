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
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _addressController;
  late String _selectedTopic;

  @override
  void initState() {
    super.initState();
    final MemoryModel m = widget.memory;
    _titleController = TextEditingController(text: m.title);
    _descriptionController = TextEditingController(text: m.description);
    _addressController = TextEditingController(text: m.address);
    _selectedTopic = m.topic.isEmpty ? MemoryTopic.citywalk : m.topic;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    super.dispose();
  }

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
                                  color: Colors.indigo.withOpacity(0.1),
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
                          color: Colors.black.withOpacity(0.5),
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
                            Colors.black.withOpacity(0),
                            Colors.black.withOpacity(0.62),
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
            // Show a detail form populated with memory content (read-only)
            const SizedBox(height: 12),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    TextFormField(
                      controller: _titleController,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'Tiêu đề',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _descriptionController,
                      readOnly: true,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Nội dung',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _addressController,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'Địa chỉ',
                        prefixIcon: Icon(Icons.place_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: TextFormField(
                            readOnly: true,
                            decoration: InputDecoration(
                              labelText: 'Lat, Lng',
                              border: const OutlineInputBorder(),
                              hintText:
                                  '${memory.lat.toStringAsFixed(6)}, ${memory.lng.toStringAsFixed(6)}',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            readOnly: true,
                            decoration: InputDecoration(
                              labelText: 'Ngày',
                              border: const OutlineInputBorder(),
                              hintText: formattedDate,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedTopic,
                      decoration: const InputDecoration(
                        labelText: 'Chủ đề',
                        border: OutlineInputBorder(),
                      ),
                      items: MemoryTopic.values
                          .map(
                            (String topic) => DropdownMenuItem<String>(
                              value: topic,
                              child: Text(MemoryTopic.label(topic)),
                            ),
                          )
                          .toList(),
                      onChanged: null,
                    ),
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 8),
                    const Text(
                      'Thông tin thêm',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: <Widget>[
                          const Icon(Icons.fingerprint, size: 18),
                          const SizedBox(width: 8),
                          Expanded(child: SelectableText('ID: ${memory.id}')),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: <Widget>[
                          const Icon(Icons.person_outline, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: SelectableText('User ID: ${memory.userId}'),
                          ),
                        ],
                      ),
                    ),
                    if (memory.imageUrls.isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const SizedBox(height: 8),
                          Text(
                            'URLs ảnh (${memory.imageUrls.length})',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 6),
                          for (final String url in memory.imageUrls)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: SelectableText(
                                url,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ),
                        ],
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
