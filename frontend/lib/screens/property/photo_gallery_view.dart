import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:property_app/widgets/property_image.dart';

class PhotoGalleryView extends StatefulWidget {
  final VoidCallback onClose;
  final List<String>? photos;

  const PhotoGalleryView({
    super.key,
    required this.onClose,
    this.photos,
  });

  @override
  State<PhotoGalleryView> createState() => _PhotoGalleryViewState();
}

class _PhotoGalleryViewState extends State<PhotoGalleryView> {
  late final PageController _pageController;
  int _pageIndex = 0;

  static const _tabs = ['Photos', 'Videos', '360º', 'Floor Plan'];
  static const _comingSoonTabs = {'Videos', '360º', 'Floor Plan'};

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _pageIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _switchTab(int index) {
    if (_pageIndex == index) return;
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  void _onPageChanged(int index) => setState(() => _pageIndex = index);

  List<String> get _photos {
    if (widget.photos != null && widget.photos!.isNotEmpty) {
      return widget.photos!;
    }
    return const [];
  }

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
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: widget.onClose,
                    behavior: HitTestBehavior.opaque,
                    child: const Icon(Icons.arrow_back,
                        size: 28, color: Colors.black),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Text(
                      'Photo Gallery',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  if (_photos.isNotEmpty)
                    Text(
                      '${_photos.length} photo${_photos.length == 1 ? '' : 's'}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                ],
              ),
            ),

            // Tabs
            SizedBox(
              height: 44,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                scrollDirection: Axis.horizontal,
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 10),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: active
                            ? const Color(0xFF3F37C9)
                            : const Color(0xFFE5E7EB),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Text(
                        tab,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight:
                              active ? FontWeight.w800 : FontWeight.w700,
                          color: active ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 24),

            // Pages
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                itemCount: _tabs.length,
                physics: const BouncingScrollPhysics(),
                itemBuilder: (context, index) {
                  final tab = _tabs[index];
                  if (_comingSoonTabs.contains(tab)) {
                    return _buildComingSoon(tab, key: ValueKey('Soon-$tab'));
                  }
                  switch (tab) {
                    case 'Photos':
                      return _photos.isEmpty
                          ? _buildEmptyPhotos(
                              key: const ValueKey('Photos-empty'))
                          : _buildGrid(_photos,
                              key: ValueKey('Photos-$index'));
                    default:
                      return const SizedBox.shrink();
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid(List<String> images, {Key? key}) {
    return GridView.builder(
      key: key,
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1,
      ),
      itemCount: images.length,
      itemBuilder: (context, index) {
        return GestureDetector(
          onTap: () => _openFullscreen(index),
          child: Hero(
            tag: 'gallery_image_$index',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: buildPropertyImage(
                images[index],
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildComingSoon(String tab, {Key? key}) {
    IconData icon;
    String message;
    switch (tab) {
      case 'Videos':
        icon = Icons.play_circle_outline;
        message = 'Property video tours are coming soon.';
        break;
      case '360º':
        icon = Icons.threed_rotation;
        message = '360° virtual tours are coming soon.';
        break;
      case 'Floor Plan':
        icon = Icons.architecture;
        message = 'Interactive floor plans are coming soon.';
        break;
      default:
        icon = Icons.hourglass_empty;
        message = 'Coming soon.';
    }
    return Center(
      key: key,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: const BoxDecoration(
                color: Color(0xFFE5E7EB),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 48, color: const Color(0xFF9CA3AF)),
            ),
            const SizedBox(height: 24),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyPhotos({Key? key}) {
    return Center(
      key: key,
      child: const Text(
        'No photos available for this property.',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Color(0xFF6B7280),
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
      backgroundColor: Colors.black,
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
          FadeTransition(
            opacity: _uiAnim,
            child: Positioned(
              top: safeTop + 12,
              left: 16,
              right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _CircleButton(icon: Icons.close, onTap: _close),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_current + 1} / ${widget.images.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
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
            FadeTransition(
              opacity: _uiAnim,
              child: Positioned.fill(
                child: Align(
                  alignment: Alignment.center,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        AnimatedOpacity(
                          opacity: _current > 0 ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 200),
                          child: _CircleButton(
                            icon: Icons.chevron_left,
                            onTap: _current > 0
                                ? () => _controller.previousPage(
                                      duration:
                                          const Duration(milliseconds: 300),
                                      curve: Curves.easeOutCubic,
                                    )
                                : () {},
                          ),
                        ),
                        AnimatedOpacity(
                          opacity:
                              _current < widget.images.length - 1 ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 200),
                          child: _CircleButton(
                            icon: Icons.chevron_right,
                            onTap: _current < widget.images.length - 1
                                ? () => _controller.nextPage(
                                      duration:
                                          const Duration(milliseconds: 300),
                                      curve: Curves.easeOutCubic,
                                    )
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
                bottom: safeBottom + 24,
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
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: active ? 20 : 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: active
                                  ? Colors.white
                                  : Colors.white.withOpacity(0.4),
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
        child: Center(
          child: buildPropertyImage(
            widget.url,
            width: double.infinity,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}

// ─── CIRCLE BUTTON ────────────────────────────────────────────────────────────

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.black54,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white24),
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}