import 'dart:convert';
import 'package:property_app/session/app_session.dart';
import 'package:property_app/repository/http_json_client.dart';
import 'package:uuid/uuid.dart';

class MessageModel {
  final String id;
  final String? clientMessageId;
  final String? conversationId;
  final String fromUserId;
  final String toUserId;
  final String text;
  final DateTime createdAt;
  final String? replyToMessageId;
  final String? replyToText;
  final String? replyToFromUserId;
  final bool isDeleted;
  final bool isDelivered;
  final bool isRead;

  MessageModel({
    required this.id,
    this.clientMessageId,
    this.conversationId,
    required this.fromUserId,
    required this.toUserId,
    required this.text,
    required this.createdAt,
    this.replyToMessageId,
    this.replyToText,
    this.replyToFromUserId,
    this.isDeleted = false,
    this.isDelivered = false,
    this.isRead = false,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    final reply = json['reply_to'] is Map
        ? Map<String, dynamic>.from(json['reply_to'] as Map)
        : null;
    return MessageModel(
      id: json['id']?.toString() ?? '',
      clientMessageId: json['client_message_id']?.toString(),
      conversationId: json['conversation_id']?.toString(),
      fromUserId: json['from_user_id']?.toString() ?? '',
      toUserId: json['to_user_id']?.toString() ?? '',
      text: json['text']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      replyToMessageId:
          json['reply_to_message_id']?.toString() ?? reply?['id']?.toString(),
      replyToText: reply?['text']?.toString(),
      replyToFromUserId: reply?['from_user_id']?.toString(),
      isDeleted: json['is_deleted'] == true,
      isDelivered: json['is_delivered'] == true,
      isRead: json['is_read'] == true,
    );
  }
}

class PropertyConversationContext {
  final String id;
  final String title;
  final String location;
  final String? imageUrl;
  final int? price;
  final String? availabilityStatus;

  const PropertyConversationContext({
    required this.id,
    required this.title,
    required this.location,
    this.imageUrl,
    this.price,
    this.availabilityStatus,
  });

  factory PropertyConversationContext.fromJson(Map<String, dynamic> json) {
    final images = json['images'];
    final firstImage = images is List && images.isNotEmpty
        ? images.first is Map
            ? images.first['url']?.toString()
            : images.first?.toString()
        : null;
    return PropertyConversationContext(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Property',
      location: json['location']?.toString() ?? '',
      imageUrl: json['image_url']?.toString() ?? firstImage,
      price: int.tryParse(json['price']?.toString() ?? ''),
      availabilityStatus: json['availability_status']?.toString(),
    );
  }
}

class ConversationHistory {
  final ConversationModel conversation;
  final List<MessageModel> messages;

  const ConversationHistory({
    required this.conversation,
    required this.messages,
  });
}

class ConversationModel {
  final String? conversationId;
  final String userId;
  final String userName;
  final String? userAvatar;
  final String? lastMessage;
  final String? lastMessageFromUserId;
  final DateTime? lastMessageAt;
  final int unreadCount;
  final bool userOnline;
  final DateTime? lastSeenAt;
  final int presenceRevision;
  final String contextType;
  final PropertyConversationContext? property;

  String get threadId => conversationId ?? userId;

  ConversationModel({
    this.conversationId,
    required this.userId,
    required this.userName,
    this.userAvatar,
    this.lastMessage,
    this.lastMessageFromUserId,
    this.lastMessageAt,
    this.unreadCount = 0,
    this.userOnline = false,
    this.lastSeenAt,
    this.presenceRevision = 0,
    this.contextType = 'general',
    this.property,
  });

  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    final unreadRaw = json['unread_count'] ?? json['unreadCount'];
    final unreadCount =
        unreadRaw == null ? 0 : int.tryParse(unreadRaw.toString()) ?? 0;

