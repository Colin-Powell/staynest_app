import 'dart:convert';
import 'package:property_app/session/app_session.dart';
import 'package:property_app/repository/http_json_client.dart';
import 'package:uuid/uuid.dart';

class MessageModel {
  final String id;
  final String fromUserId;
  final String toUserId;
  final String text;
  final DateTime createdAt;

  MessageModel({
    required this.id,
    required this.fromUserId,
    required this.toUserId,
    required this.text,
    required this.createdAt,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['id']?.toString() ?? '',
      fromUserId: json['from_user_id']?.toString() ?? '',
      toUserId: json['to_user_id']?.toString() ?? '',
      text: json['text']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

class ConversationModel {
  final String userId;
  final String userName;
  final String? userAvatar;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final int unreadCount;

  ConversationModel({
    required this.userId,
    required this.userName,
    this.userAvatar,
    this.lastMessage,
    this.lastMessageAt,
    this.unreadCount = 0,
  });

  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    final unreadRaw = json['unread_count'] ?? json['unreadCount'];
    final unreadCount =
        unreadRaw == null ? 0 : int.tryParse(unreadRaw.toString()) ?? 0;

    return ConversationModel(
      userId: json['user_id']?.toString() ?? '',
      userName: json['user_name']?.toString() ?? 'Unknown',
      userAvatar: json['user_avatar']?.toString(),
      lastMessage: json['last_message']?.toString(),
      lastMessageAt:
          DateTime.tryParse(json['last_message_at']?.toString() ?? ''),
      unreadCount: unreadCount,
    );
  }
}

class MessageService {
  static final MessageService instance = MessageService._internal();
  MessageService._internal();

  final HttpJsonClient _client = HttpJsonClient();
  final String _baseUrl = AppSession.apiBaseUrl;

  Future<String> saveMessage(
      {required String toUserId, required String text, String? idempotencyKey}) async {
    final key = idempotencyKey ?? const Uuid().v4();
    final response = await _client.post(
      Uri.parse('$_baseUrl/messages'),
      headers: {
        'Idempotency-Key': key,
      },
      body: {'to_user_id': toUserId, 'text': text},
    );

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return json['data']?['id']?.toString() ?? '';
  }

  Future<List<MessageModel>> fetchConversation(
    String userId, {
    int limit = 50,
    int offset = 0,
  }) async {
    final response = await _client.get(
      Uri.parse('$_baseUrl/messages/conversation/$userId?limit=$limit&offset=$offset'),
    );

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final messages = (json['data']?['messages'] as List<dynamic>?)
            ?.map((m) => MessageModel.fromJson(m as Map<String, dynamic>))
            .toList() ??
        [];
    return messages;
  }

  Future<List<ConversationModel>> fetchConversations() async {
    final response = await _client.get(
      Uri.parse('$_baseUrl/messages/conversations'),
    );

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final conversations = (json['data']?['conversations'] as List<dynamic>?)
            ?.map(
                (c) => ConversationModel.fromJson(c as Map<String, dynamic>))
            .toList() ??
        [];
    return conversations;
  }

  Future<void> markAsRead(List<String> userIds) async {
    if (userIds.isEmpty) return;

    await _client.post(
      Uri.parse('$_baseUrl/messages/mark-read'),
      body: {'user_ids': userIds},
    );
  }

  Future<void> deleteConversation(String userId) async {
    await _client.delete(
      Uri.parse('$_baseUrl/messages/conversation/$userId'),
    );
  }

  Future<List<ConversationModel>> fetchRecentContacts() async {
    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl/users/recent-contacts'),
      );

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return (json['data']?['contacts'] as List<dynamic>?)
              ?.map((c) => ConversationModel.fromJson(c as Map<String, dynamic>))
              .toList() ??
          [];
    } catch (err) {
      return [];
    }
  }
}
