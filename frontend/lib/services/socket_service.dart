import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:property_app/session/app_session.dart';

class SocketMessage {
  final String id;
  final String from;
  final String to;
  final String text;
  final int ts;

  SocketMessage(
      {required this.id,
      required this.from,
      required this.to,
      required this.text,
      required this.ts});

  factory SocketMessage.fromJson(Map<String, dynamic> json) {
    // Backend emits DB row:
    // { id, from_user_id, to_user_id, text, created_at }
    return SocketMessage(
      id: json['id']?.toString() ?? '',
      from: json['from_user_id']?.toString() ?? json['from']?.toString() ?? '',
      to: json['to_user_id']?.toString() ?? json['to']?.toString() ?? '',
      text: json['text']?.toString() ?? '',
      ts: _parseCreatedAtToEpochMillis(json['created_at'] ?? json['ts']),
    );
  }
}

int _parseCreatedAtToEpochMillis(Object? v) {
  if (v == null) return 0;
  if (v is int) return v;
  if (v is double) return v.toInt();
  if (v is String) {
    final trimmed = v.trim();
    final asInt = int.tryParse(trimmed);
    if (asInt != null) return asInt;
    final dt = DateTime.tryParse(trimmed);
    if (dt != null) return dt.millisecondsSinceEpoch;
  }
  return 0;
}

class SocketService {
  static final SocketService instance = SocketService._internal();
  SocketService._internal();

  io.Socket? _socket;
  final Set<String> _seenMessageKeys = <String>{};
  final StreamController<SocketMessage> _msgController =
      StreamController.broadcast();
  Stream<SocketMessage> get messages => _msgController.stream;

  final StreamController<Map<String, dynamic>> _presenceController =
      StreamController.broadcast();
  Stream<Map<String, dynamic>> get presence => _presenceController.stream;

  final StreamController<Map<String, dynamic>> _signalController =
      StreamController.broadcast();
  Stream<Map<String, dynamic>> get signals => _signalController.stream;

  final StreamController<Map<String, dynamic>> _typingController =
      StreamController.broadcast();
  Stream<Map<String, dynamic>> get typing => _typingController.stream;

  final StreamController<Map<String, dynamic>> _seenController =
      StreamController.broadcast();
  Stream<Map<String, dynamic>> get seen => _seenController.stream;

  void connect({String? url, String? token}) {
    _seenMessageKeys.clear();

    final base = url ?? AppSession.apiBaseUrl;
    // socket.io server runs at the host root (remove /api if present)
    final uri =
        base.replaceAll(RegExp(r'/api\/?\$'), '').replaceAll('/api', '');

    _socket = io.io(
        uri,
        io.OptionBuilder()
            .setTransports(['websocket'])
            .setExtraHeaders(
                {'Authorization': token != null ? 'Bearer $token' : ''})
            .setAuth({'token': token})
            .enableAutoConnect()
            .build());

    _socket?.onConnect((_) {
      // ignore
    });

    _socket?.on('message', (data) {
      final message = data is Map<String, dynamic>
          ? SocketMessage.fromJson(data)
          : data is Map
              ? SocketMessage.fromJson(Map<String, dynamic>.from(data))
              : null;
      if (message == null) return;

      final key = message.id.trim().isNotEmpty
          ? 'id:${message.id.trim()}'
          : 'fp:${message.from}:${message.to}:${message.text.trim().toLowerCase()}:${message.ts}';
      if (!_seenMessageKeys.add(key)) {
        return;
      }

      _msgController.add(message);
    });

    _socket?.on('presence', (data) {
      if (data is Map<String, dynamic>) _presenceController.add(data);
    });

    _socket?.on('typing', (data) {
      if (data is Map<String, dynamic>) _typingController.add(data);
    });

    _socket?.on('mark_seen', (data) {
      if (data is Map<String, dynamic>) _seenController.add(data);
    });

    _socket?.on('offer', (data) {
      _signalController.add({'type': 'offer', ...?data as Map?});
    });

    _socket?.on('answer', (data) {
      _signalController.add({'type': 'answer', ...?data as Map?});
    });

    _socket?.on('ice-candidate', (data) {
      _signalController.add({'type': 'ice', ...?data as Map?});
    });
  }

  void disconnect() {
    _socket?.disconnect();
    _socket = null;
  }

  void sendMessage({required String to, required String text}) {
    _socket?.emit('message', {'to': to, 'text': text});
  }

  void sendTyping({required String to, required bool isTyping}) {
    _socket?.emit('typing', {'to': to, 'isTyping': isTyping});
  }

  void markSeen({required String to, required List<String> messageIds}) {
    _socket?.emit('mark_seen', {'to': to, 'messageIds': messageIds});
  }

  void sendOffer({required String to, required Map<String, dynamic> sdp}) {
    _socket?.emit('offer', {'to': to, 'sdp': sdp});
  }

  void sendAnswer({required String to, required Map<String, dynamic> sdp}) {
    _socket?.emit('answer', {'to': to, 'sdp': sdp});
  }

  void sendIce({required String to, required Map<String, dynamic> candidate}) {
    _socket?.emit('ice-candidate', {'to': to, 'candidate': candidate});
  }

  void dispose() {
    _seenMessageKeys.clear();
    _msgController.close();
    _presenceController.close();
    _signalController.close();
    _typingController.close();
    _seenController.close();
  }
}