    return ConversationModel(
      conversationId: json['conversation_id']?.toString(),
      userId: json['user_id']?.toString() ?? '',
      userName: json['user_name']?.toString() ?? 'Unknown',
      userAvatar: json['user_avatar']?.toString(),
      lastMessage: json['last_message']?.toString(),
      lastMessageFromUserId: json['last_message_from_user_id']?.toString(),
      lastMessageAt:
          DateTime.tryParse(json['last_message_at']?.toString() ?? ''),
      unreadCount: unreadCount,
      userOnline: json['user_online'] == true,
      lastSeenAt: DateTime.tryParse(json['last_seen_at']?.toString() ?? ''),
      presenceRevision:
          int.tryParse(json['presence_revision']?.toString() ?? '') ?? 0,
      contextType: json['context_type']?.toString() ?? 'general',
      property: json['property'] is Map
          ? PropertyConversationContext.fromJson(
              Map<String, dynamic>.from(json['property'] as Map),
            )
          : json['property_id'] == null
              ? null
              : PropertyConversationContext.fromJson({
                  'id': json['property_id'],
                  'title': json['property_title'],
                  'location': json['property_location'],
                  'price': json['property_price'],
                  'availability_status': json['property_availability_status'],
                  'image_url': json['property_image_url'],
                  'images': json['property_images'],
                }),
    );
  }

  ConversationModel copyWith({
    String? conversationId,
    String? userId,
    String? userName,
    String? userAvatar,
    String? lastMessage,
    String? lastMessageFromUserId,
    DateTime? lastMessageAt,
    int? unreadCount,
    bool? userOnline,
    DateTime? lastSeenAt,
    int? presenceRevision,
    String? contextType,
    PropertyConversationContext? property,
  }) {
    return ConversationModel(
      conversationId: conversationId ?? this.conversationId,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userAvatar: userAvatar ?? this.userAvatar,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageFromUserId:
          lastMessageFromUserId ?? this.lastMessageFromUserId,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      unreadCount: unreadCount ?? this.unreadCount,
      userOnline: userOnline ?? this.userOnline,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      presenceRevision: presenceRevision ?? this.presenceRevision,
      contextType: contextType ?? this.contextType,
      property: property ?? this.property,
    );
  }
}

T? selectConversation<T>({
  required List<T> conversations,
  required String Function(T) userIdOf,
  required int Function(T) unreadCountOf,
  String? selectedUserId,
  String? preferredUserId,
  String? selectedConversationId,
  String? preferredConversationId,
  String? Function(T)? conversationIdOf,
}) {
  T? findById(String? userId) {
    if (userId == null || userId.isEmpty) return null;
    for (final conversation in conversations) {
      if (userIdOf(conversation) == userId) return conversation;
    }
    return null;
  }

  T? findByConversationId(String? conversationId) {
    if (conversationId == null ||
        conversationId.isEmpty ||
        conversationIdOf == null) {
      return null;
    }
    for (final conversation in conversations) {
      if (conversationIdOf(conversation) == conversationId) {
        return conversation;
      }
    }
    return null;
  }

  final selected = findByConversationId(selectedConversationId);
  if (selected != null) return selected;
  final selectedByUser = findById(selectedUserId);
  if (selectedByUser != null) return selectedByUser;
  final preferredConversation = findByConversationId(preferredConversationId);
  if (preferredConversation != null) return preferredConversation;
  final preferred = findById(preferredUserId);
  if (preferred != null) return preferred;
  for (final conversation in conversations) {
    if (unreadCountOf(conversation) > 0) return conversation;
  }
  return conversations.isEmpty ? null : conversations.first;
}

class MessageService {
  static final MessageService instance = MessageService._internal();
  MessageService._internal();

  final HttpJsonClient _client = HttpJsonClient();
  final String _baseUrl = AppSession.apiBaseUrl;

  Future<MessageModel> saveMessage(
      {required String toUserId,
      required String text,
      String? conversationId,
      String? replyToMessageId,
      String? idempotencyKey}) async {
    final key = idempotencyKey ?? const Uuid().v4();
    final response = await _client.post(
      Uri.parse('$_baseUrl/messages'),
      headers: {
        'Idempotency-Key': key,
      },
      body: {
        'to_user_id': toUserId,
        if (conversationId != null) 'conversation_id': conversationId,
        if (replyToMessageId != null) 'reply_to_message_id': replyToMessageId,
        'text': text,
      },
    );

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return MessageModel.fromJson(
      Map<String, dynamic>.from(json['data'] as Map),
    );
  }

  Future<void> deleteMessage(String messageId, {required String scope}) async {
    await _client.delete(
      Uri.parse('$_baseUrl/messages/$messageId?scope=$scope'),
    );
  }

