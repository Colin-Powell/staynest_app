import 'package:flutter/material.dart';

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
  bool _is360Fullscreen = false;
  double _rotationX = 0.0;
  double _rotationY = 0.0;

  static const _tabs = ['Photos', 'Videos', '360º', 'Floor Plan'];

  // Mock loading states for the new tabs
  final Map<String, bool> _loadingStates = {
    'Videos': true,
    '360º': true,
    'Floor Plan': true,
  };

  // Use local assets so the gallery is instant and offline-friendly.
  static const _fallbackPhotos = [
    'assets/images/hero.jpg',
    'assets/images/hero1.jpg',
    'assets/images/hero2.jpg',
    'assets/images/hero3.jpg',
    'assets/images/apertment1.jpg',
    'assets/images/apertment2.jpg',
  ];

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

  void _onPageChanged(int index) {
    setState(() {
      _pageIndex = index;
      _is360Fullscreen = false;
      _rotationX = 0.0;
      _rotationY = 0.0;
    });

    final tab = _tabs[index];
    if (_loadingStates[tab] == true) {
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) {
          setState(() {
            _loadingStates[tab] = false;
          });
        }
      });
    }
  }

  void _on360PanStart(DragStartDetails details) {
    setState(() {
      _is360Fullscreen = true;
    });
  }

  void _on360PanUpdate(DragUpdateDetails details) {
    setState(() {
      _rotationY += details.delta.dx * 0.008;
      _rotationX -= details.delta.dy * 0.008;
      _rotationX = _rotationX.clamp(-0.6, 0.6);
      _rotationY = _rotationY.clamp(-0.6, 0.6);
    });
  }

  void _on360PanEnd(DragEndDetails details) {
    Future.delayed(const Duration(milliseconds: 450), () {
      if (!mounted) return;
      setState(() {
        _is360Fullscreen = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.only(
                      top: 24, left: 24, right: 24, bottom: 24),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: widget.onClose,
                        behavior: HitTestBehavior.opaque,
                        child: const Icon(Icons.arrow_back,
                            size: 28, color: Colors.black),
                      ),
                      const SizedBox(width: 16),
                      const Text(
                        'Photo Gallery',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: Colors.black,
                          letterSpacing: -0.5,
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

                // Swipeable Pages
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: _onPageChanged,
                    itemCount: _tabs.length,
                    physics: const BouncingScrollPhysics(),
                    itemBuilder: (context, index) {
                      final tab = _tabs[index];
                      final images = widget.photos ?? _fallbackPhotos;
                      switch (tab) {
                        case 'Photos':
                          return _buildStaggeredGrid(images,
                              key: ValueKey('Photos-$index'));
                        case 'Videos':
                          return _buildStaggeredGrid(images,
                              isVideo: true, key: ValueKey('Videos-$index'));
                        case '360º':
                          return _build360View(images,
                              key: ValueKey('360-$index'));
                        case 'Floor Plan':
                          return _buildFloorPlan(
                              key: ValueKey('FloorPlan-$index'));
                        default:
                          return const SizedBox.shrink();
                      }
                    },
                  ),
                ),
              ],
            ),
            if (_is360Fullscreen && _tabs[_pageIndex] == '360º')
              Positioned.fill(
                child: _build360FullScreenOverlay(
                    widget.photos ?? _fallbackPhotos),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStaggeredGrid(List<String> images,
      {bool isVideo = false, Key? key}) {
    return GridView.builder(
      key: key,
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1,
      ),
      itemCount: images.length,
      itemBuilder: (context, index) {
        return _safeImage(
          images,
          index,
          height: double.infinity,
          isVideo: isVideo,
          aspectRatio: 1,
        );
      },
    );
  }

  Widget _build360View(List<String> images, {Key? key}) {
    return GestureDetector(
      onPanStart: _on360PanStart,
      onPanUpdate: _on360PanUpdate,
      onPanEnd: _on360PanEnd,
      onPanCancel: () => _on360PanEnd(DragEndDetails()),
      child: SingleChildScrollView(
        key: key,
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                _build360Scene(images, height: 400),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.threed_rotation,
                          color: Colors.white, size: 24),
                      SizedBox(width: 8),
                      Text(
                        'Drag to explore',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _build360FullScreenOverlay(List<String> images) {
    final availableHeight = MediaQuery.of(context).size.height -
        MediaQuery.of(context).padding.top -
        MediaQuery.of(context).padding.bottom -
        120;

    return GestureDetector(
      onPanStart: _on360PanStart,
      onPanUpdate: _on360PanUpdate,
      onPanEnd: _on360PanEnd,
      onPanCancel: () => _on360PanEnd(DragEndDetails()),
      child: ColoredBox(
        color: Colors.black,
        child: SafeArea(
          bottom: false,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Center(child: _build360Scene(images, height: availableHeight)),
              Positioned(
                left: 24,
                top: 24,
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _is360Fullscreen = false;
                    });
                  },
                  child: const CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.black54,
                    child: Icon(Icons.close, color: Colors.white, size: 20),
                  ),
                ),
              ),
              Positioned(
                left: 24,
                right: 24,
                bottom: 36,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: const Text(
                      'Drag to rotate 3D view',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _build360Scene(List<String> images, {double? height}) {
    final matrix = Matrix4.identity()
      ..setEntry(3, 2, 0.001)
      ..rotateX(_rotationX)
      ..rotateY(_rotationY);

    final scene = Transform(
      alignment: Alignment.center,
      transform: matrix,
      child: _safeImage(images, 0, height: height),
    );

    if (height != null) {
      return AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        height: height,
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 24),
        child: scene,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        width: double.infinity,
        child: scene,
      ),
    );
  }

  Widget _buildFloorPlan({Key? key}) {
    return Center(
      key: key,
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
            child: const Icon(Icons.architecture,
                size: 48, color: Color(0xFF9CA3AF)),
          ),
          const SizedBox(height: 24),
          const Text(
            'Floor plans are being prepared',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }

  Widget _safeImage(List<String> images, int index,
      {double? height, double aspectRatio = 1, bool isVideo = false}) {
    final content = index >= images.length
        ? Container(
            decoration: BoxDecoration(
              color: const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(24),
            ),
          )
        : ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: images[index].startsWith('http')
                ? Image.network(images[index],
                    width: double.infinity, fit: BoxFit.cover)
                : Image.asset(images[index],
                    width: double.infinity, fit: BoxFit.cover),
          );

    final contentStack = Stack(
      alignment: Alignment.center,
      children: [
        Positioned.fill(child: content),
        if (isVideo)
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.4),
              shape: BoxShape.circle,
              border:
                  Border.all(color: Colors.white.withOpacity(0.8), width: 2),
            ),
            child: const Icon(Icons.play_arrow_rounded,
                color: Colors.white, size: 36),
          ),
      ],
    );

    if (height != null) {
      return SizedBox(height: height, child: contentStack);
    }

    return AspectRatio(aspectRatio: aspectRatio, child: contentStack);
  }
}
