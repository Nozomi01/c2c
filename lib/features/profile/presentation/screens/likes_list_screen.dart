import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/app_theme.dart';
import '../../../services/domain/models/service.dart';
import '../providers/profile_mode_provider.dart';

const int _kLikesPageSize = 20;

/// 購入者: いいねしたサービス一覧 / 出品者: いいねしてくれたユーザー
class LikesListScreen extends ConsumerWidget {
  const LikesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(profileModeProvider);
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: _likesAppBar(context, title: 'いいね'),
        body: const Center(child: Text('ログインが必要です')),
      );
    }

    if (mode == ProfileMode.buyer) {
      return _BuyerFavoritesPage(uid: user.uid);
    }
    return _SellerLikersPage(myUid: user.uid);
  }
}

PreferredSizeWidget _likesAppBar(BuildContext context, {required String title}) {
  return AppBar(
    leading: IconButton(
      icon: const Icon(Icons.chevron_left),
      onPressed: () => Navigator.of(context).pop(),
    ),
    title: Text(
      title,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontWeight: FontWeight.bold,
        fontSize: 18,
      ),
    ),
    centerTitle: true,
    backgroundColor: Colors.white,
    elevation: 0,
    surfaceTintColor: Colors.white,
  );
}

// ─── Buyer: liked services, paginated by id chunks ─────────────────────────

class _BuyerFavoritesPage extends StatelessWidget {
  const _BuyerFavoritesPage({required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _likesAppBar(context, title: 'いいねリスト'),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
        builder: (context, userSnap) {
          if (userSnap.connectionState == ConnectionState.waiting && !userSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (userSnap.hasError) {
            return Center(child: Text('読み込みに失敗しました: ${userSnap.error}'));
          }

          final data = userSnap.data?.data() ?? <String, dynamic>{};
          final raw = data['likedServiceIds'];
          final ids = raw is List ? raw.whereType<String>().toList() : <String>[];

          if (ids.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.favorite_border, size: 64, color: AppColors.textSecondary),
                  SizedBox(height: 16),
                  Text(
                    'いいねしたサービスはありません',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
                  ),
                ],
              ),
            );
          }

          return _BuyerFavoritesScrollBody(allIds: ids);
        },
      ),
    );
  }
}

class _BuyerFavoritesScrollBody extends StatefulWidget {
  const _BuyerFavoritesScrollBody({required this.allIds});

  final List<String> allIds;

  @override
  State<_BuyerFavoritesScrollBody> createState() => _BuyerFavoritesScrollBodyState();
}

