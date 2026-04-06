import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import 'app_icons.dart';

/// Writes to Firestore `users/{currentUid}.likedUserIds` (array of user ids), same merge pattern as [likedServiceIds].
Future<void> toggleLikedUserId(
  BuildContext context,
  String myUid,
  String targetUserId,
  bool currentlyLiked,
) async {
  try {
    await FirebaseFirestore.instance.collection('users').doc(myUid).set(
      {
        'likedUserIds': currentlyLiked
            ? FieldValue.arrayRemove([targetUserId])
            : FieldValue.arrayUnion([targetUserId]),
      },
      SetOptions(merge: true),
    );
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('いいねを更新できませんでした')),
      );
    }
  }
}

/// Circular heart for user cards / profile — syncs with [toggleLikedUserId].
class UserFavoriteButton extends StatelessWidget {
  const UserFavoriteButton({
    super.key,
    required this.targetUserId,
    this.compact = true,
    this.backgroundAlpha = 0.35,
  });

  final String targetUserId;
  final bool compact;
  final double backgroundAlpha;

  @override
  Widget build(BuildContext context) {
    final me = FirebaseAuth.instance.currentUser;
    final size = compact ? 36.0 : 44.0;
    final iconSize = compact ? 18.0 : 22.0;

    Widget circleButton({required VoidCallback onPressed, required Icon icon}) {
      return SizedBox(
        width: size,
        height: size,
        child: Material(
          color: Colors.black.withValues(alpha: backgroundAlpha),
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: IconButton(
            padding: EdgeInsets.zero,
            constraints: BoxConstraints.tight(Size(size, size)),
            icon: icon,
            onPressed: onPressed,
          ),
        ),
      );
    }

    if (me == null) {
      return circleButton(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ログインが必要です')),
          );
        },
        icon: Icon(AppIcons.favorite_border, size: iconSize, color: Colors.white),
      );
    }
    if (me.uid == targetUserId) {
      return circleButton(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('自分自身にはいいねできません')),
          );
        },
        icon: Icon(AppIcons.favorite_border, size: iconSize, color: Colors.white),
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(me.uid).snapshots(),
      builder: (context, snapshot) {
        final raw = snapshot.data?.data()?['likedUserIds'];
        final liked = raw is List ? raw.whereType<String>().toSet() : <String>{};
        final isLiked = liked.contains(targetUserId);

        return circleButton(
          onPressed: () => toggleLikedUserId(
            context,
            me.uid,
            targetUserId,
            isLiked,
          ),
          icon: Icon(
            isLiked ? AppIcons.favorite : AppIcons.favorite_border,
            size: iconSize,
            color: isLiked ? AppColors.primary : Colors.white,
          ),
        );
      },
    );
  }
}
