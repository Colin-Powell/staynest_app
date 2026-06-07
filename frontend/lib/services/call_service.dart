import 'package:flutter_webrtc/flutter_webrtc.dart';

class RTCConfig {
  static final Map<String, dynamic> rtcConfiguration = {
    'iceServers': [
      {
        'urls': [
          'stun:stun.l.google.com:19302',
          'stun:stun1.l.google.com:19302',
        ]
      }
    ]
  };
}

class CallService {
  static final CallService instance = CallService._internal();
  CallService._internal();

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  final List<RTCIceCandidate> _iceCandidates = [];

  // Callbacks
  final List<Function(RTCIceCandidate)> _onLocalIceCandidate = [];
  final List<Function()> _onRemoteStreamAdded = [];
  final List<Function()> _onConnectionStateChange = [];

  void onLocalIceCandidate(Function(RTCIceCandidate) callback) {
    _onLocalIceCandidate.add(callback);
  }

  void onRemoteStreamAdded(Function() callback) {
    _onRemoteStreamAdded.add(callback);
  }

  void onConnectionStateChange(Function() callback) {
    _onConnectionStateChange.add(callback);
  }

  Future<MediaStream> getLocalStream({
    bool audio = true,
    bool video = true,
  }) async {
    try {
      final stream = await navigator.mediaDevices.getUserMedia({
        'audio': audio,
        'video': video
            ? {
                'mandatory': {
                  'minWidth': 640,
                  'minHeight': 480,
                  'minFrameRate': 30,
                },
                'facingMode': 'user',
                'optional': [],
              }
            : false,
      });
      _localStream = stream;
      return stream;
    } catch (err) {
      rethrow;
    }
  }

  Future<void> initializePeerConnection() async {
    try {
      _peerConnection = await createPeerConnection(
        RTCConfig.rtcConfiguration,
      );

      if (_localStream != null) {
        for (final track in _localStream!.getTracks()) {
          await _peerConnection?.addTrack(track, _localStream!);
        }
      }

      _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
        _iceCandidates.add(candidate);
        for (final callback in _onLocalIceCandidate) {
          callback(candidate);
        }
      };

      _peerConnection!.onAddStream = (MediaStream stream) {
        for (final callback in _onRemoteStreamAdded) {
          callback();
        }
      };

      _peerConnection!.onConnectionState = (RTCPeerConnectionState state) {
        for (final callback in _onConnectionStateChange) {
          callback();
        }
      };
    } catch (err) {
      rethrow;
    }
  }

  Future<RTCSessionDescription> createOffer() async {
    try {
      final offer = await _peerConnection!.createOffer({
        'offerToReceiveAudio': true,
        'offerToReceiveVideo': true,
      });
      await _peerConnection!.setLocalDescription(offer);
      return offer;
    } catch (err) {
      rethrow;
    }
  }

  Future<void> setRemoteDescription(RTCSessionDescription description) async {
    try {
      await _peerConnection!.setRemoteDescription(description);
    } catch (err) {
      rethrow;
    }
  }

  Future<RTCSessionDescription> createAnswer() async {
    try {
      final answer = await _peerConnection!.createAnswer({
        'offerToReceiveAudio': true,
        'offerToReceiveVideo': true,
      });
      await _peerConnection!.setLocalDescription(answer);
      return answer;
    } catch (err) {
      rethrow;
    }
  }

  Future<void> addIceCandidate(RTCIceCandidate candidate) async {
    try {
      await _peerConnection!.addCandidate(candidate);
    } catch (err) {
      rethrow;
    }
  }

  Future<void> close() async {
    try {
      if (_localStream != null) {
        for (final track in _localStream!.getTracks()) {
          await track.stop();
        }
        await _localStream!.dispose();
        _localStream = null;
      }
      await _peerConnection?.close();
      _peerConnection = null;
      _iceCandidates.clear();
    } catch (err) {
      rethrow;
    }
  }

  MediaStream? getLocalStream_() => _localStream;
  RTCPeerConnection? getPeerConnection() => _peerConnection;
}
