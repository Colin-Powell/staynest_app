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
}
