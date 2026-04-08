import 'package:cached_network_image/cached_network_image.dart';
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
  bool _isLoadingSuggestions = false;
  List<Map<String, dynamic>> _searchResults = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _suggestedUsers = <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _loadSuggestions();
  }

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
          .searchUsersHybrid(keyword);
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

  Future<void> _loadSuggestions() async {
    if (!mounted) {
      return;
    }
    setState(() => _isLoadingSuggestions = true);
    try {
      final List<Map<String, dynamic>> results = await _socialService
          .getSuggestedUsers();
      if (!mounted) {
        return;
      }
      setState(() {
        _suggestedUsers = results;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _suggestedUsers = <Map<String, dynamic>>[];
      });
    } finally {
      if (mounted) {
        setState(() => _isLoadingSuggestions = false);
      }
    }
  }

  Future<void> _follow(String uid) async {
    try {
      await _socialService.followUser(uid);
      await _runSearch();
      await _loadSuggestions();
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
        child: ClipOval(
          child: CachedNetworkImage(
            imageUrl: trimmedPhotoUrl,
            width: 50,
            height: 50,
            fit: BoxFit.cover,
            placeholder: (BuildContext context, String imageUrl) => Container(
              color: Colors.grey.shade200,
              alignment: Alignment.center,
              child: const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            errorWidget: (BuildContext context, String imageUrl, Object error) {
              return Container(
                color: _kBrand.withValues(alpha: 0.12),
                alignment: Alignment.center,
                child: Text(initials, style: const TextStyle(color: _kBrand)),
              );
            },
          ),
        ),
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
      child: SizedBox(
        height: 80,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
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
      ),
    );
  }

  Widget _buildSuggestionCard(Map<String, dynamic> item) {
    final String displayName = (item['displayName'] as String? ?? '').trim();
    final String email = (item['email'] as String? ?? '').trim();
    final String city = (item['city'] as String? ?? '').trim();
    final String status = (item['relationshipStatus'] as String? ?? 'none')
        .trim()
        .toLowerCase();
    final String uid = (item['uid'] as String? ?? '').trim();

    final bool canFollow = status != 'accepted' && status != 'pending';
    final String actionText = status == 'accepted'
        ? 'Đã kết nối'
        : (status == 'pending' ? 'Đã gửi' : 'Kết bạn');

    return Container(
      width: 200,
      margin: const EdgeInsets.only(right: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0x2278909C),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: <Widget>[
            _buildAvatar(
              displayName: displayName,
              email: email,
              photoUrl: (item['photoUrl'] as String? ?? '').trim(),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(
                    displayName.isEmpty ? 'Người dùng LifeMap' : displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: _kBrand,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    city.isEmpty ? email : city,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: _kSubText),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 30,
                    child: FilledButton(
                      onPressed: canFollow ? () => _follow(uid) : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: _kBrand,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                      child: Text(actionText),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestedSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Text(
                'Gợi ý bạn bè',
                style: TextStyle(
                  color: _kBrand,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: _loadSuggestions,
                child: const Text('Làm mới'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 112,
            child: _isLoadingSuggestions
                ? const Center(child: CircularProgressIndicator())
                : _suggestedUsers.isEmpty
                ? const Center(
                    child: Text(
                      'Chưa có gợi ý phù hợp lúc này.',
                      style: TextStyle(color: _kSubText),
                    ),
                  )
                : ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _suggestedUsers.length,
                    itemBuilder: (BuildContext context, int index) {
                      return _buildSuggestionCard(_suggestedUsers[index]);
                    },
                  ),
          ),
        ],
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
                          child: SizedBox(
                            height: 80,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: Row(
                                children: <Widget>[
                                  _buildAvatar(
                                    displayName: displayName,
                                    email: email,
                                    photoUrl:
                                        (item['photoUrl'] as String? ?? '')
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
          toolbarHeight: 72,
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF9575CD),
          centerTitle: true,
          title: SizedBox(
            height: 44,
            child: TextField(
              controller: _searchController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _runSearch(),
              decoration: InputDecoration(
                hintText: 'Tìm Gmail hoặc nickname...',
                prefixIcon: const Icon(Icons.search, color: _kBrand),
                filled: true,
                isDense: true,
                fillColor: const Color(0xFFF5F7FA),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(
                    color: _kBrand.withValues(alpha: 0.28),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(
                    color: _kBrand.withValues(alpha: 0.28),
                  ),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(24)),
                  borderSide: BorderSide(color: _kBrand, width: 1),
                ),
              ),
            ),
          ),
          actions: <Widget>[
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: FilledButton(
                onPressed: _isSearching ? null : _runSearch,
                style: FilledButton.styleFrom(backgroundColor: _kBrand),
                child: const Text('Tìm'),
              ),
            ),
          ],
        ),
        body: Column(
          children: <Widget>[
            _buildSuggestedSection(),
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
