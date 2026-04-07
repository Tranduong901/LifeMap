import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:latlong2/latlong.dart' as ll;

import '../../models/memory_model.dart';
import '../../models/memory_topic.dart';
import '../../services/memory_service.dart';
import '../../services/social_service.dart';
import '../timeline/memory_detail_view.dart';
import '../timeline/add_memory_view.dart';

class MapView extends StatefulWidget {
  const MapView({super.key});

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  static const Color _kLavender = Color(0xFF9575CD);
  static const Color _kSubText = Color(0xFF78909C);
  static const Color _kDarkIndigo = Color(0xFF1A237E);
  static const Color _kGradientPurple = Color(0xFF6A11CB);
  static const Color _kGradientBlue = Color(0xFF2575FC);
  static const Color _kChipActiveColor = Color(0xFFFFA500);
  static const Color _kGradientLightStart = Color(0xFFE1E5F0);
  static const Color _kGradientLightEnd = Color(0xFFF0F2F5);
  static const Color _kLavenderLight = Color(0xFF9575CD);

  static const Map<String, String> topicEmojis = <String, String>{
    'citywalk': '🏙️',
    'food': '🍲',
    'trekking': '🌲',
    'beach': '🏖️',
    'culture': '🎭',
  };

  final MemoryService _memoryService = MemoryService();
  final SocialService _socialService = SocialService();
  final TextEditingController _searchController = TextEditingController();
  final MapController _osmMapController = MapController();
  ll.LatLng _osmCenter = const ll.LatLng(21.0285, 105.8542);
  double _osmZoom = 12;
  final Set<String> _selectedTopics = <String>{};

  int _markerDetailLevel(double zoom) {
    if (zoom < 11) {
      return 1;
    }
    if (zoom <= 14) {
      return 2;
    }
    return 3;
  }

  Size _markerSizeForLevel(int level) {
    switch (level) {
      case 1:
        return const Size(12, 12);
      case 2:
        return const Size(30, 30);
      default:
        return const Size(60, 60);
    }
  }

  String? get _currentUid => FirebaseAuth.instance.currentUser?.uid;

  bool _isFriendMemory(MemoryModel memory) {
    final String? currentUid = _currentUid;
    if (currentUid == null || currentUid.isEmpty) {
      return false;
    }
    return memory.userId != currentUid;
  }

