import 'package:flutter_test/flutter_test.dart';
import 'package:property_app/services/message_service.dart';

void main() {
  final conversations = [
    ConversationModel(userId: 'recent', userName: 'Recent'),
    ConversationModel(
      userId: 'unread',
      userName: 'Unread',
      unreadCount: 2,
    ),
  ];

  test('preserves a valid explicitly selected conversation', () {
    final selected = selectConversation<ConversationModel>(
      conversations: conversations,
      userIdOf: (conversation) => conversation.userId,
      unreadCountOf: (conversation) => conversation.unreadCount,
      selectedUserId: 'recent',
    );

    expect(selected?.userId, 'recent');
  });

  test('prefers an incoming conversation when no selection exists', () {
    final selected = selectConversation<ConversationModel>(
      conversations: conversations,
      userIdOf: (conversation) => conversation.userId,
      unreadCountOf: (conversation) => conversation.unreadCount,
      preferredUserId: 'recent',
    );

    expect(selected?.userId, 'recent');
  });

  test('otherwise chooses the first unread conversation before recency order',
      () {
    final selected = selectConversation<ConversationModel>(
      conversations: conversations,
      userIdOf: (conversation) => conversation.userId,
      unreadCountOf: (conversation) => conversation.unreadCount,
    );

    expect(selected?.userId, 'unread');
  });

  test('returns null when there are no conversations', () {
    final selected = selectConversation<ConversationModel>(
      conversations: const [],
      userIdOf: (conversation) => conversation.userId,
      unreadCountOf: (conversation) => conversation.unreadCount,
    );

    expect(selected, isNull);
  });

  test('selects a property-specific thread when a partner has multiple chats',
      () {
    final propertyA = ConversationModel.fromJson({
      'conversation_id': 'thread-a',
      'user_id': 'landlord',
      'user_name': 'Host',
      'context_type': 'property',
      'property': {
        'id': 'property-a',
        'title': 'Coast apartment',
        'location': 'Kilifi',
        'price': 18000,
        'availability_status': 'available',
      },
    });
    final propertyB = ConversationModel.fromJson({
      'conversation_id': 'thread-b',
      'user_id': 'landlord',
      'user_name': 'Host',
      'context_type': 'property',
      'property': {'id': 'property-b', 'title': 'Nairobi studio'},
    });

    final selected = selectConversation<ConversationModel>(
      conversations: [propertyA, propertyB],
      userIdOf: (conversation) => conversation.userId,
      unreadCountOf: (conversation) => conversation.unreadCount,
      selectedUserId: 'landlord',
      selectedConversationId: 'thread-b',
      conversationIdOf: (conversation) => conversation.conversationId ?? '',
    );

    expect(selected?.conversationId, 'thread-b');
    expect(propertyA.property?.id, 'property-a');
    expect(propertyA.property?.location, 'Kilifi');
    expect(propertyA.property?.price, 18000);
  });
}
