enum ChatSender { me, them }
enum MessageStatus { sending, sent, failed }

class ChatMessage {
  final String id;
  final ChatSender sender;
  final String text;
  final String time;
  final MessageStatus status;

  const ChatMessage({
    required this.id,
    required this.sender,
    required this.text,
    required this.time,
    this.status = MessageStatus.sent,
  });

  ChatMessage copyWith({
    String? id,
    ChatSender? sender,
    String? text,
    String? time,
    MessageStatus? status,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      sender: sender ?? this.sender,
      text: text ?? this.text,
      time: time ?? this.time,
      status: status ?? this.status,
    );
  }
}