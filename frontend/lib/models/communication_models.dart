enum ChatSender { me, them }

enum MessageStatus { sending, sent, delivered, read, failed }

class ChatMessage {
  final String id;
  final ChatSender sender;
  final String text;
  final String time;
  final MessageStatus status;
  final DateTime createdAt;
  final String? replyToMessageId;
  final String? replyToText;
  final String? replyToFromUserId;
  final bool isDeleted;

  ChatMessage({
    required this.id,
    required this.sender,
    required this.text,
    required this.time,
    this.status = MessageStatus.sent,
    DateTime? createdAt,
    this.replyToMessageId,
    this.replyToText,
    this.replyToFromUserId,
    this.isDeleted = false,
  }) : createdAt = createdAt ?? DateTime.now();

  ChatMessage copyWith({
    String? id,
    ChatSender? sender,
    String? text,
    String? time,
    MessageStatus? status,
    DateTime? createdAt,
    String? replyToMessageId,
    String? replyToText,
    String? replyToFromUserId,
    bool? isDeleted,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      sender: sender ?? this.sender,
      text: text ?? this.text,
      time: time ?? this.time,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      replyToMessageId: replyToMessageId ?? this.replyToMessageId,
      replyToText: replyToText ?? this.replyToText,
      replyToFromUserId: replyToFromUserId ?? this.replyToFromUserId,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}
