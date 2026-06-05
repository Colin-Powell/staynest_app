import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:property_app/session/app_session.dart';

class SocketMessage {
  final String from;
  final String to;
  final String text;
  final int ts;

  SocketMessage({required this.from, required this.to, required this.text, required this.ts});

  factory SocketMessage.fromJson(Map<String, dynamic> json) {
    return SocketMessage(
      from: json['from']?.toString() ?? '',
      to: json['to']?.toString() ?? '',
      text: json['text']?.toString() ?? '',
      ts: (json['ts'] is int) ? json['ts'] as int : int.tryParse(json['ts']?.toString() ?? '') ?? 0,
    );
  }
}

class SocketService {
  static final SocketService instance = SocketService._internal();
  SocketService._internal();

  IO.Socket? _socket;
  final StreamController<SocketMessage> _msgController = StreamController.broadcast();
  Stream<SocketMessage> get messages => _msgController.stream;

  final StreamController<Map<String, dynamic>> _signalController = StreamController.broadcast();
  Stream<Map<String, dynamic>> get signals => _signalController.stream;

  void connect({String? url, String? token}) {
    final base = url ?? AppSession.apiBaseUrl;
    // socket.io server runs at the host root (remove /api if present)
    final uri = base.replaceAll(RegExp(r'/api\/?\$'), '').replaceAll('/api', '');

    _socket = IO.io(uri, IO.OptionBuilder()
        .setTransports(['websocket'])
        .setExtraHeaders({'Authorization': token != null ? 'Bearer $token' : ''})
        .setAuth({'token': token})
        .enableAutoConnect()
        .build());

    _socket?.onConnect((_) {
      // ignore
    });

    _socket?.on('message', (data) {
      if (data is Map<String, dynamic>) {
        _msgController.add(SocketMessage.fromJson(data));
      }
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
    _msgController.close();
    _signalController.close();
  }
}
