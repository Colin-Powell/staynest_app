export '../data.dart';
export '../models/property.dart';

class ChatItem {
  final int id;
  final String name;
  final String message;
  final String avatar;
  final String time;
  final bool online;
  final int unread;

  const ChatItem({
    required this.id,
    required this.name,
    required this.message,
    required this.avatar,
    required this.time,
    this.online = false,
    this.unread = 0,
  });

  String get msg => message;
}

const List<ChatItem> chats = [
  ChatItem(
    id: 1,
    name: 'Samuel Mwangi',
    message: 'Yes, the unit is still available. When would you like to visit?',
    avatar: 'https://i.pravatar.cc/150?img=15',
    time: '2m',
    online: true,
    unread: 2,
  ),
  ChatItem(
    id: 2,
    name: 'Aisha Njeri',
    message: 'Can I schedule a viewing for tomorrow afternoon?',
    avatar: 'https://i.pravatar.cc/150?img=20',
    time: '12m',
    online: false,
    unread: 0,
  ),
  ChatItem(
    id: 3,
    name: 'Brian Otieno',
    message: 'How long is the lease term?',
    avatar: 'https://i.pravatar.cc/150?img=28',
    time: '1h',
    online: true,
    unread: 1,
  ),
  ChatItem(
    id: 4,
    name: 'Mary Wanja',
    message: 'I have a question about the parking.',
    avatar: 'https://i.pravatar.cc/150?img=33',
    time: '3h',
    online: false,
    unread: 0,
  ),
];
