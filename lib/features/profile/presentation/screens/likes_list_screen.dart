import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../core/config/app_theme.dart';

class LikesListScreen extends StatelessWidget {
  const LikesListScreen({super.key});

  Future<List<_LikedByUser>> _fetchLikers(List<String> serviceIds, String myUid) async {
    if (serviceIds.isEmpty) return const [];

    final usersCol = FirebaseFirestore.instance.collection('users');

    // Reverse lookup:
    // Find users where `likedServiceIds` contains each of my service ids.
    final userSnaps = await Future.wait(
      serviceIds.map(
        (serviceId) => usersCol
            .where('likedServiceIds', arrayContains: serviceId)
            .get(),
      ),
    );

    final userIdSet = <String>{};
    for (final snap in userSnaps) {
      for (final doc in snap.docs) {
        // Exclude myself if I ever liked my own service.
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

    users.sort((a, b) => a.displayName.compareTo(b.displayName));
    return users;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'いいねしてくれたユーザー',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('ログインが必要です'));
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('services')
          .where('ownerId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, serviceSnap) {
        final docs = serviceSnap.data?.docs ?? const [];
        final serviceIds = docs.map((d) => d.id).toList();

        if (serviceIds.isEmpty) {
          return const Center(
            child: Text(
              'あなたのサービスにいいねはまだありません',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
          );
        }

        return FutureBuilder<List<_LikedByUser>>(
          future: _fetchLikers(serviceIds, user.uid),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return Center(
                child: Text('読み込みに失敗しました: ${snap.error}'),
              );
            }

            final likers = snap.data ?? const <_LikedByUser>[];
            if (likers.isEmpty) {
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

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: likers.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final u = likers[index];
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
          },
        );
      },
    );
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
