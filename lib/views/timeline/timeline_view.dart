import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/memory_service.dart';

class TimelineView extends StatelessWidget {
  const TimelineView({super.key});

  static const Color _primaryColor = Color(0xFF1A237E);
  static const Color _appBackground = Color(0xFFF5F5F7);

  String _relativeTime(DateTime date) {
    final Duration diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'Vừa xong';
    if (diff.inHours < 1) return '${diff.inMinutes} phút trước';
    if (diff.inDays < 1) return '${diff.inHours} giờ trước';
    if (diff.inDays < 30) return '${diff.inDays} ngày trước';
    return DateFormat('dd/MM/yyyy').format(date);
  }

  void _showLargeImage(
    BuildContext context, {
    required String heroTag,
    required String imageUrl,
  }) {
    if (imageUrl.trim().isEmpty) return;

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return Scaffold(
            backgroundColor: Colors.black,
            body: SafeArea(
              child: Stack(
                children: <Widget>[
                  Center(
                    child: Hero(
                      tag: heroTag,
                      child: InteractiveViewer(
                        child: Image.network(
                          imageUrl,
                          fit: BoxFit.contain,
                          errorBuilder:
                              (
                                BuildContext context,
                                Object error,
                                StackTrace? stackTrace,
                              ) {
                                return const Icon(
                                  Icons.broken_image,
                                  color: Colors.white,
                                  size: 56,
                                );
                              },
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: IconButton.filledTonal(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dòng thời gian')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: MemoryService().getMemoriesStream(),
        builder:
            (
              BuildContext context,
              AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
            ) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs =
                  List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(
                    snapshot.data?.docs ??
                        <QueryDocumentSnapshot<Map<String, dynamic>>>[],
                  );

              docs.sort((
                QueryDocumentSnapshot<Map<String, dynamic>> a,
                QueryDocumentSnapshot<Map<String, dynamic>> b,
              ) {
                final Timestamp? aCreatedAt =
                    a.data()['createdAt'] as Timestamp?;
                final Timestamp? bCreatedAt =
                    b.data()['createdAt'] as Timestamp?;
                final DateTime aDate =
                    aCreatedAt?.toDate() ??
                    DateTime.fromMillisecondsSinceEpoch(0);
                final DateTime bDate =
                    bCreatedAt?.toDate() ??
                    DateTime.fromMillisecondsSinceEpoch(0);
                return bDate.compareTo(aDate);
              });

              if (docs.isEmpty) {
                return const Center(
                  child: Text(
                    'Chưa có kỷ niệm nào. Hãy thêm kỷ niệm đầu tiên trên màn hình Bản đồ.',
                    textAlign: TextAlign.center,
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 20),
                itemCount: docs.length,
                itemBuilder: (BuildContext context, int index) {
                  final Map<String, dynamic> memory = docs[index].data();
                  final Timestamp? createdAt =
                      memory['createdAt'] as Timestamp?;
                  final DateTime? createdAtDate = createdAt?.toDate();
                  final String formattedDate = createdAtDate == null
                      ? 'Chưa rõ'
                      : DateFormat('dd/MM/yyyy').format(createdAtDate);
                  final String relativeTime = createdAtDate == null
                      ? 'Chưa rõ thời gian'
                      : _relativeTime(createdAtDate);
                  final String imageUrl =
                      (memory['imageUrl'] as String?)?.trim() ?? '';
                  final String heroTag = 'timeline_memory_${docs[index].id}';

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      SizedBox(
                        width: 36,
                        child: Column(
                          children: <Widget>[
                            Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                color: _primaryColor,
                                borderRadius: BorderRadius.circular(7),
                              ),
                            ),
                            Container(
                              width: 3,
                              height: 176,
                              color: _primaryColor.withValues(alpha: 0.35),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Card(
                          color: Colors.white,
                          elevation: 3,
                          margin: const EdgeInsets.only(bottom: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              debugPrint(
                                'Mở chi tiết kỷ niệm: ${docs[index].id}',
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Hero(
                                    tag: heroTag,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: AspectRatio(
                                        aspectRatio: 16 / 9,
                                        child: GestureDetector(
                                          onTap: () => _showLargeImage(
                                            context,
                                            heroTag: heroTag,
                                            imageUrl: imageUrl,
                                          ),
                                          child: Image.network(
                                            imageUrl,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (
                                                  BuildContext context,
                                                  Object error,
                                                  StackTrace? stackTrace,
                                                ) {
                                                  return Container(
                                                    color: _appBackground,
                                                    alignment: Alignment.center,
                                                    child: const Icon(
                                                      Icons.photo,
                                                      color: _primaryColor,
                                                    ),
                                                  );
                                                },
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    (memory['description'] as String?)
                                                ?.isNotEmpty ==
                                            true
                                        ? memory['description'] as String
                                        : 'Kỷ niệm',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Ngày đăng: $formattedDate',
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    relativeTime,
                                    style: const TextStyle(
                                      color: Color(0xAA1A237E),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
      ),
    );
  }
}
