import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../services/memory_service.dart';

class TimelineView extends StatelessWidget {
  const TimelineView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dòng thời gian'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
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
                padding: const EdgeInsets.all(12),
                itemCount: docs.length,
                itemBuilder: (BuildContext context, int index) {
                  final Map<String, dynamic> memory = docs[index].data();
                  final Timestamp? createdAt =
                      memory['createdAt'] as Timestamp?;
                  final DateTime? createdAtDate = createdAt?.toDate();
                  final String formattedDate = createdAtDate == null
                      ? 'Chưa rõ'
                      : DateFormat('dd/MM/yyyy').format(createdAtDate);

                  return Card(
                    elevation: 2,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(10),
                      leading: SizedBox(
                        width: 56,
                        height: 56,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            (memory['imageUrl'] as String?) ?? '',
                            fit: BoxFit.cover,
                            errorBuilder:
                                (
                                  BuildContext context,
                                  Object error,
                                  StackTrace? stackTrace,
                                ) {
                                  return Container(
                                    color: Colors.indigo.withValues(
                                      alpha: 0.15,
                                    ),
                                    child: const Icon(
                                      Icons.photo,
                                      color: Colors.indigo,
                                    ),
                                  );
                                },
                          ),
                        ),
                      ),
                      title: Text(
                        (memory['description'] as String?)?.isNotEmpty == true
                            ? memory['description'] as String
                            : 'Kỷ niệm',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text('Ngày đăng: $formattedDate'),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        debugPrint('Mở chi tiết kỷ niệm: ${docs[index].id}');
                      },
                    ),
                  );
                },
              );
            },
      ),
    );
  }
}
