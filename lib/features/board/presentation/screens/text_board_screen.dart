import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../core/config/app_theme.dart';
import '../../../../core/ui/app_icons.dart';

/// `cast` = キャスト募集, `guest` = ゲスト依頼
typedef BoardPostKind = String;

const _kKindCast = 'cast';
const _kKindGuest = 'guest';

class TextBoardScreen extends StatefulWidget {
  const TextBoardScreen({super.key});

  @override
  State<TextBoardScreen> createState() => _TextBoardScreenState();
}

class _TextBoardScreenState extends State<TextBoardScreen> {
  bool _posting = false;
  /// 0=すべて, 1=キャスト募集, 2=ゲスト依頼
  int _filterIndex = 0;
  String _searchQuery = '';
  bool _searchMode = false;
  late final TextEditingController _searchController;
  late final FocusNode _searchFocusNode;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _enterSearchMode() {
    setState(() {
      _searchMode = true;
      _searchController.text = _searchQuery;
      _searchController.selection = TextSelection.collapsed(offset: _searchController.text.length);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocusNode.requestFocus();
    });
  }

  void _exitSearchMode() {
    _searchFocusNode.unfocus();
    setState(() {
      _searchMode = false;
      _searchQuery = _searchController.text.trim();
    });
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _searchQuery = '');
  }

  Future<void> _submitPost({
    required String text,
    required BoardPostKind kind,
    required String location,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    if (_posting) return;
    setState(() => _posting = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      String? photoUrl;
      var verified = false;
      var displayName = user?.displayName ?? 'ゲスト';

      if (user != null) {
        final snap = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        final data = snap.data();
        if (data != null) {
          final dn = (data['displayName'] as String?)?.trim();
          if (dn != null && dn.isNotEmpty) displayName = dn;
          photoUrl = (data['photoURL'] as String?)?.trim();
          if (photoUrl != null && photoUrl.isEmpty) photoUrl = null;
          final v = data['isVerified'] ?? data['verified'] ?? data['identityVerified'];
          verified = v is bool ? v : false;
        }
      }

      final loc = location.trim().isEmpty ? '未設定' : location.trim();

      await FirebaseFirestore.instance.collection('boardPosts').add({
        'text': trimmed,
        'createdAt': FieldValue.serverTimestamp(),
        'userId': user?.uid,
        'displayName': displayName,
        'photoURL': photoUrl,
        'isVerified': verified,
        'postKind': kind,
        'location': loc,
      });
      if (!mounted) return;
      Navigator.of(context).maybePop();
      FocusScope.of(context).unfocus();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('投稿に失敗しました: $e')),
      );
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  void _openComposeSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _BoardComposeSheet(
          onSubmit: ({
            required String text,
            required String kind,
            required String location,
          }) =>
              _submitPost(
                text: text,
                kind: kind,
                location: location,
              ),
        );
      },
    );
  }

  bool _matchesFilter(Map<String, dynamic> data) {
    final raw = data['postKind'] as String?;
    final k = (raw == _kKindCast || raw == _kKindGuest) ? raw! : _kKindGuest;
    switch (_filterIndex) {
      case 1:
        return k == _kKindCast;
      case 2:
        return k == _kKindGuest;
      default:
        return true;
    }
  }

  bool _matchesSearch(Map<String, dynamic> data) {
    if (_searchQuery.isEmpty) return true;
    final q = _searchQuery.toLowerCase();
    final text = (data['text'] as String?)?.toLowerCase() ?? '';
    final name = (data['displayName'] as String?)?.toLowerCase() ?? '';
    final loc = (data['location'] as String?)?.toLowerCase() ?? '';
    return text.contains(q) || name.contains(q) || loc.contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final postStream = FirebaseFirestore.instance
        .collection('boardPosts')
        .orderBy('createdAt', descending: true)
        .limit(200)
        .snapshots();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      appBar: AppBar(
        centerTitle: false,
        titleSpacing: 0,
        automaticallyImplyLeading: false,
        leading: _searchMode
            ? IconButton(
                onPressed: _exitSearchMode,
                icon: Icon(
                  AppIcons.arrow_back,
                  color: AppColors.textPrimary,
                ),
                tooltip: '閉じる',
              )
            : null,
        title: _searchMode
            ? Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadii.md),
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    textInputAction: TextInputAction.search,
                    onChanged: (v) => setState(() => _searchQuery = v.trim()),
                    onSubmitted: (_) => _exitSearchMode(),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'キーワードで検索',
                      hintStyle: TextStyle(
                        color: AppColors.textSecondary.withValues(alpha: 0.85),
                        fontWeight: FontWeight.w500,
                      ),
                      prefixIcon: Icon(
                        AppIcons.search,
                        size: 20,
                        color: AppColors.textSecondary,
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              onPressed: _clearSearch,
                              icon: const Icon(AppIcons.clear, size: 20),
                              color: AppColors.textSecondary,
                              tooltip: 'クリア',
                            )
                          : null,
                      filled: true,
                      fillColor: const Color(0xFFF3F4F6),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                    ),
                  ),
                ),
              )
            : Padding(
                padding: const EdgeInsets.only(left: AppSpacing.listHorizontal),
                child: const Text(
                  '掲示板',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                    letterSpacing: -0.4,
                  ),
                ),
              ),
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.white,
        actions: _searchMode
            ? null
            : [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: IconButton(
                    onPressed: _enterSearchMode,
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFFECECEF),
                      foregroundColor: AppColors.textPrimary,
                    ),
                    icon: Icon(
                      AppIcons.search,
                      size: 22,
                    ),
                    tooltip: '検索',
                  ),
                ),
              ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _posting ? null : _openComposeSheet,
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: const CircleBorder(),
        child: Icon(
          AppIcons.edit_note,
          size: 24,
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.listHorizontal,
              0,
              AppSpacing.listHorizontal,
              AppSpacing.md,
            ),
            child: _BoardSegmentedControl(
              selectedIndex: _filterIndex,
              onChanged: (i) => setState(() => _filterIndex = i),
            ),
          ),
          if (_searchQuery.isNotEmpty && !_searchMode)
            Container(
              width: double.infinity,
              color: const Color(0xFFFFF9E6),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '「$_searchQuery」で絞り込み中',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      _clearSearch();
                    },
                    child: const Text('解除'),
                  ),
                ],
              ),
            ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: postStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                }
                if (snapshot.hasError) {
                  return _ErrorState(message: '${snapshot.error}');
                }

                final allDocs = snapshot.data?.docs ?? const [];
                final docs = allDocs.where((d) {
                  final data = d.data();
                  return _matchesFilter(data) && _matchesSearch(data);
                }).toList();

                if (docs.isEmpty) {
                  return _EmptyBoard(
                    hasAnyPosts: allDocs.isNotEmpty,
                    onCompose: _openComposeSheet,
                  );
                }

                return ListView.separated(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.listHorizontal,
                    AppSpacing.sm,
                    AppSpacing.listHorizontal,
                    AppSpacing.bottomForFloatingShell(context),
                  ),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data();
                    final text = (data['text'] as String?)?.trim() ?? '';
                    final name = (data['displayName'] as String?)?.trim();
                    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
                    final photoUrl = (data['photoURL'] as String?)?.trim();
                    final verified = data['isVerified'] == true;
                    final rawKind = data['postKind'] as String?;
                    final kind = (rawKind == _kKindCast || rawKind == _kKindGuest) ? rawKind! : _kKindGuest;
                    final location = (data['location'] as String?)?.trim() ?? '未設定';
                    final uid = data['userId'] as String?;
                    final me = FirebaseAuth.instance.currentUser?.uid;

                    return _PostCard(
                      displayName: (name == null || name.isEmpty) ? '匿名' : name,
                      createdAt: createdAt,
                      text: text,
                      photoUrl: photoUrl,
                      isVerified: verified,
                      postKind: kind,
                      location: location,
                      isMine: uid != null && me != null && uid == me,
                      onDelete: () async {
                        try {
                          await FirebaseFirestore.instance.collection('boardPosts').doc(doc.id).delete();
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('削除に失敗しました: $e')),
                            );
                          }
                        }
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _BoardComposeSheet extends StatefulWidget {
  const _BoardComposeSheet({
    required this.onSubmit,
  });

  final Future<void> Function({
    required String text,
    required String kind,
    required String location,
  }) onSubmit;

  @override
  State<_BoardComposeSheet> createState() => _BoardComposeSheetState();
}

