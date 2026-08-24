import 'dart:async';
import 'package:flutter/material.dart';
import 'package:property_app/widgets/property_image.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:property_app/services/call_service.dart';
import 'package:property_app/services/socket_service.dart';

const Color _primary = Color(0xFF6366F1);

class CallingView extends StatefulWidget {
  final String userId;
  final String name;
  final String avatar;
  final VoidCallback onEndCall;

  const CallingView({
    super.key,
    required this.userId,
    required this.name,
    required this.avatar,
    required this.onEndCall,
  });

  @override
  State<CallingView> createState() => _CallingViewState();
}

class _CallingViewState extends State<CallingView>
    with TickerProviderStateMixin {
  // Entry animation
  late final AnimationController _entryController;
  late final Animation<Offset> _entrySlide;
  late final Animation<double> _entryFade;

  // Ping pulse animation
  late final AnimationController _pingController;

  StreamSubscription? _signalSubscription;
  // Call timer
  late final Timer _timer;
  int _seconds = 0;
  bool _isMuted = false;
  bool _isVideoOn = true;

  @override
  void initState() {
    super.initState();

    // Entry
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _entrySlide = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
        .animate(
            CurvedAnimation(parent: _entryController, curve: Curves.easeOut));
    _entryFade =
        CurvedAnimation(parent: _entryController, curve: Curves.easeIn);
    _entryController.forward();

    // Ping
    _pingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    // Timer
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _seconds++);
    });

    // Initialize call
    _initializeCall();

    // Listen to socket signals
    _signalSubscription = SocketService.instance.signals.listen((signal) {
      if (signal['type'] == 'answer' && signal['from'] == widget.userId) {
        _handleRemoteAnswer(signal);
      } else if (signal['type'] == 'ice' && signal['from'] == widget.userId) {
        _handleIceCandidate(signal);
      }
    });
  }

  @override
  void dispose() {
    _entryController.dispose();
    _pingController.dispose();
    _signalSubscription?.cancel();
    _timer.cancel();
    CallService.instance.close();
    super.dispose();
  }

  Future<void> _initializeCall() async {
    try {
      // Get local media stream
      await CallService.instance.getLocalStream(audio: true, video: _isVideoOn);

      // Create peer connection
      await CallService.instance.initializePeerConnection();

      // Send offer to remote peer
      final offer = await CallService.instance.createOffer();
      SocketService.instance.sendOffer(
        to: widget.userId,
        sdp: {
          'type': offer.type,
          'sdp': offer.sdp,
        },
      );

      // Listen for ICE candidates and send them
      CallService.instance.onLocalIceCandidate((candidate) {
        SocketService.instance.sendIce(
          to: widget.userId,
          candidate: {
            'candidate': candidate.candidate,
            'sdpMLineIndex': candidate.sdpMLineIndex,
            'sdpMid': candidate.sdpMid,
          },
        );
      });

      if (mounted) setState(() {});
    } catch (err) {
      // ignore: avoid_print
      print('Failed to initialize call: $err');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to initialize call')),
        );
        widget.onEndCall();
      }
    }
  }

  void _handleRemoteAnswer(Map<String, dynamic> signal) {
    try {
      final sdp = signal['sdp'] as Map<String, dynamic>?;
      if (sdp == null) return;

      final answer = RTCSessionDescription(
        sdp['sdp'] as String,
        sdp['type'] as String,
      );
      CallService.instance.setRemoteDescription(answer);
    } catch (err) {
      // ignore: avoid_print
      print('Failed to handle remote answer: $err');
    }
  }

  void _handleIceCandidate(Map<String, dynamic> signal) {
    try {
      final candidate = signal['candidate'] as Map<String, dynamic>?;
      if (candidate == null) return;

      final iceCandidate = RTCIceCandidate(
        candidate['candidate'] as String,
        candidate['sdpMid'] as String?,
        candidate['sdpMLineIndex'] as int?,
      );
      CallService.instance.addIceCandidate(iceCandidate);
    } catch (err) {
      // ignore: avoid_print
      print('Failed to add ICE candidate: $err');
    }
  }

  void _toggleVideo() {
    setState(() {
      _isVideoOn = !_isVideoOn;
    });
  }

  String get _formattedTime {
    final m = (_seconds ~/ 60).toString().padLeft(2, '0');
    final s = (_seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _entrySlide,
      child: FadeTransition(
        opacity: _entryFade,
        child: Scaffold(
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0F172A),
                  Color(0xFF1E1B4B),
                  Color(0xFF0F172A)
                ],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  _buildTopBar(),
                  Expanded(child: _buildCenterContent()),
                  _buildControlsBar(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Top bar ────────────────────────────────────────────────────────────────

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: widget.onEndCall,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.12)),
              ),
              child: const Icon(Icons.close_rounded,
                  color: Colors.white, size: 22),
            ),
          ),
          const Spacer(),
          Text(
            _formattedTime,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 1.2,
            ),
          ),
          const Spacer(),
          const SizedBox(width: 42),
        ],
      ),
    );
  }

  // ─── Center – avatar + name ──────────────────────────────────────────────────

  Widget _buildCenterContent() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Calling',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: Colors.white.withOpacity(0.65),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          widget.name,
          style: const TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: -0.6,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        Text(
          'Ringing on mobile',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.white.withOpacity(0.58),
          ),
        ),
        const SizedBox(height: 36),
        // Ping avatar
        SizedBox(
          width: 190,
          height: 190,
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedBuilder(
                animation: _pingController,
                builder: (_, __) {
                  final scale = 1.0 + _pingController.value * 0.55;
                  final opacity = (1.0 - _pingController.value) * 0.18;
                  return Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _primary.withOpacity(opacity),
                      ),
                    ),
                  );
                },
              ),
              AnimatedBuilder(
                animation: _pingController,
                builder: (_, __) {
                  final scale = 1.0 + _pingController.value * 0.28;
                  final opacity = (1.0 - _pingController.value) * 0.12;
                  return Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 152,
                      height: 152,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(opacity),
                      ),
                    ),
                  );
                },
              ),
              Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: Colors.white.withOpacity(0.18), width: 4),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x40000000),
                      blurRadius: 22,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: buildPropertyImage(
                    widget.avatar,
                    width: 150,
                    height: 150,
                    fit: BoxFit.cover,
                    errorPlaceholder: Container(
                      color: const Color(0xFF334155),
                      child: const Icon(Icons.person,
                          color: Colors.white54, size: 56),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  // ─── Controls ────────────────────────────────────────────────────────────────

  Widget _buildControlsBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Mute
          _CallButton(
            icon: _isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
            label: _isMuted ? 'Unmute' : 'Mute',
            bgColor: _isMuted
                ? Colors.white.withOpacity(0.22)
                : Colors.white.withOpacity(0.1),
            iconColor: Colors.white,
            size: 62,
            onTap: () => setState(() => _isMuted = !_isMuted),
          ),
          // End call (larger)
          _CallButton(
            icon: Icons.call_end_rounded,
            label: 'End',
            bgColor: const Color(0xFFEF4444),
            iconColor: Colors.white,
            size: 78,
            shadowColor: const Color(0xFFEF4444),
            onTap: widget.onEndCall,
          ),
          // Video
          _CallButton(
            icon: _isVideoOn
                ? Icons.videocam_rounded
                : Icons.videocam_off_rounded,
            label: _isVideoOn ? 'Video' : 'No Video',
            bgColor: _isVideoOn
                ? Colors.white.withOpacity(0.1)
                : Colors.white.withOpacity(0.22),
            iconColor: Colors.white,
            size: 62,
            onTap: _toggleVideo,
          ),
        ],
      ),
    );
  }
}

// ─── Reusable Call Button ─────────────────────────────────────────────────────

class _CallButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color bgColor;
  final Color iconColor;
  final double size;
  final Color? shadowColor;
  final VoidCallback onTap;

  const _CallButton({
    required this.icon,
    required this.label,
    required this.bgColor,
    required this.iconColor,
    required this.size,
    required this.onTap,
    this.shadowColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
              border: shadowColor == null
                  ? Border.all(
                      color: Colors.white.withOpacity(0.15), width: 1.2)
                  : null,
              boxShadow: shadowColor != null
                  ? [
                      BoxShadow(
                        color: shadowColor!.withOpacity(0.28),
                        blurRadius: 22,
                        offset: const Offset(0, 10),
                      )
                    ]
                  : null,
            ),
            child: Icon(icon, color: iconColor, size: size * 0.44),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.white.withOpacity(0.75),
          ),
        ),
      ],
    );
  }
}
