import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:property_app/session/app_session.dart';

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

  ConversationModel({
    required this.userId,
    required this.userName,
    this.userAvatar,
    this.lastMessage,
    this.lastMessageAt,
  });

  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    return ConversationModel(
      userId: json['user_id']?.toString() ?? '',
      userName: json['user_name']?.toString() ?? 'Unknown',
      userAvatar: json['user_avatar']?.toString(),
      lastMessage: json['last_message']?.toString(),
      lastMessageAt:
          DateTime.tryParse(json['last_message_at']?.toString() ?? ''),
    );
  }
}

class MessageService {
  static final MessageService instance = MessageService._internal();
  MessageService._internal();

  final String _baseUrl = AppSession.apiBaseUrl;

  Future<void> saveMessage(
      {required String toUserId, required String text}) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/messages'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${AppSession.apiToken}',
        },
        body: jsonEncode({'to_user_id': toUserId, 'text': text}),
      );

      if (response.statusCode != 201) {
        throw Exception('Failed to save message: ${response.body}');
      }
    } catch (err) {
      rethrow;
    }
  }

  Future<List<MessageModel>> fetchConversation(
    String userId, {
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final response = await http.get(
        Uri.parse(
            '$_baseUrl/messages/conversation/$userId?limit=$limit&offset=$offset'),
        headers: {
          'Authorization': 'Bearer ${AppSession.apiToken}',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to fetch messages: ${response.body}');
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final messages = (json['data']?['messages'] as List<dynamic>?)
              ?.map((m) => MessageModel.fromJson(m as Map<String, dynamic>))
              .toList() ??
          [];
      return messages;
    } catch (err) {
      rethrow;
    }
  }

  Future<List<ConversationModel>> fetchConversations() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/messages/conversations'),
        headers: {
          'Authorization': 'Bearer ${AppSession.apiToken}',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to fetch conversations: ${response.body}');
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final conversations = (json['data']?['conversations'] as List<dynamic>?)
              ?.map(
                  (c) => ConversationModel.fromJson(c as Map<String, dynamic>))
              .toList() ??
          [];
      return conversations;
    } catch (err) {
      rethrow;
    }
  }
}
