import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../services/memory_service.dart';

class MapView extends StatefulWidget {
  const MapView({super.key});

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> with AutomaticKeepAliveClientMixin {
  static const Color _primaryColor = Color(0xFF1A237E);
  static const Color _accentColor = Color(0xFFFFC107);

  final MemoryService _memoryService = MemoryService();
  final MapController _mapController = MapController();
  final LatLng _defaultCenter = const LatLng(21.0285, 105.8542);
  LatLng _currentCenter = const LatLng(21.0285, 105.8542);
  double _currentZoom = 12;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _currentCenter = _defaultCenter;
  }

  List<Marker> _buildMarkers(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    return docs
        .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) {
          final Map<String, dynamic> data = doc.data();
          final GeoPoint? location = data['location'] as GeoPoint?;
          if (location == null) {
            return null;
          }

          final String title =
              (data['title'] as String?)?.trim().isNotEmpty == true
              ? (data['title'] as String).trim()
              : 'Kỷ niệm';
          final String description =
              (data['description'] as String?)?.trim() ?? 'Chưa có mô tả';
          final LatLng point = LatLng(location.latitude, location.longitude);

          return Marker(
            point: point,
            width: 44,
            height: 44,
            child: GestureDetector(
              onTap: () =>
                  _showMemorySummary(title: title, description: description),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.location_on,
                  size: 30,
                  color: _primaryColor,
                ),
              ),
            ),
          );
        })
        .whereType<Marker>()
        .toList(growable: false);
  }

  void _showMemorySummary({
    required String title,
    required String description,
  }) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: TextStyle(color: Colors.grey.shade800),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showAddMemoryDialog() async {
    final TextEditingController descriptionController = TextEditingController();
    final TextEditingController imageUrlController = TextEditingController();

    final bool? submitted = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Thêm kỷ niệm'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextField(
                  controller: descriptionController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Mô tả',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: imageUrlController,
                  decoration: const InputDecoration(
                    labelText: 'Link ảnh',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Kỷ niệm sẽ được ghim tại vị trí trung tâm bản đồ hiện tại.',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Lưu'),
            ),
          ],
        );
      },
    );

    if (submitted != true) {
      return;
    }

    final String description = descriptionController.text.trim();
    final String imageUrl = imageUrlController.text.trim();

    if (description.isEmpty || imageUrl.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vui lòng nhập đủ mô tả và link ảnh.')),
        );
      }
      return;
    }

    try {
      await _memoryService.saveMemory(
        description: description,
        imageUrl: imageUrl,
        lat: _currentCenter.latitude,
        lng: _currentCenter.longitude,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã thêm kỷ niệm thành công.')),
        );
      }
    } catch (e) {
      debugPrint('Thêm kỷ niệm thất bại: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Không thể thêm kỷ niệm: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final User? user = FirebaseAuth.instance.currentUser;
    final String? photoUrl = user?.photoURL;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _memoryService.getMemoriesStream(),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
          ) {
            final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs =
                snapshot.data?.docs ??
                <QueryDocumentSnapshot<Map<String, dynamic>>>[];
            final List<Marker> markers = _buildMarkers(docs);

            return Scaffold(
              body: Stack(
                children: <Widget>[
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _defaultCenter,
                      initialZoom: 12,
                      onPositionChanged: (MapPosition position, bool _) {
                        if (position.center != null) {
                          _currentCenter = position.center!;
                        }
                        if (position.zoom != null) {
                          final double nextZoom = position.zoom!;
                          if ((nextZoom - _currentZoom).abs() >= 0.05 &&
                              mounted) {
                            setState(() {
                              _currentZoom = nextZoom;
                            });
                          } else {
                            _currentZoom = nextZoom;
                          }
                        }
                      },
                    ),
                    children: <Widget>[
                      TileLayer(
                        urlTemplate:
                            'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                        subdomains: const <String>['a', 'b', 'c', 'd'],
                        keepBuffer: 2,
                        userAgentPackageName: 'com.lifemap.app',
                      ),
                      MarkerLayer(markers: markers),
                    ],
                  ),
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 25,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: TextField(
                        readOnly: true,
                        decoration: InputDecoration(
                          hintText: 'Tìm kiếm kỷ niệm...',
                          hintStyle: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                          prefixIcon: const Icon(
                            Icons.search,
                            color: _primaryColor,
                          ),
                          suffixIcon: Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: CircleAvatar(
                              radius: 14,
                              backgroundColor: Colors.grey.shade200,
                              backgroundImage: photoUrl != null
                                  ? NetworkImage(photoUrl)
                                  : null,
                              child: photoUrl == null
                                  ? const Icon(
                                      Icons.person,
                                      size: 16,
                                      color: _primaryColor,
                                    )
                                  : null,
                            ),
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    top: 84,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 180),
                      opacity:
                          snapshot.connectionState == ConnectionState.waiting
                          ? 1
                          : 0,
                      child: const LinearProgressIndicator(
                        minHeight: 3,
                        color: _primaryColor,
                        backgroundColor: Colors.white70,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 16,
                    bottom: 16,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Text(
                            'Zoom: ${_currentZoom.toStringAsFixed(1)}',
                            style: const TextStyle(
                              color: _primaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 16,
                    bottom: 16,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        FloatingActionButton.small(
                          heroTag: 'map_my_location_fab',
                          backgroundColor: Colors.white,
                          elevation: 6,
                          onPressed: () {
                            _mapController.move(_currentCenter, _currentZoom);
                          },
                          child: const Icon(
                            Icons.my_location_rounded,
                            color: _primaryColor,
                          ),
                        ),
                        const SizedBox(height: 12),
                        FloatingActionButton(
                          heroTag: 'map_add_memory_fab',
                          elevation: 12,
                          highlightElevation: 14,
                          shape: const CircleBorder(),
                          backgroundColor: _accentColor,
                          onPressed: _showAddMemoryDialog,
                          child: const Icon(
                            Icons.add_location_alt,
                            color: _primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              floatingActionButton: null,
            );
          },
    );
  }
}