class _BuyerFavoritesScrollBodyState extends State<_BuyerFavoritesScrollBody> {
  final ScrollController _scrollController = ScrollController();
  final List<Service> _items = [];
  int _nextIndex = 0;
  bool _loading = true;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMore());
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_hasMore || _loading) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 280) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    setState(() => _loading = true);

    try {
      final ids = widget.allIds;
      if (_nextIndex >= ids.length) {
        setState(() {
          _hasMore = false;
          _loading = false;
        });
        return;
      }

      final end = (_nextIndex + _kLikesPageSize).clamp(0, ids.length);
      final slice = ids.sublist(_nextIndex, end);
      _nextIndex = end;

      final fetched = await _fetchServicesByIds(slice);
      if (mounted) {
        setState(() {
          _items.addAll(fetched);
          _hasMore = _nextIndex < ids.length;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  static Future<List<Service>> _fetchServicesByIds(List<String> serviceIds) async {
    if (serviceIds.isEmpty) return const [];
    final col = FirebaseFirestore.instance.collection('services');
    final out = <Service>[];

    const chunkSize = 30;
    for (var i = 0; i < serviceIds.length; i += chunkSize) {
      final chunk = serviceIds.sublist(
        i,
        i + chunkSize > serviceIds.length ? serviceIds.length : i + chunkSize,
      );
      final snap = await col.where(FieldPath.documentId, whereIn: chunk).get();
      for (final doc in snap.docs) {
        try {
          out.add(Service.fromFirestore(doc));
        } catch (_) {}
      }
    }

    final order = {for (var i = 0; i < serviceIds.length; i++) serviceIds[i]: i};
    out.sort((a, b) => (order[a.id] ?? 0).compareTo(order[b.id] ?? 0));
    return out;
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty && _loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_items.isEmpty && !_loading) {
      return const Center(
        child: Text(
          'サービス情報を読み込めませんでした',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
      );
    }

    return ListView.separated(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _items.length + (_hasMore ? 1 : 0),
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        if (index >= _items.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final s = _items[index];
        final img = s.images.isNotEmpty ? s.images.first : null;
        return InkWell(
          onTap: () => context.push('/services/${s.id}'),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 72,
                    height: 72,
                    child: img == null || img.isEmpty
                        ? Container(
                            color: AppColors.primarySoft,
                            child: const Icon(Icons.image, color: AppColors.primary),
                          )
                        : CachedNetworkImage(
                            imageUrl: img,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => Container(
                              color: AppColors.primarySoft,
                              child: const Icon(Icons.broken_image_outlined,
                                  color: AppColors.primary),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '¥${NumberFormat('#,###').format(s.price)}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.textSecondary),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── Seller: likers discovered in service-id batches, display paged ────────

class _SellerLikersPage extends StatelessWidget {
  const _SellerLikersPage({required this.myUid});

  final String myUid;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _likesAppBar(context, title: 'いいねしてくれたユーザー'),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('services')
            .where('ownerId', isEqualTo: myUid)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, serviceSnap) {
          if (serviceSnap.connectionState == ConnectionState.waiting && !serviceSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (serviceSnap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'サービス一覧の取得に失敗しました: ${serviceSnap.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final docs = serviceSnap.data?.docs ?? const [];
          final serviceIds = docs.map((d) => d.id).toList();

          if (serviceIds.isEmpty) {
            return const Center(
              child: Text(
                '出品中のサービスがないため、いいねユーザーは表示できません',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
            );
          }

          return _SellerLikersScrollBody(
            key: ValueKey(serviceIds.join(',')),
            serviceIds: serviceIds,
            myUid: myUid,
          );
        },
      ),
    );
  }
}

class _SellerLikersScrollBody extends StatefulWidget {
  const _SellerLikersScrollBody({
    super.key,
    required this.serviceIds,
    required this.myUid,
  });

  final List<String> serviceIds;
  final String myUid;

  @override
  State<_SellerLikersScrollBody> createState() => _SellerLikersScrollBodyState();
}

class _SellerLikersScrollBodyState extends State<_SellerLikersScrollBody> {
  final ScrollController _scrollController = ScrollController();

  /// Unique likers found so far (merged from processed service batches).
  final Map<String, _LikedByUser> _likerById = {};

  /// How many service ids at the start of [widget.serviceIds] have been queried.
  int _processedServiceCount = 0;

  /// How many rows to show (increments by 20).
  int _visibleCount = _kLikesPageSize;

  bool _loading = false;

  /// First discovery pass finished (avoid empty flash before bootstrap).
  bool _ready = false;

  /// All services processed and no more users can appear.
  bool _discoveryExhausted = false;

  static const int _servicesPerDiscoveryBatch = 10;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_loading) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 280) {
      _loadMoreVisible();
    }
  }

  Future<void> _bootstrap() async {
    await _discoverUntilCount(_kLikesPageSize);
    if (mounted) setState(() => _ready = true);
  }

  List<_LikedByUser> get _sortedLikers {
    final list = _likerById.values.toList()
      ..sort((a, b) => a.displayName.compareTo(b.displayName));
    return list;
  }

  /// Query more services until we have at least [minCount] unique likers or run out.
  Future<void> _discoverUntilCount(int minCount) async {
    if (_discoveryExhausted) return;

    while (_likerById.length < minCount && !_discoveryExhausted) {
      if (_processedServiceCount >= widget.serviceIds.length) {
        _discoveryExhausted = true;
        break;
      }

      final end = (_processedServiceCount + _servicesPerDiscoveryBatch)
          .clamp(0, widget.serviceIds.length);
      final chunk = widget.serviceIds.sublist(_processedServiceCount, end);
      _processedServiceCount = end;

      final batchUsers = await _fetchLikersForServiceIds(chunk, widget.myUid);
      for (final u in batchUsers) {
        _likerById[u.uid] = u;
      }

      if (_processedServiceCount >= widget.serviceIds.length) {
        _discoveryExhausted = true;
      }
    }
  }

  Future<void> _loadMoreVisible() async {
    if (_loading) return;

    final sorted = _sortedLikers;
    if (_visibleCount < sorted.length) {
      setState(() => _visibleCount += _kLikesPageSize);
      return;
    }

    if (_discoveryExhausted) return;

    setState(() => _loading = true);
    await _discoverUntilCount(sorted.length + _kLikesPageSize);
    if (mounted) {
      setState(() {
        _visibleCount += _kLikesPageSize;
        _loading = false;
      });
    }
  }

  static Future<List<_LikedByUser>> _fetchLikersForServiceIds(
    List<String> serviceIds,
    String myUid,
  ) async {
    if (serviceIds.isEmpty) return const [];

    final usersCol = FirebaseFirestore.instance.collection('users');
    final userSnaps = await Future.wait(
      serviceIds.map(
        (serviceId) =>
            usersCol.where('likedServiceIds', arrayContains: serviceId).get(),
      ),
    );

    final userIdSet = <String>{};
    for (final snap in userSnaps) {
      for (final doc in snap.docs) {
        if (doc.id != myUid) userIdSet.add(doc.id);
      }
    }

    if (userIdSet.isEmpty) return const [];

    final userDocs = await Future.wait(
      userIdSet.map((id) => usersCol.doc(id).get()),
    );

    final users = <_LikedByUser>[];
    for (final d in userDocs) {
      if (!d.exists) continue;
      users.add(_LikedByUser.fromDoc(d));
    }
    return users;
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_bootstrapRanEmpty()) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.favorite_border, size: 64, color: AppColors.textSecondary),
            SizedBox(height: 16),
            Text(
              'いいねしてくれているユーザーはいません',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
            ),
          ],
        ),
      );
    }

    final sorted = _sortedLikers;
    final showCount = _visibleCount.clamp(0, sorted.length);
    final hasMoreList = showCount < sorted.length || !_discoveryExhausted;

    return ListView.separated(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: showCount + ((hasMoreList && _loading) ? 1 : 0),
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        if (index >= showCount) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final u = sorted[index];
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: ClipOval(
            child: SizedBox(
              width: 44,
              height: 44,
              child: u.photoUrl == null || u.photoUrl!.isEmpty
                  ? Container(
                      color: AppColors.primarySoft,
                      alignment: Alignment.center,
                      child: Text(
                        u.displayName.isNotEmpty ? u.displayName[0] : '?',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  : CachedNetworkImage(
                      imageUrl: u.photoUrl!,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(
                        color: AppColors.primarySoft,
                        alignment: Alignment.center,
                        child: const Icon(Icons.person, color: AppColors.primary),
                      ),
                    ),
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  u.displayName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (u.verified) ...[
                const SizedBox(width: 6),
                const Icon(Icons.verified, size: 16, color: Colors.green),
              ],
            ],
          ),
          subtitle: Text(
            u.reviewCount > 0 ? 'レビュー: ${u.reviewCount}' : 'レビューなし',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
        );
      },
    );
  }

  bool _bootstrapRanEmpty() {
    return _likerById.isEmpty && _discoveryExhausted && !_loading;
  }
}

class _LikedByUser {
  const _LikedByUser({
    required this.uid,
    required this.displayName,
    required this.photoUrl,
    required this.reviewCount,
    required this.verified,
  });

  final String uid;
  final String displayName;
  final String? photoUrl;
  final int reviewCount;
  final bool verified;

  factory _LikedByUser.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final name = (data['displayName'] as String?)?.trim();
    final email = (data['email'] as String?)?.trim();
    final fallback =
        email != null && email.isNotEmpty && email.contains('@') ? email.split('@').first : 'ユーザー';
    final displayName = (name == null || name.isEmpty) ? fallback : name;

    final reviewCountRaw = data['reviewCount'];
    final verifiedRaw = data['isVerified'] ?? data['verified'] ?? data['identityVerified'];

    final reviewCount = reviewCountRaw is num ? reviewCountRaw.toInt() : 0;
    final verified = verifiedRaw is bool ? verifiedRaw : false;

    final photoUrl = (data['photoURL'] as String?)?.trim();

    return _LikedByUser(
      uid: doc.id,
      displayName: displayName,
      photoUrl: photoUrl,
      reviewCount: reviewCount,
      verified: verified,
    );
  }
}
