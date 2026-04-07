import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../services/social_service.dart';

class FriendsView extends StatefulWidget {
  const FriendsView({super.key});

  @override
  State<FriendsView> createState() => _FriendsViewState();
}

class _FriendsViewState extends State<FriendsView> {
  static const Color _kBrand = Color(0xFF9575CD);
  static const Color _kSubText = Color(0xFF78909C);

  final SocialService _socialService = SocialService();
  final TextEditingController _searchController = TextEditingController();

  bool _isSearching = false;
  bool _showSearchOverlay = false;
  List<Map<String, dynamic>> _searchResults = <Map<String, dynamic>>[];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _runSearch() async {
    final String keyword = _searchController.text.trim();
    if (keyword.isEmpty) {
      setState(() {
        _showSearchOverlay = false;
        _searchResults = <Map<String, dynamic>>[];
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _showSearchOverlay = true;
    });

    try {
      final List<Map<String, dynamic>> results = await _socialService
          .searchUsersByEmail(keyword);
      if (!mounted) {
        return;
      }
      setState(() {
        _searchResults = results;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi tìm kiếm: $e')));
    } finally {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  Future<void> _follow(String uid) async {
    try {
      await _socialService.followUser(uid);
      await _runSearch();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã gửi yêu cầu theo dõi.')));
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Không thể theo dõi: $e')));
    }
  }

  Future<void> _accept(String uid) async {
    try {
      await _socialService.acceptFollowRequest(uid);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã chấp nhận kết nối.')));
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Không thể chấp nhận: $e')));
    }
  }

  Widget _buildSearchAction(Map<String, dynamic> item) {
    final String status = (item['relationshipStatus'] as String? ?? 'none')
        .trim()
        .toLowerCase();
    if (status == 'accepted') {
      return FilledButton(
        onPressed: null,
        style: FilledButton.styleFrom(backgroundColor: _kBrand),
        child: const Text('Đã kết nối'),
      );
    }
    if (status == 'pending') {
      return OutlinedButton(
        onPressed: null,
        style: OutlinedButton.styleFrom(foregroundColor: _kBrand),
        child: const Text('Đã gửi'),
      );
    }
    return FilledButton(
      onPressed: () => _follow((item['uid'] as String? ?? '').trim()),
      style: FilledButton.styleFrom(backgroundColor: _kBrand),
      child: const Text('Kết bạn'),
    );
  }

  Widget _buildAvatar({
    required String displayName,
    required String email,
    String photoUrl = '',
  }) {
    final String initials = displayName.isNotEmpty
        ? displayName[0].toUpperCase()
        : (email.isNotEmpty ? email[0].toUpperCase() : 'U');

    final String trimmedPhotoUrl = photoUrl.trim();

    if (trimmedPhotoUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 25,
        backgroundColor: Colors.grey[200],
        backgroundImage: NetworkImage(trimmedPhotoUrl),
        onBackgroundImageError: (Object exception, StackTrace? stackTrace) {
          // Fallback when image fails to load
        },
        child: const SizedBox.shrink(),
      );
    }

    return CircleAvatar(
      radius: 25,
      backgroundColor: _kBrand.withValues(alpha: 0.12),
      foregroundColor: _kBrand,
      child: Text(initials),
    );
  }

  Widget _buildProfileCard(
    Map<String, dynamic> item, {
    bool canAcceptPending = false,
  }) {
    final String uid = (item['uid'] as String? ?? '').trim();
    final String displayName = (item['displayName'] as String? ?? '').trim();
    final String email = (item['email'] as String? ?? '').trim();
    final String photoUrl = (item['photoUrl'] as String? ?? '').trim();
    final String status = (item['status'] as String? ?? '')
        .trim()
        .toLowerCase();

    Widget trailing;
    if (canAcceptPending && status == 'pending') {
      trailing = FilledButton(
        onPressed: () => _accept(uid),
        style: FilledButton.styleFrom(backgroundColor: _kBrand),
        child: const Text('Chấp nhận'),
      );
    } else {
      trailing = FilledButton(
        onPressed: null,
        style: FilledButton.styleFrom(backgroundColor: _kBrand),
        child: Text(status == 'accepted' ? 'Đã kết nối' : 'Đang chờ'),
      );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.white,
      elevation: 0.8,
      shadowColor: const Color(0x2278909C),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: <Widget>[
            _buildAvatar(
              displayName: displayName,
              email: email,
              photoUrl: photoUrl,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    displayName.isEmpty ? 'Người dùng LifeMap' : displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _kSubText),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            trailing,
          ],
        ),
      ),
    );
  }

  Widget _buildStreamList(
    Stream<List<Map<String, dynamic>>> stream, {
    bool canAcceptPending = false,
  }) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: stream,
      builder:
          (
            BuildContext context,
            AsyncSnapshot<List<Map<String, dynamic>>> snapshot,
          ) {
            if (snapshot.hasError) {
              return Center(child: Text('Lỗi tải dữ liệu: ${snapshot.error}'));
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final List<Map<String, dynamic>> items =
                snapshot.data ?? <Map<String, dynamic>>[];
            if (items.isEmpty) {
              return const Center(child: Text('Chưa có dữ liệu.'));
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              itemBuilder: (BuildContext context, int index) {
                return _buildProfileCard(
                  items[index],
                  canAcceptPending: canAcceptPending,
                );
              },
            );
          },
    );
  }

  Widget _buildSearchOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.white.withValues(alpha: 0.94),
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: <Widget>[
                  Text(
                    'Kết quả tìm kiếm',
                    style: TextStyle(
                      color: _kBrand,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _showSearchOverlay = false;
                        _searchResults = <Map<String, dynamic>>[];
                      });
                    },
                    icon: const Icon(Icons.close),
                    label: const Text('Đóng'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isSearching
                  ? const Center(child: CircularProgressIndicator())
                  : _searchResults.isEmpty
                  ? const Center(
                      child: Text('Không tìm thấy người dùng phù hợp.'),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: _searchResults.length,
                      itemBuilder: (BuildContext context, int index) {
                        final Map<String, dynamic> item = _searchResults[index];
                        final String displayName =
                            (item['displayName'] as String? ?? '').trim();
                        final String email = (item['email'] as String? ?? '')
                            .trim();

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          color: Colors.white,
                          elevation: 0.8,
                          shadowColor: const Color(0x2278909C),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: <Widget>[
                                _buildAvatar(
                                  displayName: displayName,
                                  email: email,
                                  photoUrl: (item['photoUrl'] as String? ?? '')
                                      .trim(),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        displayName.isEmpty
                                            ? 'Người dùng LifeMap'
                                            : displayName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        email,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _buildSearchAction(item),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF0F2F5),
        appBar: AppBar(
          toolbarHeight: 60,
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF9575CD),
          centerTitle: true,
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1),
            child: Divider(height: 1, thickness: 1, color: Color(0x2278909C)),
          ),
          title: Text(
            'Bạn bè',
            style: const TextStyle(
              color: Color(0xFF9575CD),
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ),
        body: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: const Color(0x2278909C),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.search,
                            onSubmitted: (_) => _runSearch(),
                            decoration: InputDecoration(
                              hintText: 'Nhập email để tìm...',
                              prefixIcon: const Icon(
                                Icons.search,
                                color: _kBrand,
                              ),
                              filled: true,
                              isDense: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: _kBrand.withValues(alpha: 0.4),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: _kBrand.withValues(alpha: 0.4),
                                ),
                              ),
                              focusedBorder: const OutlineInputBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(12),
                                ),
                                borderSide: BorderSide(
                                  color: _kBrand,
                                  width: 1.2,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        FilledButton(
                          onPressed: _isSearching ? null : _runSearch,
                          style: FilledButton.styleFrom(
                            backgroundColor: _kBrand,
                          ),
                          child: const Text('Tìm'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Container(
              color: Colors.white,
              child: const TabBar(
                dividerColor: Colors.transparent,
                overlayColor: WidgetStatePropertyAll<Color>(Color(0x149575CD)),
                labelColor: _kBrand,
                unselectedLabelColor: Color(0xFF78909C),
                indicatorColor: _kBrand,
                tabs: <Widget>[
                  Tab(text: 'Đang theo dõi'),
                  Tab(text: 'Theo dõi bạn'),
                ],
              ),
            ),
            Expanded(
              child: Stack(
                children: <Widget>[
                  TabBarView(
                    children: <Widget>[
                      _buildStreamList(
                        _socialService.getFollowingProfilesStream(
                          status: 'accepted',
                        ),
                        canAcceptPending: false,
                      ),
                      _buildStreamList(
                        _socialService.getFollowersProfilesStream(),
                        canAcceptPending: true,
                      ),
                    ],
                  ),
                  if (_showSearchOverlay) _buildSearchOverlay(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
