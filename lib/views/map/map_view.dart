import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_map/flutter_map.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:latlong2/latlong.dart' as ll;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mb;

import '../../models/memory_model.dart';
import '../../models/memory_topic.dart';
import '../../services/memory_service.dart';
import '../timeline/memory_detail_view.dart';
import '../timeline/add_memory_view.dart';

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
  final TextEditingController _searchController = TextEditingController();
  final mb.Position _defaultPosition = mb.Position(105.8542, 21.0285);
  final MapController _osmMapController = MapController();
  ll.LatLng _osmCenter = const ll.LatLng(21.0285, 105.8542);
  final Set<String> _selectedTopics = <String>{};

  mb.MapboxMap? _mapboxMap;
  mb.PointAnnotationManager? _pointAnnotationManager;
  mb.Cancelable? _pointTapEvents;
  final Map<int, Uint8List> _markerIconCache = <int, Uint8List>{};
  final Map<String, MemoryModel> _annotationMemoryMap = <String, MemoryModel>{};

  String _lastMemorySignature = '';

  bool get _hasMapboxToken => _mapboxAccessToken.isNotEmpty;

  @override
  void initState() {
    super.initState();
    if (_hasMapboxToken) {
      mb.MapboxOptions.setAccessToken(_mapboxAccessToken);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _pointTapEvents?.cancel();
    super.dispose();
  }

  List<String> _availableTopics(List<MemoryModel> memories) {
    final Set<String> topics = <String>{...MemoryTopic.presets};
    for (final MemoryModel memory in memories) {
      final String topic = memory.topic.trim().toLowerCase();
      if (topic.isNotEmpty) {
        topics.add(topic);
      }
    }
    return topics.toList();
  }

  List<MemoryModel> _filterMapMemories(List<MemoryModel> memories) {
    final String keyword = _searchController.text.trim().toLowerCase();
    return memories.where((MemoryModel memory) {
      final bool keywordMatched =
          keyword.isEmpty || memory.title.toLowerCase().contains(keyword);
      final bool topicMatched =
          _selectedTopics.isEmpty || _selectedTopics.contains(memory.topic);
      return keywordMatched && topicMatched;
    }).toList();
  }

  Future<void> _onMapCreated(mb.MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;
    await mapboxMap.setCamera(
      mb.CameraOptions(
        center: mb.Point(coordinates: _defaultPosition),
        zoom: 12,
      ),
    );
  }

  Future<void> _onStyleLoaded(mb.StyleLoadedEventData data) async {
    if (_mapboxMap == null) {
      return;
    }

    _pointAnnotationManager ??= await _mapboxMap!.annotations
        .createPointAnnotationManager();
    _pointTapEvents ??= _pointAnnotationManager!.tapEvents(
      onTap: (mb.PointAnnotation annotation) {
        final MemoryModel? memory = _annotationMemoryMap[annotation.id];
        if (memory != null) {
          _showMemoryBottomSheet(memory);
        }
      },
    );

    if (mounted) {
      setState(() {});
    }
  }

  Future<Uint8List> _buildMarkerIcon(Color color) async {
    final int key = color.toARGB32();
    if (_markerIconCache.containsKey(key)) {
      return _markerIconCache[key]!;
    }

    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);

    final Paint fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final Paint centerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    canvas.drawCircle(const Offset(28, 28), 20, fillPaint);
    canvas.drawCircle(const Offset(28, 28), 7, centerPaint);

    final ui.Image image = await recorder.endRecording().toImage(56, 56);
    final ByteData? byteData = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );

    if (byteData == null) {
      throw Exception('Không thể tạo biểu tượng đánh dấu.');
    }

    final Uint8List bytes = byteData.buffer.asUint8List();
    _markerIconCache[key] = bytes;
    return bytes;
  }

  Future<void> _syncMarkers(List<MemoryModel> memories) async {
    if (_pointAnnotationManager == null) {
      return;
    }

    final String signature = memories
        .map((MemoryModel memory) => '${memory.id}:${memory.lat}:${memory.lng}')
        .join('|');

    if (signature == _lastMemorySignature) {
      return;
    }

    _lastMemorySignature = signature;

    await _pointAnnotationManager!.deleteAll();
    _annotationMemoryMap.clear();

    for (final MemoryModel memory in memories) {
      final Color topicColor = MemoryTopic.color(memory.topic);
      final Uint8List icon = await _buildMarkerIcon(topicColor);
      final mb.PointAnnotation annotation = await _pointAnnotationManager!
          .create(
            mb.PointAnnotationOptions(
              geometry: mb.Point(
                coordinates: mb.Position(memory.lng, memory.lat),
              ),
              image: icon,
              iconSize: 1,
              textField: memory.title,
              textColor: Colors.black.toARGB32(),
              textHaloColor: Colors.white.toARGB32(),
              textHaloWidth: 1.5,
              textOffset: const <double>[0, 1.6],
              textSize: 12,
            ),
          );

      _annotationMemoryMap[annotation.id] = memory;
    }
  }

  Future<void> _moveToCurrentLocation() async {
    final bool enabled = await geo.Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      _showMessage('Vui lòng bật GPS để sử dụng tính năng này.');
      return;
    }

    geo.LocationPermission permission = await geo.Geolocator.checkPermission();
    if (permission == geo.LocationPermission.denied) {
      permission = await geo.Geolocator.requestPermission();
    }

    if (permission == geo.LocationPermission.deniedForever ||
        permission == geo.LocationPermission.denied) {
      _showMessage('Ứng dụng chưa có quyền vị trí.');
      return;
    }

    final geo.Position current = await geo.Geolocator.getCurrentPosition();
    if (_hasMapboxToken) {
      await _mapboxMap?.flyTo(
        mb.CameraOptions(
          center: mb.Point(
            coordinates: mb.Position(current.longitude, current.latitude),
          ),
          zoom: 13,
        ),
        mb.MapAnimationOptions(duration: 900),
      );
      return;
    }

    final ll.LatLng currentPoint = ll.LatLng(
      current.latitude,
      current.longitude,
    );
    _osmMapController.move(currentPoint, 13);
    if (mounted) {
      setState(() => _osmCenter = currentPoint);
    }
  }

  void _showMemoryBottomSheet(MemoryModel memory) {
    showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext context) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                memory.title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 6),
              Chip(
                avatar: Icon(
                  Icons.circle,
                  size: 12,
                  color: MemoryTopic.color(memory.topic),
                ),
                label: Text('Chủ đề: ${MemoryTopic.label(memory.topic)}'),
              ),
              const SizedBox(height: 6),
              Text(memory.address.isEmpty ? 'Chưa có địa chỉ' : memory.address),
              const SizedBox(height: 4),
              Text(
                'Lat: ${memory.lat.toStringAsFixed(6)}, Lng: ${memory.lng.toStringAsFixed(6)}',
              ),
              const SizedBox(height: 10),
              if (memory.imageUrls.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    memory.imageUrls.first,
                    width: double.infinity,
                    height: 180,
                    fit: BoxFit.cover,
                    errorBuilder:
                        (
                          BuildContext context,
                          Object error,
                          StackTrace? stackTrace,
                        ) {
                          return Container(
                            height: 120,
                            alignment: Alignment.center,
                            child: const Text('Không tải được ảnh'),
                          );
                        },
                  ),
                ),
              const SizedBox(height: 8),
              Text(memory.description),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(this.context).push(
                      MaterialPageRoute<void>(
                        builder: (BuildContext context) =>
                            MemoryDetailView(memory: memory),
                      ),
                    );
                  },
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Xem chi tiết'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<MemoryModel>>(
      stream: _memoryService.getMemoriesStream(),
      builder: (BuildContext context, AsyncSnapshot<List<MemoryModel>> snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Không thể tải dữ liệu bản đồ: ${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        final List<MemoryModel> allMemories = snapshot.data ?? <MemoryModel>[];
        final List<MemoryModel> memories = _filterMapMemories(allMemories);
        final List<String> topics = _availableTopics(allMemories);

        if (memories.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _syncMarkers(memories);
          });
        }

        final double fabBottom =
            MediaQuery.of(context).padding.bottom +
            kBottomNavigationBarHeight +
            12.0;

        return Scaffold(
          body: Stack(
            children: <Widget>[
              if (_hasMapboxToken)
                mb.MapWidget(
                  key: const ValueKey<String>('lifemap_mapbox_widget'),
                  styleUri: mb.MapboxStyles.MAPBOX_STREETS,
                  cameraOptions: mb.CameraOptions(
                    center: mb.Point(coordinates: _defaultPosition),
                    zoom: 12,
                  ),
                  onMapCreated: _onMapCreated,
                  onStyleLoadedListener: _onStyleLoaded,
                )
              else
                Stack(
                  children: <Widget>[
                    FlutterMap(
                      mapController: _osmMapController,
                      options: MapOptions(
                        initialCenter: _osmCenter,
                        initialZoom: 12,
                      ),
                      children: <Widget>[
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'vn.edu.tlu.nhom7.lifemap',
                        ),
                        MarkerLayer(
                          markers: memories.map((MemoryModel memory) {
                            final Color topicColor = MemoryTopic.color(
                              memory.topic,
                            );
                            return Marker(
                              width: 40,
                              height: 40,
                              point: ll.LatLng(memory.lat, memory.lng),
                              child: GestureDetector(
                                onTap: () => _showMemoryBottomSheet(memory),
                                child: Icon(
                                  Icons.location_on,
                                  color: topicColor,
                                  size: 34,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ],
                ),
              Positioned(
                top: 16,
                left: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      TextField(
                        controller: _searchController,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: 'Tìm theo tên kỷ niệm...',
                          prefixIcon: const Icon(Icons.search),
                          isDense: true,
                          filled: true,
                          fillColor: const Color(0xFFF4F6FA),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: topics.map((String topic) {
                            final bool selected = _selectedTopics.contains(
                              topic,
                            );
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                label: Text(MemoryTopic.label(topic)),
                                selected: selected,
                                onSelected: (bool value) {
                                  setState(() {
                                    if (value) {
                                      _selectedTopics.add(topic);
                                    } else {
                                      _selectedTopics.remove(topic);
                                    }
                                  });
                                },
                                avatar: Icon(
                                  Icons.circle,
                                  size: 10,
                                  color: MemoryTopic.color(topic),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Floating buttons positioned over the map
              Positioned(
                bottom: fabBottom,
                right: 16,
                child: FloatingActionButton(
                  heroTag: 'add_memory_btn',
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (BuildContext c) => const AddMemoryView(),
                      ),
                    );
                  },
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  child: const Icon(Icons.add),
                ),
              ),

              Positioned(
                bottom: fabBottom,
                left: 16,
                child: FloatingActionButton.small(
                  heroTag: 'gps_btn',
                  onPressed: _moveToCurrentLocation,
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.indigo,
                  child: const Icon(Icons.my_location),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