  Future<List<MessageModel>> fetchConversation(
    String userId, {
    String? conversationId,
    int limit = 50,
    int offset = 0,
  }) async {
    final response = await _client.get(
      conversationId == null
          ? Uri.parse(
              '$_baseUrl/messages/conversation/$userId?limit=$limit&offset=$offset')
          : Uri.parse(
              '$_baseUrl/messages/conversations/$conversationId/messages?limit=$limit&offset=$offset'),
      bypassCache: true,
    );

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final messages = (json['data']?['messages'] as List<dynamic>?)
            ?.map((m) => MessageModel.fromJson(m as Map<String, dynamic>))
            .toList() ??
        [];
    return messages;
  }

  Future<ConversationHistory> fetchGeneralConversationHistory(
    String userId, {
    required String userName,
    String? userAvatar,
    int limit = 50,
    int offset = 0,
  }) async {
    final response = await _client.get(
        Uri.parse(
          '$_baseUrl/messages/conversation/$userId?limit=$limit&offset=$offset',
        ),
        bypassCache: true);
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final data = Map<String, dynamic>.from(json['data'] as Map);
    final messages = (data['messages'] as List<dynamic>? ?? const [])
        .map((message) =>
            MessageModel.fromJson(Map<String, dynamic>.from(message as Map)))
        .toList();
    return ConversationHistory(
      conversation: ConversationModel(
        conversationId: data['conversation_id']?.toString(),
        userId: userId,
        userName: userName,
        userAvatar: userAvatar,
      ),
      messages: messages,
    );
  }

  Future<ConversationModel> initiatePropertyConversation(
      String propertyId) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/messages/conversations/initiate'),
      body: {'property_id': propertyId},
    );
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return ConversationModel.fromJson(
      Map<String, dynamic>.from(json['data']['conversation'] as Map),
    );
  }

  Future<ConversationHistory> fetchConversationById(
    String conversationId, {
    int limit = 50,
    int offset = 0,
  }) async {
    final response = await _client.get(
      Uri.parse(
        '$_baseUrl/messages/conversations/$conversationId/messages?limit=$limit&offset=$offset',
      ),
      bypassCache: true,
    );
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final data = Map<String, dynamic>.from(json['data'] as Map);
    final conversation = ConversationModel.fromJson(
      Map<String, dynamic>.from(data['conversation'] as Map),
    );
    final messages = (data['messages'] as List<dynamic>? ?? const [])
        .map((message) =>
            MessageModel.fromJson(Map<String, dynamic>.from(message as Map)))
        .toList();
    return ConversationHistory(conversation: conversation, messages: messages);
  }

  Future<List<ConversationModel>> fetchConversations() async {
    final response = await _client.get(
      Uri.parse('$_baseUrl/messages/conversations'),
      bypassCache: true,
    );

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final conversations = (json['data']?['conversations'] as List<dynamic>?)
            ?.map((c) => ConversationModel.fromJson(c as Map<String, dynamic>))
            .toList() ??
        [];
    return conversations;
  }

  Future<void> markAsRead(List<String> userIds,
      {List<String> conversationIds = const []}) async {
    if (userIds.isEmpty && conversationIds.isEmpty) return;

    await _client.post(
      Uri.parse('$_baseUrl/messages/mark-read'),
      body: {
        if (userIds.isNotEmpty) 'user_ids': userIds,
        if (conversationIds.isNotEmpty) 'conversation_ids': conversationIds,
      },
    );
  }

  Future<void> deleteConversation(String userId) async {
    await _client.delete(
      Uri.parse('$_baseUrl/messages/conversation/$userId'),
    );
  }

  Future<void> deleteConversationById(String conversationId) async {
    await _client.delete(
      Uri.parse('$_baseUrl/messages/conversations/$conversationId'),
    );
  }

  Future<List<ConversationModel>> fetchRecentContacts() async {
    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl/users/recent-contacts'),
      );

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return (json['data']?['contacts'] as List<dynamic>?)
              ?.map(
                  (c) => ConversationModel.fromJson(c as Map<String, dynamic>))
              .toList() ??
          [];
    } catch (err) {
      return [];
    }
  }
}
