import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:property_app/session/app_session.dart';

class SocketMessage {
  final String id;
  final String? conversationId;
  final String from;
  final String to;
  final String text;
  final int ts;

  SocketMessage(
      {required this.id,
      this.conversationId,
      required this.from,
      required this.to,
      required this.text,
      required this.ts});

  factory SocketMessage.fromJson(Map<String, dynamic> json) {
    // Backend emits DB row:
    // { id, from_user_id, to_user_id, text, created_at }
    return SocketMessage(
      id: json['id']?.toString() ?? '',
      conversationId: json['conversation_id']?.toString(),
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
  Timer? _presenceHeartbeatTimer;
  final Map<String, Map<String, dynamic>> _latestPresenceByUser = {};
  final Set<String> _seenMessageKeys = <String>{};
  final StreamController<SocketMessage> _msgController =
      StreamController.broadcast();
  Stream<SocketMessage> get messages => _msgController.stream;

  final StreamController<Map<String, dynamic>> _presenceController =
      StreamController.broadcast();
  Stream<Map<String, dynamic>> get presence => _presenceController.stream;

  Map<String, dynamic>? latestPresenceFor(String userId) =>
      _latestPresenceByUser[userId];

  final StreamController<Map<String, dynamic>> _signalController =
      StreamController.broadcast();
  Stream<Map<String, dynamic>> get signals => _signalController.stream;

  final StreamController<Map<String, dynamic>> _typingController =
      StreamController.broadcast();
  Stream<Map<String, dynamic>> get typing => _typingController.stream;

  final StreamController<Map<String, dynamic>> _seenController =
      StreamController.broadcast();
  Stream<Map<String, dynamic>> get seen => _seenController.stream;

  final StreamController<Map<String, dynamic>> _deletedController =
      StreamController.broadcast();
  Stream<Map<String, dynamic>> get deleted => _deletedController.stream;

  final StreamController<Map<String, dynamic>> _deliveredController =
      StreamController.broadcast();
  Stream<Map<String, dynamic>> get delivered => _deliveredController.stream;

  final StreamController<bool> _connectionController =
      StreamController.broadcast();
  Stream<bool> get connectionChanges => _connectionController.stream;

  void connect({String? url, String? token}) {
    disconnect();
    _seenMessageKeys.clear();

    final base = url ?? AppSession.apiBaseUrl;
    // socket.io server runs at the host root (remove /api if present)
    final uri =
        base.replaceAll(RegExp(r'/api\/?\$'), '').replaceAll('/api', '');

    final socket = io.io(
        uri,
        io.OptionBuilder()
            .setTransports(['websocket'])
            .setExtraHeaders(
                {'Authorization': token != null ? 'Bearer $token' : ''})
            .setAuth({'token': token})
            .enableAutoConnect()
            .build());
    _socket = socket;

    socket.onConnect((_) {
      _connectionController.add(true);
      socket.emit('presence:heartbeat');
      _presenceHeartbeatTimer?.cancel();
      _presenceHeartbeatTimer = Timer.periodic(
        const Duration(seconds: 15),
        (_) => socket.emit('presence:heartbeat'),
      );
    });
    socket.onDisconnect((_) {
      _connectionController.add(false);
      _presenceHeartbeatTimer?.cancel();
    });

    socket.on('message', (data) {
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
      if (message.id.isNotEmpty) {
        markDelivered([message.id]);
      }
    });

    socket.on('presence', (data) {
      if (data is Map) {
        final presence = Map<String, dynamic>.from(data);
        final userId = presence['userId']?.toString();
        if (userId == null || userId.isEmpty) return;
        final revision =
            int.tryParse(presence['revision']?.toString() ?? '') ?? 0;
        final previousRevision = int.tryParse(
              _latestPresenceByUser[userId]?['revision']?.toString() ?? '',
            ) ??
            -1;
        if (revision < previousRevision) return;
        _latestPresenceByUser[userId] = presence;
        _presenceController.add(presence);
      }
    });

    socket.on('typing', (data) {
      if (data is Map) _typingController.add(Map<String, dynamic>.from(data));
    });

    socket.on('mark_seen', (data) {
      if (data is Map) _seenController.add(Map<String, dynamic>.from(data));
    });

    socket.on('message_deleted', (data) {
      if (data is Map) _deletedController.add(Map<String, dynamic>.from(data));
    });

    socket.on('message_delivered', (data) {
      if (data is Map) {
        _deliveredController.add(Map<String, dynamic>.from(data));
      }
    });

    socket.on('offer', (data) {
      _signalController.add({'type': 'offer', ...?data as Map?});
    });

    socket.on('answer', (data) {
      _signalController.add({'type': 'answer', ...?data as Map?});
    });

    socket.on('ice-candidate', (data) {
      _signalController.add({'type': 'ice', ...?data as Map?});
    });
  }

  void disconnect() {
    _presenceHeartbeatTimer?.cancel();
    _presenceHeartbeatTimer = null;
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _latestPresenceByUser.clear();
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

  void markDelivered(List<String> messageIds) {
    if (messageIds.isEmpty) return;
    _socket?.emit('message_delivered', {'messageIds': messageIds});
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
    _deletedController.close();
    _deliveredController.close();
    _connectionController.close();
  }
}
