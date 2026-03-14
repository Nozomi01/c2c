import 'dart:io';
import 'dart:typed_data';

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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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

    final messagesAsync = ref.watch(messagesProvider(widget.chatId));
    final repo = ref.watch(chatRepositoryProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(context, user.uid),
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              data: (messages) {
                if (messages.isEmpty) {
                  return const Center(
                    child: Text(
                      'メッセージを送信して会話を始めましょう',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMine = msg.senderId == user.uid;
                    return _MessageBubble(message: msg, isMine: isMine);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('エラー: $e')),
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
    final title = chatAsync.when(
      data: (chat) {
        if (chat == null) return 'チャット';
        final otherId = chat.users.firstWhere(
          (u) => u != currentUserId,
          orElse: () => '',
        );
        return otherId.isEmpty ? 'チャット' : 'ユーザー';
      },
      loading: () => 'チャット',
      error: (_, __) => 'チャット',
    );

    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.chevron_left),
        onPressed: () => context.pop(),
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
