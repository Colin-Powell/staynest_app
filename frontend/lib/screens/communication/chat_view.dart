import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:property_app/models/communication_models.dart';
import 'package:property_app/services/message_service.dart';
import 'package:property_app/services/socket_service.dart';
import 'package:property_app/session/app_session.dart';
import 'package:property_app/utils/presence_format.dart';
import 'package:property_app/widgets/property_conversation_header.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

const Color _chatBackground = Color(0xFFFAFAFA);
const Color _chatText = Color(0xFF111827);
const Color _chatMuted = Color(0xFF9CA3AF);
const Color _chatPrimary = Color(0xFF3F37C9);

class ChatView extends StatefulWidget {
  final VoidCallback onBack;
  final VoidCallback? onClose;
  final VoidCallback? onMinimize;
  final String userId;
  final String? conversationId;
  final ConversationModel? initialConversation;
  final String name;
  final String avatar;
  final bool isOnline;
  final DateTime? lastSeenAt;

  const ChatView({
    super.key,
    required this.onBack,
    required this.userId,
    this.conversationId,
    this.initialConversation,
    required this.name,
    required this.avatar,
    this.isOnline = false,
    this.lastSeenAt,
    this.onClose,
    this.onMinimize,
  });

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  final TextEditingController _composer = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  final Map<String, GlobalKey> _messageKeys = {};
  final Set<String> _deliveredMessageIds = {};
  final Set<String> _readMessageIds = {};
  final Set<String> _deletedMessageIds = {};
  final List<StreamSubscription<dynamic>> _subscriptions = [];

  late String _peerUserId;
  late bool _peerOnline;
  DateTime? _lastSeenAt;
  ConversationModel? _conversation;
  ChatMessage? _replyingTo;
  Timer? _typingTimer;
  bool _isTyping = false;
  bool _peerTyping = false;
  bool _sending = false;
  bool _initialLoadComplete = false;

  String? get _conversationId =>
      widget.conversationId ?? _conversation?.conversationId;

