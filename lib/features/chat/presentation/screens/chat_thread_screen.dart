import 'dart:io';
import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/app_theme.dart';
import '../../data/chat_repository.dart';
import '../../domain/models/message.dart';
import '../providers/chat_providers.dart';

class ChatThreadScreen extends ConsumerStatefulWidget {
  const ChatThreadScreen({super.key, required this.chatId});

  final String chatId;

  @override
  ConsumerState<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends ConsumerState<ChatThreadScreen> {
  final _controller = TextEditingController();
  bool _hasMarkedRead = false;
  bool _sendingAttachment = false;
  final ScrollController _scrollController = ScrollController();

  final List<Message> _messages = [];
  bool _initialLoading = true;
  bool _loadingMore = false;
  bool _hasMore = true;

  // Used for pagination (descending query uses createdAt desc).
  DocumentSnapshot<Map<String, dynamic>>? _oldestDescDoc;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _latestSub;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadInitialMessages();
    _startLatestSubscription();
  }

  void _onScroll() {
    if (!_hasMore || _loadingMore) return;
    if (!_scrollController.hasClients) return;

    // Because we display messages in chronological order (reverse: false),
    // older messages are at the top. Trigger pagination when user scrolls near top.
    if (_scrollController.position.pixels <= 200) {
      _loadMoreMessages();
    }
  }

  Future<void> _loadInitialMessages() async {
    setState(() {
      _initialLoading = true;
      _hasMore = true;
      _messages.clear();
      _oldestDescDoc = null;
    });

    try {
      final col = FirebaseFirestore.instance.collection('messages');
      final snap = await col
          .where('chatId', isEqualTo: widget.chatId)
          .orderBy('createdAt', descending: true)
          .limit(20)
          .get();

      final docs = snap.docs;
      final messagesDesc = docs.map((d) => Message.fromFirestore(d)).toList();
      final messagesAsc = messagesDesc.reversed.toList();

      setState(() {
        _messages
          ..clear()
          ..addAll(messagesAsc);
        _oldestDescDoc = docs.isNotEmpty ? docs.last : null; // oldest in this page
        _hasMore = docs.length == 20;
        _initialLoading = false;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scrollController.hasClients) return;
        // Jump to bottom (newest).
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _initialLoading = false);
    }
  }

  void _startLatestSubscription() {
    _latestSub?.cancel();
    _latestSub = FirebaseFirestore.instance
        .collection('messages')
        .where('chatId', isEqualTo: widget.chatId)
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots()
        .listen((snap) {
      if (_loadingMore) return;
      final messagesDesc = snap.docs.map((d) => Message.fromFirestore(d)).toList();
      final messagesAsc = messagesDesc.reversed.toList();

      setState(() {
        // Merge: update existing messages by id and add any missing ones.
        final map = <String, Message>{
          for (final m in _messages) m.id: m,
        };
        for (final m in messagesAsc) {
          map[m.id] = m;
        }
        final combined = map.values.toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
        _messages
          ..clear()
          ..addAll(combined);
      });
    });
  }