  Widget _buildPolaroidMarker(
    MemoryModel memory, {
    required bool isFriendMemory,
  }) {
    final Color topicColor = MemoryTopic.color(memory.topic);
    final Color markerBorderColor = _kLavender;
    final int level = _markerDetailLevel(_osmZoom);
    final String markerImageUrl = memory.imageUrl.trim().isNotEmpty
        ? memory.imageUrl.trim()
        : (memory.imageUrls.isNotEmpty ? memory.imageUrls.first : '');

    Widget markerBody;
    if (level == 1) {
      markerBody = Container(
        key: const ValueKey<String>('marker-dot'),
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _kLavender,
          border: Border.all(color: Colors.white, width: 1),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
      );
    } else {
      final bool compact = level == 2;
      final double markerSize = compact ? 30 : 60;
      markerBody = Container(
        key: ValueKey<String>(
          compact ? 'marker-circle-mid' : 'marker-circle-full',
        ),
        width: markerSize,
        height: markerSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          border: Border.all(color: markerBorderColor, width: 3),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: ClipOval(
            child: markerImageUrl.isNotEmpty
                ? _buildSafeNetworkImage(
                    markerImageUrl,
                    width: markerSize - 6,
                    height: markerSize - 6,
                    fit: BoxFit.cover,
                  )
                : Container(
                    color: topicColor.withValues(alpha: 0.18),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.photo,
                      size: compact ? 12 : 20,
                      color: topicColor,
                    ),
                  ),
          ),
        ),
      );
    }

    return RepaintBoundary(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        switchInCurve: Curves.easeInOut,
        switchOutCurve: Curves.easeInOut,
        child: markerBody,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
  }

  Widget _buildSafeNetworkImage(
    String url, {
    required double width,
    required double height,
    BoxFit fit = BoxFit.cover,
  }) {
    return Image.network(
      url,
      width: width,
      height: height,
      fit: fit,
      loadingBuilder:
          (
            BuildContext context,
            Widget child,
            ImageChunkEvent? loadingProgress,
          ) {
            if (loadingProgress == null) {
              return child;
            }
            return Container(
              width: width,
              height: height,
              color: Colors.grey.shade200,
              alignment: Alignment.center,
              child: const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          },
      errorBuilder:
          (BuildContext context, Object error, StackTrace? stackTrace) {
            return Container(
              width: width,
              height: height,
              color: Colors.grey.shade200,
              alignment: Alignment.center,
              child: const Icon(Icons.broken_image, color: Colors.grey),
            );
          },
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
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

  List<MemoryModel> _buildSearchSuggestions(List<MemoryModel> memories) {
    final String keyword = _searchController.text.trim().toLowerCase();
    if (keyword.isEmpty) {
      return <MemoryModel>[];
    }

    final List<MemoryModel> startsWith = <MemoryModel>[];
    final List<MemoryModel> contains = <MemoryModel>[];
    final Set<String> seenTitles = <String>{};

    for (final MemoryModel memory in memories) {
      final String title = memory.title.trim();
      final String titleLower = title.toLowerCase();
      if (titleLower.isEmpty || seenTitles.contains(titleLower)) {
        continue;
      }
      if (titleLower.startsWith(keyword)) {
        startsWith.add(memory);
        seenTitles.add(titleLower);
      } else if (titleLower.contains(keyword)) {
        contains.add(memory);
        seenTitles.add(titleLower);
      }
    }

    return <MemoryModel>[...startsWith, ...contains].take(6).toList();
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
    final ll.LatLng currentPoint = ll.LatLng(
      current.latitude,
      current.longitude,
    );
    _osmMapController.move(currentPoint, 13);
    if (mounted) {
      setState(() => _osmCenter = currentPoint);
    }
  }

  Future<String> _resolveOwnerName(String userId) async {
    try {
      final DocumentSnapshot<Map<String, dynamic>> snapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .get();
      final Map<String, dynamic>? data = snapshot.data();
      final String displayName = (data?['displayName'] as String? ?? '').trim();
      if (displayName.isNotEmpty) {
        return displayName;
      }
      final String email = (data?['email'] as String? ?? '').trim();
      if (email.isNotEmpty) {
        return email;
      }
    } catch (_) {}

    if (userId.length > 8) {
      return 'Bạn ${userId.substring(0, 8)}';
    }
    return 'Bạn bè';
  }

  void _showMemoryBottomSheet(MemoryModel memory) {
    final String? currentUid = _currentUid;
    final bool isOwnMemory = currentUid != null && memory.userId == currentUid;
    final Future<String>? ownerNameFuture = isOwnMemory
        ? null
        : _resolveOwnerName(memory.userId);

    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      clipBehavior: Clip.antiAlias,
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
              if (!isOwnMemory) ...<Widget>[
                const SizedBox(height: 4),
                FutureBuilder<String>(
                  future: ownerNameFuture,
                  builder:
                      (BuildContext context, AsyncSnapshot<String> snapshot) {
                        final String ownerName =
                            snapshot.data?.trim().isNotEmpty == true
                            ? snapshot.data!.trim()
                            : 'Bạn bè';
                        return Row(
                          children: <Widget>[
                            CircleAvatar(
                              radius: 6,
                              backgroundColor: const Color(
                                0xFF9575CD,
                              ).withValues(alpha: 0.2),
                              child: const CircleAvatar(
                                radius: 2.5,
                                backgroundColor: _kLavender,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Kỷ niệm của $ownerName',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: _kSubText,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                ),
              ],
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
                  child: _buildSafeNetworkImage(
                    memory.imageUrls.first,
                    width: double.infinity,
                    height: 180,
                  ),
                ),
              const SizedBox(height: 8),
              Text(memory.description),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _kLavender,
                    side: const BorderSide(color: _kLavender),
                  ),
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
                  label: isOwnMemory
                      ? const Text('Xem chi tiết')
                      : FutureBuilder<String>(
                          future: ownerNameFuture,
                          builder:
                              (
                                BuildContext context,
                                AsyncSnapshot<String> snapshot,
                              ) {
                                final String ownerName =
                                    snapshot.data?.trim().isNotEmpty == true
                                    ? snapshot.data!.trim()
                                    : 'bạn';
                                return Text('Xem hành trình của $ownerName');
                              },
                        ),
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
    return StreamBuilder<List<String>>(
      stream: _socialService.getAcceptedFollowingIdsStream(),
      builder: (BuildContext context, AsyncSnapshot<List<String>> followingSnapshot) {
        if (followingSnapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Không thể tải danh sách bạn bè: ${followingSnapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        final String? currentUid = _currentUid;
        final Set<String> socialUserIds = <String>{
          if (currentUid != null && currentUid.isNotEmpty) currentUid,
          ...(followingSnapshot.data ?? <String>[]),
        };

        return StreamBuilder<List<MemoryModel>>(
          stream: _memoryService.getMemoriesForUserIdsStream(
            socialUserIds.toList(),
          ),
          builder:
              (
                BuildContext context,
                AsyncSnapshot<List<MemoryModel>> snapshot,
              ) {
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

                final List<MemoryModel> allMemories =
                    snapshot.data ?? <MemoryModel>[];
                final List<MemoryModel> memories = _filterMapMemories(
                  allMemories,
                );
                final List<MemoryModel> suggestions = _buildSearchSuggestions(
                  allMemories,
                );

                final double fabBottom =
                    MediaQuery.of(context).padding.bottom +
                    kBottomNavigationBarHeight +
                    12.0;

                return Scaffold(
                  appBar: AppBar(
                    title: SizedBox(
                      height: 40,
                      child: TextField(
                        controller: _searchController,
                        onChanged: (_) => setState(() {}),
                        style: const TextStyle(color: _kLavender),
                        decoration: InputDecoration(
                          hintText: 'Tìm theo tên kỷ niệm...',
                          hintStyle: const TextStyle(color: _kLavender),
                          prefixIcon: const Icon(
                            Icons.search,
                            color: _kLavender,
                          ),
                          isDense: true,
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: const BorderSide(
                              color: _kLavender,
                              width: 0.5,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide(
                              color: _kLavender.withValues(alpha: 0.3),
                              width: 0.5,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: const BorderSide(
                              color: _kLavender,
                              width: 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                    elevation: 0,
                    centerTitle: true,
                    backgroundColor: Colors.white,
                    flexibleSpace: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: <Color>[
                            _kGradientLightStart,
                            _kGradientLightEnd,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),
                    bottom: PreferredSize(
                      preferredSize: const Size.fromHeight(48),
                      child: Container(
                        color: _kGradientLightEnd,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        child: SizedBox(
                          height: 36,
                          child: ListView.builder(
                            clipBehavior: Clip.antiAlias,
                            scrollDirection: Axis.horizontal,
                            itemCount: MemoryTopic.presets.length,
                            itemBuilder: (BuildContext context, int index) {
                              final String topic = MemoryTopic.presets[index];
                              final bool isSelected = _selectedTopics.contains(
                                topic,
                              );
                              final String emoji = topicEmojis[topic] ?? '📍';
                              final String label = MemoryTopic.label(topic);

                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                child: FilterChip(
                                  label: Text(
                                    '$emoji $label',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: isSelected
                                          ? Colors.white
                                          : _kLavender,
                                    ),
                                  ),
                                  onSelected: (bool value) {
                                    setState(() {
                                      if (value) {
                                        _selectedTopics.add(topic);
                                      } else {
                                        _selectedTopics.remove(topic);
                                      }
                                    });
                                  },
                                  selected: isSelected,
                                  backgroundColor: Colors.white,
                                  selectedColor: _kChipActiveColor,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                    side: BorderSide(
                                      color: isSelected
                                          ? _kChipActiveColor
                                          : _kLavender.withValues(alpha: 0.4),
                                      width: isSelected ? 1.5 : 0.8,
                                    ),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                  body: Stack(
                    children: <Widget>[
                      Stack(
                        children: <Widget>[
                          FlutterMap(
                            mapController: _osmMapController,
                            options: MapOptions(
                              initialCenter: _osmCenter,
                              initialZoom: 12,
                              onPositionChanged:
                                  (MapCamera camera, bool hasGesture) {
                                    final ll.LatLng center = camera.center;
                                    final double zoom = camera.zoom;
                                    if ((_osmZoom - zoom).abs() > 0.01 ||
                                        center != _osmCenter) {
                                      setState(() {
                                        _osmCenter = center;
                                        _osmZoom = zoom;
                                      });
                                    }
                                  },
                            ),
                            children: <Widget>[
                              TileLayer(
                                urlTemplate:
                                    'https://{s}.basemaps.cartocdn.com/rastertiles/voyager_nolabels/{z}/{x}/{y}.png',
                                userAgentPackageName:
                                    'vn.edu.tlu.nhom7.lifemap',
                                subdomains: const <String>['a', 'b', 'c'],
                                tileProvider: CancellableNetworkTileProvider(),
                              ),
                              MarkerLayer(
                                markers: memories.map((MemoryModel memory) {
                                  final int level = _markerDetailLevel(
                                    _osmZoom,
                                  );
                                  final Size markerSize = _markerSizeForLevel(
                                    level,
                                  );
                                  final bool isFriendMemory = _isFriendMemory(
                                    memory,
                                  );
                                  return Marker(
                                    width: markerSize.width,
                                    height: markerSize.height,
                                    point: ll.LatLng(memory.lat, memory.lng),
                                    child: GestureDetector(
                                      onTap: () =>
                                          _showMemoryBottomSheet(memory),
                                      child: _buildPolaroidMarker(
                                        memory,
                                        isFriendMemory: isFriendMemory,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ],
                      ),
                      if (_searchController.text.trim().isNotEmpty)
                        Positioned(
                          top: 8,
                          left: 16,
                          right: 16,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 180),
                            child: suggestions.isEmpty
                                ? const SizedBox.shrink()
                                : Container(
                                    key: const ValueKey<String>(
                                      'search-suggestion-list',
                                    ),
                                    constraints: const BoxConstraints(
                                      maxHeight: 190,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.84),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: _kLavender.withValues(
                                          alpha: 0.28,
                                        ),
                                      ),
                                      boxShadow: <BoxShadow>[
                                        BoxShadow(
                                          color: const Color(0x2278909C),
                                          blurRadius: 12,
                                          offset: const Offset(0, 5),
                                        ),
                                      ],
                                    ),
                                    child: ListView.separated(
                                      shrinkWrap: true,
                                      itemCount: suggestions.length,
                                      separatorBuilder:
                                          (BuildContext _, int __) => Divider(
                                            height: 1,
                                            color: _kLavender.withValues(
                                              alpha: 0.16,
                                            ),
                                          ),
                                      itemBuilder:
                                          (BuildContext context, int index) {
                                            final MemoryModel memory =
                                                suggestions[index];
                                            return ListTile(
                                              dense: true,
                                              leading: const Icon(
                                                Icons.history,
                                                color: _kLavender,
                                                size: 18,
                                              ),
                                              title: Text(
                                                memory.title,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  color: _kLavender,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              onTap: () {
                                                _searchController.text =
                                                    memory.title;
                                                _searchController.selection =
                                                    TextSelection.fromPosition(
                                                      TextPosition(
                                                        offset:
                                                            _searchController
                                                                .text
                                                                .length,
                                                      ),
                                                    );
                                                _osmMapController.move(
                                                  ll.LatLng(
                                                    memory.lat,
                                                    memory.lng,
                                                  ),
                                                  14,
                                                );
                                                setState(() {});
                                              },
                                            );
                                          },
                                    ),
                                  ),
                          ),
                        ),
                      Positioned(
                        bottom: fabBottom,
                        right: 16,
                        child: FloatingActionButton(
                          heroTag: 'add_memory_btn',
                          onPressed: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (BuildContext c) =>
                                    const AddMemoryView(),
                              ),
                            );
                          },
                          backgroundColor: _kLavender,
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
                          backgroundColor: _kLavender,
                          foregroundColor: Colors.white,
                          child: const Icon(Icons.my_location),
                        ),
                      ),
                    ],
                  ),
                );
              },
        );
      },
    );
  }
}