  @override
  void initState() {
    super.initState();
    _peerUserId = widget.userId;
    _peerOnline = widget.isOnline;
    _lastSeenAt = widget.lastSeenAt;
    _conversation = widget.initialConversation;
    _composer.addListener(_updateComposerState);

    final presence = SocketService.instance.latestPresenceFor(_peerUserId);
    if (presence != null) {
      _peerOnline = presence['online'] == true;
      _lastSeenAt = DateTime.tryParse(presence['lastSeenAt']?.toString() ?? '');
    }

    _subscriptions
        .add(SocketService.instance.messages.listen(_onSocketMessage));
    _subscriptions.add(SocketService.instance.typing.listen(_onTyping));
    _subscriptions.add(SocketService.instance.presence.listen(_onPresence));
    _subscriptions.add(SocketService.instance.seen.listen(_onSeen));
    _subscriptions.add(SocketService.instance.delivered.listen(_onDelivered));
    _subscriptions.add(SocketService.instance.deleted.listen(_onDeleted));
    _subscriptions.add(
      SocketService.instance.connectionChanges.listen((connected) {
        if (connected) unawaited(_fetchMessages());
      }),
    );
    unawaited(_fetchMessages(initial: true));
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _typingTimer?.cancel();
    _composer.removeListener(_updateComposerState);
    _composer.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _updateComposerState() {
    if (!mounted) return;
    final hasText = _composer.text.trim().isNotEmpty;
    setState(() => _isTyping = hasText);
    if (_peerUserId.isEmpty) return;
    _typingTimer?.cancel();
    SocketService.instance.sendTyping(to: _peerUserId, isTyping: hasText);
    if (hasText) {
      _typingTimer = Timer(const Duration(milliseconds: 1500), () {
        SocketService.instance.sendTyping(to: _peerUserId, isTyping: false);
      });
    }
  }

  void _onSocketMessage(SocketMessage message) {
    if (_deletedMessageIds.contains(message.id)) return;
    if (message.from != _peerUserId) return;
    final conversationId = _conversationId;
    if (conversationId == null || message.conversationId != conversationId) {
      if (conversationId == null) unawaited(_fetchMessages());
      return;
    }
    if (_messages.any((item) => item.id == message.id)) return;
    _insertMessage(
      ChatMessage(
        id: message.id,
        sender: ChatSender.them,
        text: message.text,
        time: _formatTime(DateTime.fromMillisecondsSinceEpoch(message.ts)),
        createdAt: DateTime.fromMillisecondsSinceEpoch(message.ts),
      ),
    );
    unawaited(MessageService.instance.markAsRead(
      const [],
      conversationIds: [conversationId],
    ));
    SocketService.instance.markSeen(to: _peerUserId, messageIds: [message.id]);
  }

  void _onTyping(Map<String, dynamic> data) {
    if (data['userId']?.toString() == _peerUserId && mounted) {
      setState(() => _peerTyping = data['isTyping'] == true);
    }
  }

  void _onPresence(Map<String, dynamic> data) {
    if (data['userId']?.toString() != _peerUserId || !mounted) return;
    setState(() {
      _peerOnline = data['online'] == true;
      _lastSeenAt = DateTime.tryParse(data['lastSeenAt']?.toString() ?? '');
    });
  }

  void _onSeen(Map<String, dynamic> data) {
    if (data['userId']?.toString() != _peerUserId || !mounted) return;
    final messageIds = data['messageIds'];
    if (messageIds is! List) return;
    _readMessageIds.addAll(messageIds.map((id) => id.toString()));
    setState(() {
      for (var index = 0; index < _messages.length; index++) {
        if (_messages[index].sender == ChatSender.me &&
            messageIds.contains(_messages[index].id)) {
          _messages[index] =
              _messages[index].copyWith(status: MessageStatus.read);
        }
      }
    });
  }

  void _onDelivered(Map<String, dynamic> data) {
    if (data['userId']?.toString() != _peerUserId || !mounted) return;
    final messageIds = data['messageIds'];
    if (messageIds is! List) return;
    _deliveredMessageIds.addAll(messageIds.map((id) => id.toString()));
    setState(() {
      for (var index = 0; index < _messages.length; index++) {
        if (_messages[index].sender == ChatSender.me &&
            _messages[index].status == MessageStatus.sent &&
            !_readMessageIds.contains(_messages[index].id) &&
            messageIds.contains(_messages[index].id)) {
          _messages[index] =
              _messages[index].copyWith(status: MessageStatus.delivered);
        }
      }
    });
  }

  void _onDeleted(Map<String, dynamic> data) {
    if (data['conversationId']?.toString() != _conversationId) return;
    final deletedId = data['messageId']?.toString();
    if (deletedId != null) _deletedMessageIds.add(deletedId);
    final index = _messages.indexWhere(
      (message) => message.id == deletedId,
    );
    if (index == -1 || !mounted) return;
    setState(() {
      if (data['scope'] == 'me' &&
          data['userId']?.toString() == AppSession.currentUserId) {
        _messages.removeAt(index);
      } else {
        _replaceWithDeleted(index);
      }
    });
  }

  Future<void> _fetchMessages({bool initial = false}) async {
    try {
      final conversationId = _conversationId;
      final List<MessageModel> loaded;
      if (conversationId != null && conversationId.isNotEmpty) {
        final history =
            await MessageService.instance.fetchConversationById(conversationId);
        _conversation = history.conversation;
        _peerUserId = history.conversation.userId;
        loaded = history.messages;
      } else {
        final history =
            await MessageService.instance.fetchGeneralConversationHistory(
          _peerUserId,
          userName: widget.name,
          userAvatar: widget.avatar,
        );
        _conversation = history.conversation;
        loaded = history.messages;
      }
      if (!mounted) return;
      setState(() {
        for (final message in loaded) {
          if (message.isDeleted) _deletedMessageIds.add(message.id);
          final item = ChatMessage(
            id: message.id,
            sender: message.fromUserId == AppSession.currentUserId
                ? ChatSender.me
                : ChatSender.them,
            text: message.text,
            time: _formatTime(message.createdAt),
            createdAt: message.createdAt,
            status: message.isRead
                ? MessageStatus.read
                : message.isDelivered
                    ? MessageStatus.delivered
                    : MessageStatus.sent,
            replyToMessageId: message.replyToMessageId,
            replyToText: message.replyToText,
            replyToFromUserId: message.replyToFromUserId,
            isDeleted: message.isDeleted,
          );
          final existingIndex = _messages.indexWhere((existing) =>
              existing.id == item.id || existing.id == message.clientMessageId);
          if (existingIndex == -1) {
            _messages.add(item);
          } else {
            _messages[existingIndex] = item;
          }
        }
        _sortMessages();
      });
      final activeId = _conversationId;
      await MessageService.instance.markAsRead(
        activeId == null ? [_peerUserId] : const [],
        conversationIds: activeId == null ? const [] : [activeId],
      );
      final incomingIds = loaded
          .where((message) =>
              message.toUserId == AppSession.currentUserId &&
              !message.isDeleted)
          .map((message) => message.id)
          .toList();
      if (incomingIds.isNotEmpty) {
        SocketService.instance.markDelivered(incomingIds);
        SocketService.instance.markSeen(
          to: _peerUserId,
          messageIds: incomingIds,
        );
      }
      _scrollToBottom(force: initial && !_initialLoadComplete);
      _initialLoadComplete = true;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Messages could not be loaded.')),
        );
      }
    }
  }

  void _insertMessage(ChatMessage message) {
    if (_messages.any((item) => item.id == message.id) || !mounted) return;
    final shouldScroll = !_scrollController.hasClients ||
        _scrollController.position.extentAfter < 150;
    setState(() {
      _messages.add(message);
      _sortMessages();
    });
    if (shouldScroll) _scrollToBottom(force: true);
  }

  void _sortMessages() {
    _messages.sort((left, right) {
      final byTime = left.createdAt.compareTo(right.createdAt);
      return byTime != 0 ? byTime : left.id.compareTo(right.id);
    });
  }

  Future<void> _sendMessage() async {
    final text = _composer.text.trim();
    if (text.isEmpty || text.length > 5000 || _sending) return;
    final clientId = const Uuid().v4();
    final reply = _replyingTo;
    setState(() => _sending = true);
    _insertMessage(
      ChatMessage(
        id: clientId,
        sender: ChatSender.me,
        text: text,
        time: 'Now',
        status: MessageStatus.sending,
        createdAt: DateTime.now(),
        replyToMessageId: reply?.id,
        replyToText:
            reply?.isDeleted == true ? 'This message was deleted' : reply?.text,
        replyToFromUserId: reply?.sender == ChatSender.me
            ? AppSession.currentUserId
            : _peerUserId,
      ),
    );

    try {
      final saved = await MessageService.instance.saveMessage(
        toUserId: _peerUserId,
        text: text,
        conversationId: _conversationId,
        replyToMessageId: reply?.id,
        idempotencyKey: clientId,
      );
      if (!mounted) return;
      if (_conversation?.conversationId == null &&
          saved.conversationId != null) {
        _conversation = _conversation?.copyWith(
              conversationId: saved.conversationId,
            ) ??
            ConversationModel(
              conversationId: saved.conversationId,
              userId: _peerUserId,
              userName: widget.name,
              userAvatar: widget.avatar,
            );
      }
      setState(() {
        final index = _messages.indexWhere((message) => message.id == clientId);
        if (index != -1) {
          _messages[index] = _messages[index].copyWith(
            id: saved.id,
            createdAt: saved.createdAt,
            status: _readMessageIds.contains(saved.id)
                ? MessageStatus.read
                : _deliveredMessageIds.contains(saved.id)
                    ? MessageStatus.delivered
                    : MessageStatus.sent,
            replyToMessageId: saved.replyToMessageId,
            replyToText: saved.replyToText,
            replyToFromUserId: saved.replyToFromUserId,
          );
          _sortMessages();
        }
        if (_composer.text.trim() == text) _composer.clear();
        _replyingTo = null;
        _sending = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        final index = _messages.indexWhere((message) => message.id == clientId);
        if (index != -1) {
          _messages[index] =
              _messages[index].copyWith(status: MessageStatus.failed);
        }
        _sending = false;
      });
    }
  }

  Future<void> _retryMessage(ChatMessage message) async {
    if (message.status != MessageStatus.failed || _sending) return;
    setState(() {
      _sending = true;
      final index = _messages.indexOf(message);
      if (index != -1) {
        _messages[index] = message.copyWith(status: MessageStatus.sending);
      }
    });
    try {
      final saved = await MessageService.instance.saveMessage(
        toUserId: _peerUserId,
        text: message.text,
        conversationId: _conversationId,
        replyToMessageId: message.replyToMessageId,
        idempotencyKey: message.id,
      );
      if (!mounted) return;
      setState(() {
        final index = _messages.indexWhere((item) => item.id == message.id);
        if (index != -1) {
          _messages[index] = message.copyWith(
            id: saved.id,
            status: MessageStatus.sent,
            createdAt: saved.createdAt,
          );
        }
        _sending = false;
        if (_composer.text.trim() == message.text) _composer.clear();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        final index = _messages.indexWhere((item) => item.id == message.id);
        if (index != -1) {
          _messages[index] = message.copyWith(status: MessageStatus.failed);
        }
        _sending = false;
      });
    }
  }

  Future<void> _copyMessage(ChatMessage message) async {
    try {
      await Clipboard.setData(ClipboardData(text: message.text));
      if (mounted) _showNotice('Message copied');
    } catch (_) {
      if (mounted) _showNotice('Could not copy this message');
    }
  }

  Future<void> _deleteMessage(ChatMessage message, String scope) async {
    try {
      await MessageService.instance.deleteMessage(message.id, scope: scope);
      if (!mounted) return;
      setState(() {
        final index = _messages.indexWhere((item) => item.id == message.id);
        if (index == -1) return;
        if (scope == 'me') {
          _messages.removeAt(index);
        } else {
          _replaceWithDeleted(index);
        }
      });
    } catch (error) {
      if (mounted) _showNotice('Could not delete message: $error');
    }
  }

  void _replaceWithDeleted(int index) {
    _messages[index] = _messages[index].copyWith(
      text: 'This message was deleted',
      isDeleted: true,
    );
  }

  Future<void> _confirmDeleteForEveryone(ChatMessage message) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete for everyone?'),
        content: const Text(
          'This removes the message from both participants’ conversation.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _deleteMessage(message, 'everyone');
  }

  void _showNotice(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  void _scrollToBottom({bool force = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      if (!force && _scrollController.position.extentAfter > 150) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    });
  }

  void _jumpToMessage(String? messageId) {
    if (messageId == null) return;
    final target = _messageKeys[messageId]?.currentContext;
    if (target != null) {
      Scrollable.ensureVisible(
        target,
        alignment: 0.5,
        duration: const Duration(milliseconds: 200),
      );
    }
  }

  String _formatTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${local.hour >= 12 ? 'PM' : 'AM'}';
  }

  Widget _messageMenu(ChatMessage message) {
    final saved = message.status != MessageStatus.sending &&
        message.status != MessageStatus.failed;
    return PopupMenuButton<String>(
      tooltip: 'Message actions',
      icon: const Icon(Icons.more_horiz, size: 18, color: _chatMuted),
      onSelected: (action) {
        switch (action) {
          case 'copy':
            unawaited(_copyMessage(message));
            break;
          case 'reply':
            setState(() => _replyingTo = message);
            break;
          case 'delete_me':
            unawaited(_deleteMessage(message, 'me'));
            break;
          case 'delete_everyone':
            unawaited(_confirmDeleteForEveryone(message));
            break;
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'copy', child: Text('Copy message')),
        if (!message.isDeleted && saved)
          const PopupMenuItem(value: 'reply', child: Text('Reply')),
        if (saved)
          const PopupMenuItem(value: 'delete_me', child: Text('Delete for me')),
        if (saved && message.sender == ChatSender.me && !message.isDeleted)
          const PopupMenuItem(
            value: 'delete_everyone',
            child: Text('Delete for everyone'),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayName = _conversation?.userName ?? widget.name;
    final displayAvatar = _conversation?.userAvatar ?? widget.avatar;
    return Scaffold(
      backgroundColor: _chatBackground,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(displayName, displayAvatar),
            if (_conversation?.property case final property?)
              PropertyConversationHeader(property: property),
            Expanded(child: _buildMessageList()),
            _buildComposer(displayName),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(String displayName, String displayAvatar) {
    final presenceText = _peerTyping
        ? 'typing...'
        : presenceLabel(online: _peerOnline, lastSeenAt: _lastSeenAt);
    final presenceColor = _peerTyping
        ? _chatPrimary
        : _peerOnline
            ? const Color(0xFF10B981)
            : _chatMuted;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back to conversations',
            onPressed: widget.onBack,
            icon: const Icon(PhosphorIconsRegular.caretLeft),
          ),
          ClipOval(
            child: AppSession.buildAvatar(
              displayAvatar,
              width: 42,
              height: 42,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _chatText,
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: presenceColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      presenceText,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: presenceColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (widget.onMinimize != null)
            IconButton(
              tooltip: 'Minimize chat',
              onPressed: widget.onMinimize,
              icon: const Icon(Icons.remove),
            ),
          if (widget.onClose != null)
            IconButton(
              tooltip: 'Close chat',
              onPressed: widget.onClose,
              icon: const Icon(Icons.close),
            ),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    if (_messages.isEmpty) {
      return Center(
        child: Text(
          'No messages yet',
          style: GoogleFonts.poppins(color: _chatMuted, fontSize: 14),
        ),
      );
    }
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        final outgoing = message.sender == ChatSender.me;
        final previous = index > 0 ? _messages[index - 1] : null;
        final grouped = previous?.sender == message.sender &&
            previous!.createdAt.difference(message.createdAt).inMinutes.abs() <
                5;
        return Container(
          key: _messageKeys.putIfAbsent(message.id, GlobalKey.new),
          margin: EdgeInsets.only(bottom: grouped ? 6 : 14),
          child: Row(
            mainAxisAlignment:
                outgoing ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!outgoing && !grouped) ...[
                ClipOval(
                  child: AppSession.buildAvatar(
                    _conversation?.userAvatar ?? widget.avatar,
                    width: 28,
                    height: 28,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 8),
              ] else if (!outgoing) ...[
                const SizedBox(width: 36),
              ],
              Flexible(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 560),
                  padding: const EdgeInsets.fromLTRB(13, 10, 8, 7),
                  decoration: BoxDecoration(
                    color: outgoing ? _chatPrimary : Colors.white,
                    border: outgoing
                        ? null
                        : Border.all(color: const Color(0xFFE5E7EB)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (message.replyToMessageId != null)
                        _ReplyCard(
                          text: message.replyToText ?? 'Message unavailable',
                          sender: message.replyToFromUserId ==
                                  AppSession.currentUserId
                              ? 'You'
                              : 'Reply',
                          outgoing: outgoing,
                          onTap: () => _jumpToMessage(message.replyToMessageId),
                        ),
                      _LinkifiedText(
                        text: message.text,
                        color: outgoing ? Colors.white : _chatText,
                        isDeleted: message.isDeleted,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            message.time,
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              color: outgoing ? Colors.white70 : _chatMuted,
                            ),
                          ),
                          if (outgoing) ...[
                            const SizedBox(width: 4),
                            _statusIcon(message),
                          ],
                          const SizedBox(width: 2),
                          _messageMenu(message),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (outgoing) const SizedBox(width: 4),
            ],
          ),
        );
      },
    );
  }

  Widget _statusIcon(ChatMessage message) {
    switch (message.status) {
      case MessageStatus.sending:
        return const SizedBox(
          width: 11,
          height: 11,
          child: CircularProgressIndicator(strokeWidth: 1.5),
        );
      case MessageStatus.sent:
        return const Icon(PhosphorIconsRegular.check,
            size: 13, color: Colors.white70);
      case MessageStatus.delivered:
        return const Icon(PhosphorIconsRegular.checks,
            size: 13, color: Colors.white70);
      case MessageStatus.read:
        return const Icon(PhosphorIconsRegular.checks,
            size: 13, color: Color(0xFFBFDBFE));
      case MessageStatus.failed:
        return IconButton(
          tooltip: 'Retry sending',
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
          onPressed: () {
            unawaited(_retryMessage(message));
          },
          icon: const Icon(Icons.error_outline,
              size: 14, color: Colors.redAccent),
        );
    }
  }

  Widget _buildComposer(String displayName) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        14,
        12,
        14,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_replyingTo != null)
            Row(
              children: [
                Expanded(
                  child: _ReplyCard(
                    text: _replyingTo!.isDeleted
                        ? 'This message was deleted'
                        : _replyingTo!.text,
                    sender: _replyingTo!.sender == ChatSender.me
                        ? 'You'
                        : displayName,
                    outgoing: false,
                  ),
                ),
                IconButton(
                  tooltip: 'Cancel reply',
                  onPressed: () => setState(() => _replyingTo = null),
                  icon: const Icon(Icons.close, size: 18),
                ),
              ],
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _composer,
                  minLines: 1,
                  maxLines: 4,
                  maxLength: 5000,
                  maxLengthEnforcement: MaxLengthEnforcement.enforced,
                  buildCounter: (_,
                          {required currentLength,
                          required isFocused,
                          maxLength}) =>
                      null,
                  keyboardType: TextInputType.multiline,
                  enabled: !_sending,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: 'Write a message',
                    filled: true,
                    fillColor: const Color(0xFFF3F4F6),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                tooltip: 'Send message',
                onPressed: _isTyping && !_sending ? _sendMessage : null,
                style: IconButton.styleFrom(
                  fixedSize: const Size(44, 44),
                  backgroundColor: _chatPrimary,
                ),
                icon: _sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(PhosphorIconsFill.paperPlaneRight, size: 20),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReplyCard extends StatelessWidget {
  final String text;
  final String sender;
  final bool outgoing;
  final VoidCallback? onTap;

  const _ReplyCard({
    required this.text,
    required this.sender,
    required this.outgoing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(8, 5, 8, 5),
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          color:
              outgoing ? Colors.white.withValues(alpha: 0.12) : _chatBackground,
          border: Border(
            left: BorderSide(
              color: outgoing ? Colors.white70 : _chatPrimary,
              width: 2,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              sender,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: outgoing ? Colors.white : _chatPrimary,
              ),
            ),
            Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: outgoing ? Colors.white : _chatText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LinkifiedText extends StatefulWidget {
  final String text;
  final Color color;
  final bool isDeleted;

  const _LinkifiedText({
    required this.text,
    required this.color,
    required this.isDeleted,
  });

  @override
  State<_LinkifiedText> createState() => _LinkifiedTextState();
}

class _LinkifiedTextState extends State<_LinkifiedText> {
  static final RegExp _urls =
      RegExp(r'(https?://[^\s<>]+|www\.[^\s<>]+)', caseSensitive: false);
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    super.dispose();
  }

  Future<void> _open(String text) async {
    final value =
        text.toLowerCase().startsWith('www.') ? 'https://$text' : text;
    final uri = Uri.tryParse(value);
    if (uri == null ||
        !{'http', 'https'}.contains(uri.scheme.toLowerCase()) ||
        uri.host.isEmpty) {
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final match in _urls.allMatches(widget.text)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: widget.text.substring(cursor, match.start)));
      }
      final matched = match.group(0)!;
      final url = matched.replaceFirst(RegExp(r'[.,!?;:)\]}]+$'), '');
      final punctuation = matched.substring(url.length);
      final candidate =
          url.toLowerCase().startsWith('www.') ? 'https://$url' : url;
      final uri = Uri.tryParse(candidate);
      final safe = uri != null &&
          {'http', 'https'}.contains(uri.scheme.toLowerCase()) &&
          uri.host.isNotEmpty;
      if (safe) {
        final recognizer = TapGestureRecognizer()..onTap = () => _open(url);
        _recognizers.add(recognizer);
        spans.add(TextSpan(
          text: url,
          recognizer: recognizer,
          style: TextStyle(
            color: widget.isDeleted
                ? widget.color
                : widget.color == Colors.white
                    ? const Color(0xFFBFDBFE)
                    : const Color(0xFF1D4ED8),
            decoration: widget.isDeleted ? null : TextDecoration.underline,
          ),
        ));
      } else {
        spans.add(TextSpan(text: url));
      }
      if (punctuation.isNotEmpty) spans.add(TextSpan(text: punctuation));
      cursor = match.end;
    }
    if (cursor < widget.text.length) {
      spans.add(TextSpan(text: widget.text.substring(cursor)));
    }
    return SelectableText.rich(
      TextSpan(
        children: spans,
        style: TextStyle(
          color: widget.color,
          height: 1.4,
          fontSize: 14,
          fontStyle: widget.isDeleted ? FontStyle.italic : FontStyle.normal,
        ),
      ),
    );
  }
}