  Future<void> _loadMoreMessages() async {
    if (_loadingMore || !_hasMore) return;
    if (_oldestDescDoc == null) return;
    if (!_scrollController.hasClients) return;

    setState(() => _loadingMore = true);

    // Track scroll extent so we can keep the visible messages stable.
    final oldMaxScrollExtent = _scrollController.position.maxScrollExtent;

    try {
      final col = FirebaseFirestore.instance.collection('messages');
      final snap = await col
          .where('chatId', isEqualTo: widget.chatId)
          .orderBy('createdAt', descending: true)
          .startAfterDocument(_oldestDescDoc!)
          .limit(20)
          .get();

      final docs = snap.docs;
      if (docs.isEmpty) {
        setState(() {
          _hasMore = false;
          _loadingMore = false;
        });
        return;
      }

      final messagesDesc = docs.map((d) => Message.fromFirestore(d)).toList();
      final messagesAsc = messagesDesc.reversed.toList();

      final existingIds = _messages.map((m) => m.id).toSet();
      final newMessages = messagesAsc.where((m) => !existingIds.contains(m.id)).toList();

      final newOldestDescDoc = docs.last;

      setState(() {
        _messages.insertAll(0, newMessages);
        _oldestDescDoc = newOldestDescDoc;
        _hasMore = docs.length == 20;
        _loadingMore = false;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scrollController.hasClients) return;
        final newMaxScrollExtent = _scrollController.position.maxScrollExtent;
        final diff = newMaxScrollExtent - oldMaxScrollExtent;
        final target = (_scrollController.offset + diff).clamp(
          0.0,
          _scrollController.position.maxScrollExtent,
        );
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _latestSub?.cancel();
    super.dispose();
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  /// Each calendar day (local) gets a [DateTime] marker, then [Message]s for that day.
  List<Object> _chatItemsWithDayDividers(List<Message> messages) {
    if (messages.isEmpty) return [];
    final out = <Object>[];
    DateTime? lastDay;
    for (final m in messages) {
      final day = DateUtils.dateOnly(m.createdAt.toLocal());
      if (lastDay == null || day != lastDay) {
        out.add(day);
        lastDay = day;
      }
      out.add(m);
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: _buildAppBar(context, ''),
        body: const Center(child: Text('ログインが必要です')),
      );
    }

    if (!_hasMarkedRead) {
      _hasMarkedRead = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(chatRepositoryProvider).markMessagesAsRead(widget.chatId, user.uid);
      });
    }

    final repo = ref.watch(chatRepositoryProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(context, user.uid),
      body: Column(
        children: [
          Expanded(
            child: _initialLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? const Center(
                        child: Text(
                          'メッセージを送信して会話を始めましょう',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      )
                    : Builder(
                        builder: (context) {
                          final chatItems = _chatItemsWithDayDividers(_messages);
                          return Stack(
                            clipBehavior: Clip.none,
                            alignment: Alignment.topCenter,
                            children: [
                              ListView.builder(
                                controller: _scrollController,
                                reverse: false,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                itemCount: chatItems.length,
                                itemBuilder: (context, index) {
                                  final item = chatItems[index];
                                  if (item is DateTime) {
                                    return _DayDivider(date: item);
                                  }
                                  final msg = item as Message;
                                  final isMine = msg.senderId == user.uid;
                                  return _MessageBubble(
                                    message: msg,
                                    isMine: isMine,
                                  );
                                },
                              ),
                              // Load-more feedback (does not affect scroll extent).
                              Positioned(
                                top: 0,
                                left: 0,
                                right: 0,
                                child: IgnorePointer(
                                  child: AnimatedOpacity(
                                    opacity: _loadingMore ? 1 : 0,
                                    duration: const Duration(milliseconds: 220),
                                    curve: Curves.easeOut,
                                    child: AnimatedSlide(
                                      offset: _loadingMore
                                          ? Offset.zero
                                          : const Offset(0, -0.12),
                                      duration: const Duration(milliseconds: 280),
                                      curve: Curves.easeOutCubic,
                                      child: Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.only(
                                          top: 8,
                                          bottom: 20,
                                        ),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [
                                              AppColors.background
                                                  .withValues(alpha: 0.98),
                                              AppColors.background
                                                  .withValues(alpha: 0),
                                            ],
                                          ),
                                        ),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            SizedBox(
                                              width: 26,
                                              height: 26,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.5,
                                                color: AppColors.primary,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              '読み込み中…',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
          ),
          Container(
            padding: EdgeInsets.only(
              left: 16,
              right: 8,
              top: 8,
              bottom: 8 + MediaQuery.of(context).padding.bottom,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  onPressed: _sendingAttachment
                      ? null
                      : () => _pickAndSendImage(repo, user.uid),
                  icon: const Icon(Icons.photo_outlined),
                  color: AppColors.textSecondary,
                ),
                IconButton(
                  onPressed: _sendingAttachment
                      ? null
                      : () => _pickAndSendFile(repo, user.uid),
                  icon: const Icon(Icons.attach_file),
                  color: AppColors.textSecondary,
                ),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    minLines: 1,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'メッセージを入力',
                      filled: true,
                      fillColor: AppColors.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onSubmitted: (_) => _send(repo, user.uid),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: () => _send(repo, user.uid),
                  icon: const Icon(Icons.send),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _send(ChatRepository repo, String uid) async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    await repo.sendMessage(
      chatId: widget.chatId,
      senderId: uid,
      text: text,
    );
    _scrollToBottom();
  }

  Future<void> _pickAndSendImage(ChatRepository repo, String uid) async {
    final picker = ImagePicker();
    final XFile? picked =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return;

    setState(() => _sendingAttachment = true);
    try {
      final bytes = await picked.readAsBytes();
      final ext = picked.name.split('.').length > 1
          ? picked.name.split('.').last
          : 'jpg';
      final url = await _uploadChatBytes(bytes, '$uid-image', ext);
      if (!mounted) return;
      await repo.sendMessage(
        chatId: widget.chatId,
        senderId: uid,
        text: '画像を送信しました',
        imageUrl: url,
      );
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('画像の送信に失敗しました: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _sendingAttachment = false);
      }
    }
  }

  Future<void> _pickAndSendFile(ChatRepository repo, String uid) async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) {
      // Fallback to reading from path if available.
      if (file.path == null) return;
      final f = File(file.path!);
      if (!f.existsSync()) return;
      final fileBytes = await f.readAsBytes();
      await _sendFileBytes(repo, uid, file.name, fileBytes);
    } else {
      await _sendFileBytes(repo, uid, file.name, bytes);
    }
  }

  Future<void> _sendFileBytes(
    ChatRepository repo,
    String uid,
    String name,
    Uint8List bytes,
  ) async {
    setState(() => _sendingAttachment = true);
    try {
      final ext = name.split('.').length > 1 ? name.split('.').last : 'dat';
      final url = await _uploadChatBytes(bytes, '$uid-file', ext);
      if (!mounted) return;
      final text = 'ファイルを送信しました: $name\n$url';
      await repo.sendMessage(
        chatId: widget.chatId,
        senderId: uid,
        text: text,
      );
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ファイルの送信に失敗しました: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _sendingAttachment = false);
      }
    }
  }

  Future<String> _uploadChatBytes(
    Uint8List bytes,
    String prefix,
    String ext,
  ) async {
    final storage = FirebaseStorage.instance;
    final ts = DateTime.now().millisecondsSinceEpoch;
    final ref = storage
        .ref()
        .child('chats')
        .child(widget.chatId)
        .child('$prefix-$ts.$ext');
    await ref.putData(bytes);
    return _getDownloadUrlWithRetry(ref);
  }

  Future<String> _getDownloadUrlWithRetry(
    Reference ref, {
    int maxAttempts = 3,
  }) async {
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        return await ref.getDownloadURL();
      } catch (_) {
        if (attempt == maxAttempts - 1) rethrow;
        await Future<void>.delayed(
          Duration(milliseconds: 500 * (attempt + 1)),
        );
      }
    }
    throw StateError('getDownloadURL failed after $maxAttempts attempts');
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, String currentUserId) {
    final chatAsync = ref.watch(chatDetailProvider(widget.chatId));
    final titleWidget = chatAsync.when(
      data: (chat) {
        if (chat == null) {
          return const Text(
            'チャット',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          );
        }
        final otherId = chat.users.firstWhere(
          (u) => u != currentUserId,
          orElse: () => '',
        );
        if (otherId.isEmpty) {
          return const Text(
            'チャット',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          );
        }

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('users').doc(otherId).snapshots(),
          builder: (context, userSnap) {
            final data = userSnap.data?.data() ?? <String, dynamic>{};
            final name = (data['displayName'] as String?)?.trim();
            final email = (data['email'] as String?)?.trim();
            final emailPrefix = email != null && email.contains('@')
                ? email.split('@').first
                : null;
            final title = (name == null || name.isEmpty)
                ? (emailPrefix ?? 'ユーザー')
                : name;

            return Text(
              title,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            );
          },
        );
      },
      loading: () => const Text(
        'チャット',
        style: TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
      error: (_, __) => const Text(
        'チャット',
        style: TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
    );

    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.chevron_left),
        onPressed: () => context.pop(),
      ),
      title: titleWidget,
      centerTitle: true,
      backgroundColor: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.white,
    );
  }
}

/// Horizontal rule with centered date (local calendar day).
class _DayDivider extends StatelessWidget {
  const _DayDivider({required this.date});

  /// Date-only in local time (midnight).
  final DateTime date;

  static String _label(DateTime day) {
    final now = DateTime.now();
    final today = DateUtils.dateOnly(now);
    final yesterday = today.subtract(const Duration(days: 1));
    if (day == today) return '今日';
    if (day == yesterday) return '昨日';
    return DateFormat('yyyy年M月d日').format(day);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Divider(
              height: 1,
              thickness: 1,
              color: Colors.grey.shade300,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              _label(date),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Divider(
              height: 1,
              thickness: 1,
              color: Colors.grey.shade300,
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.isMine});

  final Message message;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final timeStr = DateFormat('HH:mm').format(message.createdAt);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Align(
        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMine ? AppColors.primary : Colors.grey.shade200,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isMine ? 18 : 4),
                  bottomRight: Radius.circular(isMine ? 4 : 18),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Flexible(
                    child: Column(
                      crossAxisAlignment:
                          isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (message.image != null) ...[
                          GestureDetector(
                            onTap: () {
                              _showFullScreenImage(context, message.image!);
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: AspectRatio(
                                aspectRatio: 4 / 3,
                                child: Image.network(
                                  message.image!,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                          if ((message.text ?? '').isNotEmpty)
                            const SizedBox(height: 8),
                        ],
                        if ((message.text ?? '').isNotEmpty)
                          Text(
                            message.text ?? '',
                            style: TextStyle(
                              fontSize: 15,
                              color: isMine ? Colors.white : AppColors.textPrimary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (isMine) ...[
                    const SizedBox(width: 6),
                    Icon(
                      message.isRead ? Icons.done_all : Icons.done,
                      size: 14,
                      color: message.isRead ? Colors.white70 : Colors.white,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              timeStr,
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFullScreenImage(BuildContext context, String url) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.9),
      builder: (ctx) {
        return GestureDetector(
          onTap: () => Navigator.of(ctx).pop(),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: SafeArea(
              child: Stack(
                children: [
                  Center(
                    child: InteractiveViewer(
                      minScale: 1,
                      maxScale: 4,
                      child: Hero(
                        tag: url,
                        child: Image.network(url),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
