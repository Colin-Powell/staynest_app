import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:property_app/models/property.dart';
import 'package:property_app/widgets/property_image.dart';
import 'booking_view.dart';

class PropertyDetails extends StatefulWidget {
  final Property property;
  final VoidCallback? onBack;
  final VoidCallback? onViewGallery;
  final VoidCallback? onViewAmenities;
  final VoidCallback? onViewLocation;
  final VoidCallback? onViewLandlord;
  final Function(String userId, String name, String avatar)? onMessage;
  final VoidCallback? onBook;

  const PropertyDetails({
    super.key,
    required this.property,
    this.onBack,
    this.onViewGallery,
    this.onViewAmenities,
    this.onViewLocation,
    this.onViewLandlord,
    this.onMessage,
    this.onBook,
  });

  @override
  State<PropertyDetails> createState() => _PropertyDetailsState();
}

class _PropertyDetailsState extends State<PropertyDetails> {
  @override
  Widget build(BuildContext context) {
    // Ensure we have at least 3 images for the spacious rooms preview
    final photos = widget.property.images != null &&
            widget.property.images!.isNotEmpty
        ? widget.property.images!
        : [widget.property.image, widget.property.image, widget.property.image];

    final previewPhotos = List<String>.from(photos);
    while (previewPhotos.length < 3) {
      previewPhotos.add(widget.property.image);
    }

    return Scaffold(
      backgroundColor: Colors.white,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12, top: 8, bottom: 8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.35)),
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new,
                      color: Colors.white, size: 18),
                  onPressed: widget.onBack ?? () => Navigator.pop(context),
                ),
              ),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.zero,
        child: Stack(
          children: [
            // Hero Image
            GestureDetector(
              onTap: widget.onViewGallery,
              child: Hero(
                tag: 'property-${widget.property.id}',
                child: buildPropertyImage(
                  widget.property.image,
                  width: double.infinity,
                  height: 380,
                  fit: BoxFit.cover,
                ),
              ),
            ),

            // Main Content Container
            Container(
              margin:
                  const EdgeInsets.only(top: 340), // Overlaps the image by 40px
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      widget.property.name,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        height: 1.2,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Rating and Location
                    Row(
                      children: [
                        const Icon(Icons.star_rounded,
                            color: Color(0xFFFBBF24), size: 24),
                        const SizedBox(width: 6),
                        Text(
                          '${widget.property.rating}',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => Navigator.pushNamed(context, '/reviews'),
                          behavior: HitTestBehavior.opaque,
                          child: const Text(
                            '(200 Reviews)',
                            style: TextStyle(
                              fontSize: 15,
                              color: Color(0xFF9CA3AF),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          widget.property.location,
                          style: const TextStyle(
                            fontSize: 15,
                            color: Color(0xFF9CA3AF),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Price
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          'Kes. ${widget.property.price ~/ 1000}k',
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: Colors.black,
                          ),
                        ),
                        const Text(
                          '/month',
                          style: TextStyle(
                            fontSize: 18,
                            color: Color(0xFF9CA3AF),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Property Tags
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _buildTag(Icons.apartment_rounded, 'Apartment', true),
                        _buildTag(
                            Icons.door_front_door_rounded, '4 Room', false),
                        _buildTag(Icons.bed_rounded, '2 beds', false),
                        _buildTag(Icons.weekend_rounded, 'Furnished', false),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // Spacious Rooms Area
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2F4FD),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              _buildWhiteCircleIcon(Icons.wifi),
                              const SizedBox(width: 16),
                              const Text(
                                'Spacious Rooms',
                                style: TextStyle(
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF6B72E2),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Column(
                                children: [
                                  _buildWhiteCircleIcon(
                                      Icons.water_drop_outlined),
                                  const SizedBox(height: 12),
                                  _buildWhiteCircleIcon(
                                      Icons.local_parking_rounded),
                                ],
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: GestureDetector(
                                  onTap: widget.onViewGallery,
                                  child: Row(
                                    children: [
                                      Expanded(
                                          child: _buildRoomImage(
                                              previewPhotos[0],
                                              height: 120)),
                                      const SizedBox(width: 10),
                                      Expanded(
                                          child: _buildRoomImage(
                                              previewPhotos[1],
                                              height: 120)),
                                      const SizedBox(width: 10),
                                      Expanded(
                                          child: _buildRoomImage(
                                              previewPhotos[2],
                                              height: 120)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // About Property Section
                    const Text(
                      'About Property',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.property.description ??
                          'Modern luxury apartment in the heart of Boston.\nClose to public transport, schools, and markets.',
                      style: const TextStyle(
                        fontSize: 15.5,
                        height: 1.6,
                        color: Color(0xFF9CA3AF),
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    const SizedBox(height: 28),

                    // Navigation Tabs
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildNavTab('Amenities',
                            onTap: widget.onViewAmenities),
                        _buildNavTab('Gallery', onTap: widget.onViewGallery),
                        _buildNavTab('Location', onTap: widget.onViewLocation),
                        _buildNavTab('Landlord', onTap: widget.onViewLandlord),
                      ],
                    ),

                    const SizedBox(height: 28),

                    // Bottom Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => widget.onMessage?.call(
                                widget.property.agent.userId,
                                widget.property.agent.name,
                                widget.property.agent.avatar),
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              height: 56,
                              decoration: BoxDecoration(
                                color: const Color(0xFFEEF2FF),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              alignment: Alignment.center,
                              child: const Text(
                                'Message',
                                style: TextStyle(
                                  color: Color(0xFF3F37C9),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => BookingView(
                                    propertyId: widget.property.id,
                                  ),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF3F37C9),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                            ),
                            child: const Text(
                              'Book a Visit',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTag(IconData icon, String label, bool isPrimary) {
    return Container(
      padding: const EdgeInsets.only(left: 6, right: 16, top: 6, bottom: 6),
      decoration: BoxDecoration(
        color: isPrimary ? const Color(0xFF3F37C9) : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 16,
              color:
                  isPrimary ? const Color(0xFF3F37C9) : const Color(0xFF9CA3AF),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
              color: isPrimary ? Colors.white : const Color(0xFF9CA3AF),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWhiteCircleIcon(IconData icon) {
    return Container(
      width: 40,
      height: 40,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        color: const Color(0xFF6B72E2),
        size: 22,
      ),
    );
  }

  Widget _buildRoomImage(String url, {double height = 120}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: buildPropertyImage(
        url,
        height: height,
        fit: BoxFit.cover,
      ),
    );
  }

  Widget _buildNavTab(String text, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Color(0xFF3F37C9),
        ),
      ),
    );
  }
}
