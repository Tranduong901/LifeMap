import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../services/memory_service.dart';

const String _mapboxAccessToken = String.fromEnvironment(
  'MAPBOX_ACCESS_TOKEN',
  defaultValue: '',
);

class MapView extends StatefulWidget {
  const MapView({super.key});

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  final MemoryService _memoryService = MemoryService();
  MapboxMap? _mapboxMap;
  PointAnnotationManager? _pointAnnotationManager;
  String? _renderedMemorySignature;
  final Position _defaultPosition = Position(105.8542, 21.0285);
  Uint8List? _markerIconBytes;

  bool get _hasMapboxToken => _mapboxAccessToken.isNotEmpty;

  @override
  void initState() {
    super.initState();
    if (_hasMapboxToken) {
      MapboxOptions.setAccessToken(_mapboxAccessToken);
    }
  }

  Future<void> _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;
    await mapboxMap.setCamera(
      CameraOptions(center: Point(coordinates: _defaultPosition), zoom: 12),
    );
  }

  Future<void> _onStyleLoaded(StyleLoadedEventData data) async {
    if (_mapboxMap == null) {
      return;
    }

    _pointAnnotationManager ??= await _mapboxMap!.annotations
        .createPointAnnotationManager();
    if (mounted) {
      setState(() {});
    }
  }

  Future<Uint8List> _buildMarkerIcon() async {
    if (_markerIconBytes != null) {
      return _markerIconBytes!;
    }

    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    final Paint shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.2)
      ..style = PaintingStyle.fill;
    final Paint fillPaint = Paint()
      ..color = Colors.indigo
      ..style = PaintingStyle.fill;
    final Paint ringPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    canvas.drawCircle(const Offset(34, 34), 24, shadowPaint);
    canvas.drawCircle(const Offset(30, 30), 22, fillPaint);
    canvas.drawCircle(const Offset(30, 30), 8, ringPaint);

    final ui.Picture picture = recorder.endRecording();
    final ui.Image image = await picture.toImage(64, 64);
    final ByteData? byteData = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );

    if (byteData == null) {
      throw Exception('Không thể tạo biểu tượng kỷ niệm.');
    }

    _markerIconBytes = byteData.buffer.asUint8List();
    return _markerIconBytes!;
  }

  Future<void> _syncMemoriesToMap(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    if (_pointAnnotationManager == null) {
      return;
    }

    final String signature = docs
        .map((QueryDocumentSnapshot<Map<String, dynamic>> doc) => doc.id)
        .join('|');
    if (signature == _renderedMemorySignature) {
      return;
    }

    _renderedMemorySignature = signature;

    await _pointAnnotationManager!.deleteAll();
    final Uint8List markerIcon = await _buildMarkerIcon();

    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in docs) {
      final Map<String, dynamic> data = doc.data();
      final GeoPoint? location = data['location'] as GeoPoint?;
      if (location == null) {
        continue;
      }

      await _pointAnnotationManager!.create(
        PointAnnotationOptions(
          geometry: Point(
            coordinates: Position(location.longitude, location.latitude),
          ),
          image: markerIcon,
          iconSize: 1.2,
          textField: (data['description'] as String?)?.trim() ?? '',
        ),
      );
    }
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
        lat: _defaultPosition.lat.toDouble(),
        lng: _defaultPosition.lng.toDouble(),
      );
      _renderedMemorySignature = null;
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

            if (docs.isNotEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _syncMemoriesToMap(docs);
              });
            }

            return Scaffold(
              body: Stack(
                children: <Widget>[
                  if (_hasMapboxToken)
                    MapWidget(
                      key: const ValueKey<String>('lifemap_mapbox_widget'),
                      styleUri: MapboxStyles.MAPBOX_STREETS,
                      cameraOptions: CameraOptions(
                        center: Point(coordinates: _defaultPosition),
                        zoom: 12,
                      ),
                      onMapCreated: _onMapCreated,
                      onStyleLoadedListener: _onStyleLoaded,
                    )
                  else
                    Container(
                      color: Colors.indigo.withValues(alpha: 0.08),
                      alignment: Alignment.center,
                      padding: const EdgeInsets.all(24),
                      child: const Text(
                        'Thiếu MAPBOX_ACCESS_TOKEN.\nHãy chạy app với --dart-define=MAPBOX_ACCESS_TOKEN=your_token',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  Positioned(
                    top: 20,
                    left: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.indigo.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Text(
                        'Bản đồ kỷ niệm',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  if (snapshot.connectionState == ConnectionState.waiting)
                    Positioned(
                      bottom: 20,
                      left: 16,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Text(
                          'Đang tải kỷ niệm...',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                ],
              ),
              floatingActionButton: FloatingActionButton(
                backgroundColor: Colors.indigo,
                onPressed: _showAddMemoryDialog,
                child: const Icon(Icons.add_location_alt, color: Colors.white),
              ),
            );
          },
    );
  }
}