class _BoardComposeSheetState extends State<_BoardComposeSheet> {
  late final TextEditingController _body;
  late final TextEditingController _location;
  String _kind = _kKindGuest;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _body = TextEditingController();
    _location = TextEditingController();
  }

  @override
  void dispose() {
    _body.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> _onSubmit() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      await widget.onSubmit(
        text: _body.text,
        kind: _kind,
        location: _location.text,
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
          boxShadow: [
            BoxShadow(
              color: Color(0x1A000000),
              blurRadius: 24,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.listHorizontal,
              AppSpacing.sm,
              AppSpacing.listHorizontal,
              AppSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                const Text(
                  '新規投稿',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '種類を選んで投稿内容を入力してください',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: _KindChip(
                        label: 'キャスト募集',
                        selected: _kind == _kKindCast,
                        selectedColor: const Color(0xFFFFE4EC),
                        borderColor: const Color(0xFFFFB3C6),
                        textColor: const Color(0xFFC2185B),
                        onTap: () => setState(() => _kind = _kKindCast),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _KindChip(
                        label: 'ゲスト依頼',
                        selected: _kind == _kKindGuest,
                        selectedColor: const Color(0xFFE3F2FD),
                        borderColor: const Color(0xFF90CAF9),
                        textColor: const Color(0xFF1565C0),
                        onTap: () => setState(() => _kind = _kKindGuest),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _location,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'エリア（任意）',
                    hintText: '例: 東京 / 全国(オンライン)',
                    filled: true,
                    fillColor: const Color(0xFFF3F4F6),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadii.md),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadii.md),
                      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _body,
                  minLines: 5,
                  maxLines: 10,
                  textInputAction: TextInputAction.newline,
                  decoration: InputDecoration(
                    labelText: '本文',
                    hintText: '条件や希望を書いてください',
                    alignLabelWithHint: true,
                    filled: true,
                    fillColor: const Color(0xFFF3F4F6),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadii.md),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadii.md),
                      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.all(16),
                  ),
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.45,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  height: 50,
                  child: FilledButton(
                    onPressed: _submitting ? null : _onSubmit,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.textPrimary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadii.md),
                      ),
                      elevation: 0,
                    ),
                    child: _submitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: Colors.white,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                AppIcons.send,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                '投稿する',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BoardSegmentedControl extends StatelessWidget {
  const _BoardSegmentedControl({
    required this.selectedIndex,
    required this.onChanged,
  });

  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    const labels = ['すべて', 'キャスト募集', 'ゲスト依頼'];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFE8E9ED),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: List.generate(3, (i) {
          final selected = selectedIndex == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(i),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: selected
                      ? const [
                          BoxShadow(
                            color: Color(0x14000000),
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  labels[i],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: selected ? AppColors.textPrimary : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _KindChip extends StatelessWidget {
  const _KindChip({
    required this.label,
    required this.selected,
    required this.selectedColor,
    required this.borderColor,
    required this.textColor,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color selectedColor;
  final Color borderColor;
  final Color textColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? selectedColor : const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(AppRadii.md),
            border: Border.all(
              color: selected ? borderColor : AppColors.border.withValues(alpha: 0.5),
              width: selected ? 1.5 : 1,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: selected ? textColor : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyBoard extends StatelessWidget {
  const _EmptyBoard({
    required this.hasAnyPosts,
    required this.onCompose,
  });

  final bool hasAnyPosts;
  final VoidCallback onCompose;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              AppIcons.forum,
              size: 56,
              color: AppColors.textSecondary.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 16),
            Text(
              hasAnyPosts ? '該当する投稿がありません' : 'まだ投稿がありません',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              hasAnyPosts ? 'タブや検索条件を変えてみてください' : '右下のボタンから投稿してみましょう',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.45,
                color: AppColors.textSecondary.withValues(alpha: 0.95),
              ),
            ),
            if (!hasAnyPosts) ...[
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                onPressed: onCompose,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.textPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadii.md),
                  ),
                  elevation: 0,
                ),
                icon: const Icon(AppIcons.edit_note, size: 20),
                label: const Text(
                  '投稿する',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.listHorizontal),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              AppIcons.error_outline,
              size: 48,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 12),
            Text(
              '読み込みに失敗しました',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard({
    required this.displayName,
    required this.createdAt,
    required this.text,
    required this.photoUrl,
    required this.isVerified,
    required this.postKind,
    required this.location,
    required this.isMine,
    required this.onDelete,
  });

  final String displayName;
  final DateTime? createdAt;
  final String text;
  final String? photoUrl;
  final bool isVerified;
  final BoardPostKind postKind;
  final String location;
  final bool isMine;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    final relative = _relativeTimeJa(createdAt);
    final initial = displayName.isNotEmpty
        ? String.fromCharCode(displayName.runes.first)
        : '?';

    final isCast = postKind == _kKindCast;
    final roleBg = isCast ? const Color(0xFFFFE4EC) : const Color(0xFFE3F2FD);
    final roleFg = isCast ? const Color(0xFFC2185B) : const Color(0xFF1565C0);
    final roleLabel = isCast ? 'キャスト' : 'ゲスト';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE4E6EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Avatar(photoUrl: photoUrl, initial: initial),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        Text(
                          displayName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (isVerified)
                          Icon(AppIcons.verified, size: 16, color: Colors.blue.shade600),
                        _SmallPill(
                          background: roleBg,
                          foreground: roleFg,
                          child: Text(
                            roleLabel,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        _SmallPill(
                          background: const Color(0xFFF0F1F4),
                          foreground: AppColors.textSecondary,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                AppIcons.location_on,
                                size: 12,
                              ),
                              const SizedBox(width: 2),
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 140),
                                child: Text(
                                  location,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (relative.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          relative,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary.withValues(alpha: 0.9),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                icon: Icon(
                  AppIcons.more_horiz,
                  color: AppColors.textSecondary,
                  size: 22,
                ),
                onSelected: (value) async {
                  if (value == 'delete' && isMine) {
                    await onDelete();
                  }
                  if (value == 'report') {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('報告は近日対応予定です')),
                      );
                    }
                  }
                },
                itemBuilder: (context) => [
                  if (isMine)
                    const PopupMenuItem(value: 'delete', child: Text('削除')),
                  const PopupMenuItem(value: 'report', child: Text('報告')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            text,
            style: const TextStyle(
              fontSize: 15,
              height: 1.55,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.photoUrl, required this.initial});

  final String? photoUrl;
  final String initial;

  @override
  Widget build(BuildContext context) {
    final url = photoUrl;
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFE8EAEF)),
        color: const Color(0xFFF5F6F8),
      ),
      clipBehavior: Clip.antiAlias,
      child: url != null && url.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => _initial(initial),
            )
          : _initial(initial),
    );
  }

  Widget _initial(String i) {
    return Center(
      child: Text(
        i,
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 18,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

class _SmallPill extends StatelessWidget {
  const _SmallPill({
    required this.background,
    required this.foreground,
    required this.child,
  });

  final Color background;
  final Color foreground;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle.merge(
      style: TextStyle(color: foreground),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
        child: child,
      ),
    );
  }
}

String _relativeTimeJa(DateTime? at) {
  if (at == null) return '';
  final now = DateTime.now();
  final diff = now.difference(at);
  if (diff.isNegative) return 'たった今';
  if (diff.inMinutes < 1) return 'たった今';
  if (diff.inMinutes < 60) return '${diff.inMinutes}分前';
  if (diff.inHours < 24) return '${diff.inHours}時間前';
  if (diff.inDays < 7) return '${diff.inDays}日前';
  return '${at.month}/${at.day}';
}
