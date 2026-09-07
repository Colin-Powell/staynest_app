import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:video_player/video_player.dart';

import 'package:property_app/widgets/property_image.dart';
import 'package:property_app/session/app_session.dart';
import 'package:property_app/utils/property_image_url.dart';

// ─── Design System Constants ──────────────────────────────────────────────────
const Color _bg = Color(0xFFFAFAFA);
const Color _dark = Color(0xFF111827);
const Color _grey = Color(0xFF9CA3AF);
const Color _surface = Colors.white;

class PhotoGalleryView extends StatefulWidget {
  final VoidCallback onClose;
  final List<String>? photos;
  final String? videoUrl;

  const PhotoGalleryView({
    super.key,
    required this.onClose,
    this.photos,
    this.videoUrl,
  });

  @override
  State<PhotoGalleryView> createState() => _PhotoGalleryViewState();
}

class _PhotoGalleryViewState extends State<PhotoGalleryView> {
  late final PageController _pageController;
  int _pageIndex = 0;
  VideoPlayerController? _videoController;
  bool _videoLoading = false;
  String? _videoError;

  static const _tabs = ['Photos', 'Videos', '360º', 'Floor Plan'];
  static const _comingSoonTabs = {'360º', 'Floor Plan'};

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _pageIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  void _switchTab(int index) {
    if (_pageIndex == index) return;
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  void _onPageChanged(int index) {
    setState(() => _pageIndex = index);
    if (_tabs[index] == 'Videos') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadVideo();
      });
    } else {
      // Pause video when navigating away
      _videoController?.pause();
    }
  }

  Future<void> _loadVideo() async {
    if (_videoController != null ||
        _videoLoading ||
        widget.videoUrl?.trim().isNotEmpty != true) {
      return;
    }
    setState(() {
      _videoLoading = true;
      _videoError = null;
    });

    final controller = VideoPlayerController.networkUrl(
      Uri.parse(resolvePropertyVideoUrl(widget.videoUrl!)),
      httpHeaders: AppSession.apiToken == null
          ? const {}
          : {'Authorization': 'Bearer ${AppSession.apiToken}'},
    );

    try {
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _videoController = controller;
        _videoLoading = false;
      });
      // Auto-play muted for good UX
      controller.setVolume(0.0);
      controller.play();
    } catch (_) {
      await controller.dispose();
      if (mounted) {
        setState(() {
          _videoLoading = false;
          _videoError = 'This property video could not be loaded.';
        });
      }
    }
  }

  List<String> get _photos => widget.photos != null && widget.photos!.isNotEmpty
      ? widget.photos!
      : const [];

  void _openFullscreen(int startIndex) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        pageBuilder: (_, __, ___) => _FullscreenImageViewer(
          images: _photos,
          initialIndex: startIndex,
        ),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Header ───
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: widget.onClose,
                    behavior: HitTestBehavior.opaque,
                    child: const Icon(PhosphorIconsRegular.caretLeft,
                        size: 28, color: _dark),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'Gallery',
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: _dark,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  if (_photos.isNotEmpty && _pageIndex == 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                          color: _grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16)),
                      child: Text(
                        '${_photos.length} Photo${_photos.length == 1 ? '' : 's'}',
                        style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _dark),
                      ),
                    ),
                ],
              ),
            ),

            // ─── Pills Navigation ───
            SizedBox(
              height: 48,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: _tabs.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final tab = _tabs[index];
                  final active = index == _pageIndex;
                  return GestureDetector(
                    onTap: () => _switchTab(index),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: active ? _dark : _surface,
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: active ? _dark : _grey.withOpacity(0.2),
                          width: active ? 2.0 : 1.5,
                        ),
                      ),
                      child: Text(
                        tab,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight:
                              active ? FontWeight.w600 : FontWeight.w500,
                          color: active ? Colors.white : _dark,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 16),

            // ─── Content Pages ───
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                itemCount: _tabs.length,
                physics: const BouncingScrollPhysics(),
                itemBuilder: (context, index) {
                  final tab = _tabs[index];
                  if (tab == 'Videos')
                    return _buildVideoPage(key: const ValueKey('Videos'));
                  if (_comingSoonTabs.contains(tab))
                    return _buildComingSoon(tab, key: ValueKey('Soon-$tab'));

                  return _photos.isEmpty
                      ? _buildEmptyState(
                          PhosphorIconsRegular.image, 'No photos available.')
                      : _buildGrid(_photos, key: ValueKey('Photos-$index'));
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Video Player UI ───
  Widget _buildVideoPage({Key? key}) {
    if (widget.videoUrl?.trim().isNotEmpty != true) {
      return _buildEmptyState(PhosphorIconsRegular.videoCameraSlash,
          'No property video available.');
    }
    if (_videoError != null) {
      return _buildEmptyState(PhosphorIconsRegular.warningCircle, _videoError!,
          isError: true);
    }
    if (_videoLoading ||
        _videoController == null ||
        !_videoController!.value.isInitialized) {
      return const Center(child: CircularProgressIndicator(color: _dark));
    }

    final controller = _videoController!;
    return Center(
      key: key,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
        child: Container(
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 20,
                  offset: const Offset(0, 10))
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: AspectRatio(
              aspectRatio: controller.value.aspectRatio,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  VideoPlayer(controller),

                  // Play/Pause Overlay
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        controller.value.isPlaying
                            ? controller.pause()
                            : controller.play();
                      });
                    },
                    behavior: HitTestBehavior.opaque,
                    child: AnimatedOpacity(
                      opacity: controller.value.isPlaying ? 0.0 : 1.0,
                      duration: const Duration(milliseconds: 300),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.4),
                        ),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                shape: BoxShape.circle),
                            child: const Icon(PhosphorIconsFill.play,
                                color: Colors.white, size: 48),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Progress Indicator
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: VideoProgressIndicator(
                      controller,
                      allowScrubbing: true,
                      padding: const EdgeInsets.all(16),
                      colors: const VideoProgressColors(
                        playedColor: Colors.white,
                        bufferedColor: Colors.white30,
                        backgroundColor: Colors.white24,
                      ),
                    ),
                  ),

                  // Volume Toggle
                  Positioned(
                    top: 16,
                    right: 16,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          controller.value.volume > 0
                              ? controller.setVolume(0.0)
                              : controller.setVolume(1.0);
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                            color: Colors.black45, shape: BoxShape.circle),
                        child: Icon(
                            controller.value.volume > 0
                                ? PhosphorIconsFill.speakerHigh
                                : PhosphorIconsFill.speakerSlash,
                            color: Colors.white,
                            size: 20),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Photo Grid UI ───
  Widget _buildGrid(List<String> images, {Key? key}) {
    return GridView.builder(
      key: key,
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1, // Perfect squares
      ),
      itemCount: images.length,
      itemBuilder: (context, index) {
        return GestureDetector(
          onTap: () => _openFullscreen(index),
          child: Hero(
            tag: 'gallery_image_$index',
            child: Container(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4))
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: buildPropertyImage(
                  images[index],
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ─── Empty & Coming Soon States ───
  Widget _buildComingSoon(String tab, {Key? key}) {
    IconData icon;
    String message;
    switch (tab) {
      case '360º':
        icon = PhosphorIconsRegular.cube;
        message = 'Interactive 360° virtual tours are launching soon.';
        break;
      case 'Floor Plan':
        icon = PhosphorIconsRegular.blueprint;
        message = 'Detailed floor plans will be available shortly.';
        break;
      default:
        icon = PhosphorIconsRegular.hourglass;
        message = 'Coming soon.';
    }
    return _buildEmptyState(icon, message, key: key);
  }

  Widget _buildEmptyState(IconData icon, String message,
      {Key? key, bool isError = false}) {
    return Center(
      key: key,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                  color: isError
                      ? const Color(0xFFFEF2F2)
                      : _grey.withOpacity(0.1),
                  shape: BoxShape.circle),
              child: Icon(icon,
                  size: 48, color: isError ? const Color(0xFFEF4444) : _grey),
            ),
            const SizedBox(height: 24),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: isError ? const Color(0xFFEF4444) : _grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── FULLSCREEN VIEWER ────────────────────────────────────────────────────────

class _FullscreenImageViewer extends StatefulWidget {
  final List<String> images;
  final int initialIndex;

  const _FullscreenImageViewer({
    required this.images,
    required this.initialIndex,
  });

  @override
  State<_FullscreenImageViewer> createState() => _FullscreenImageViewerState();
}

class _FullscreenImageViewerState extends State<_FullscreenImageViewer>
    with SingleTickerProviderStateMixin {
  late final PageController _controller;
  late int _current;
  bool _showUI = true;
  late final AnimationController _uiAnimController;
  late final Animation<double> _uiAnim;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
    _uiAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      value: 1.0,
    );
    _uiAnim = CurvedAnimation(parent: _uiAnimController, curve: Curves.easeOut);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _controller.dispose();
    _uiAnimController.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _toggleUI() {
    setState(() => _showUI = !_showUI);
    _showUI ? _uiAnimController.forward() : _uiAnimController.reverse();
  }

  void _close() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    final safeTop = MediaQuery.of(context).padding.top;
    final safeBottom = MediaQuery.of(context).padding.bottom;
    final screenW = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.black, // Immersive dark mode
      body: Stack(
        children: [
          // ── Swipeable images ──
          GestureDetector(
            onTap: _toggleUI,
            child: PageView.builder(
              controller: _controller,
              itemCount: widget.images.length,
              physics: const BouncingScrollPhysics(),
              onPageChanged: (i) => setState(() => _current = i),
              itemBuilder: (context, index) => Hero(
                tag: 'gallery_image_$index',
                child: _ZoomableImage(url: widget.images[index]),
              ),
            ),
          ),

          // ── Top bar: close + counter ──
          Positioned(
            top: safeTop + 16,
            left: 24,
            right: 24,
            child: FadeTransition(
              opacity: _uiAnim,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _GlassCircleButton(
                      icon: PhosphorIconsRegular.x, onTap: _close),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                    ),
                    child: Text(
                      '${_current + 1} / ${widget.images.length}',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Side nav arrows (vertically centred on screen) ──
          if (widget.images.length > 1)
            Positioned.fill(
              child: FadeTransition(
                opacity: _uiAnim,
                child: Align(
                  alignment: Alignment.center,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        AnimatedOpacity(
                          opacity: _current > 0 ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 200),
                          child: _GlassCircleButton(
                            icon: PhosphorIconsRegular.caretLeft,
                            onTap: _current > 0
                                ? () => _controller.previousPage(
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeOutCubic)
                                : () {},
                          ),
                        ),
                        AnimatedOpacity(
                          opacity:
                              _current < widget.images.length - 1 ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 200),
                          child: _GlassCircleButton(
                            icon: PhosphorIconsRegular.caretRight,
                            onTap: _current < widget.images.length - 1
                                ? () => _controller.nextPage(
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeOutCubic)
                                : () {},
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // ── Bottom: dot indicators ──
          if (widget.images.length > 1)
            FadeTransition(
              opacity: _uiAnim,
              child: Positioned(
                bottom: safeBottom + 32,
                left: 0,
                right: 0,
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: screenW * 0.8),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(widget.images.length, (i) {
                          final active = i == _current;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: active ? 24 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: active
                                  ? Colors.white
                                  : Colors.white.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── ZOOMABLE IMAGE ───────────────────────────────────────────────────────────

class _ZoomableImage extends StatefulWidget {
  final String url;
  const _ZoomableImage({required this.url});

  @override
  State<_ZoomableImage> createState() => _ZoomableImageState();
}

class _ZoomableImageState extends State<_ZoomableImage> {
  final _transformationController = TransformationController();

  void _onDoubleTap() {
    if (_transformationController.value != Matrix4.identity()) {
      _transformationController.value = Matrix4.identity();
    } else {
      final size = MediaQuery.of(context).size;
      _transformationController.value = Matrix4.identity()
        ..translate(-size.width / 2, -size.height / 2)
        ..scale(2.5)
        ..translate(size.width / 2 / 2.5, size.height / 2 / 2.5);
    }
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTap: _onDoubleTap,
      child: InteractiveViewer(
        transformationController: _transformationController,
        minScale: 1.0,
        maxScale: 4.0,
        constrained: true,
        child: Center(
          child: SizedBox.expand(
            child: buildPropertyImage(
              widget.url,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── GLASS CIRCLE BUTTON ──────────────────────────────────────────────────────

class _GlassCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _GlassCircleButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }
}
