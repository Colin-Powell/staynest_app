import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:property_app/services/properties_api.dart';
import 'package:property_app/widgets/property_image.dart';

class LandlordPropertiesPage extends StatefulWidget {
  final VoidCallback onAddProperty;

  const LandlordPropertiesPage({super.key, required this.onAddProperty});

  @override
  State<LandlordPropertiesPage> createState() => _LandlordPropertiesPageState();
}

class _LandlordPropertiesPageState extends State<LandlordPropertiesPage> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'All';
  bool _isLoading = true;
  String? _errorMessage;

  final List<String> _filters = ['All', 'Published', 'Draft', 'In Review'];
  List<Map<String, dynamic>> _properties = [];

  @override
  void initState() {
    super.initState();
    _loadProperties();
  }

  Future<void> _loadProperties() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final properties = await PropertiesApi.getLandlordProperties();
      setState(() {
        _properties = properties;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load properties: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredProperties {
    final query = _searchController.text.trim().toLowerCase();

    return _properties.where((property) {
      final matchesFilter =
          _selectedFilter == 'All' || property['status'] == _selectedFilter;
      final matchesSearch = query.isEmpty ||
          property['title'].toLowerCase().contains(query) ||
          property['location'].toLowerCase().contains(query);
      return matchesFilter && matchesSearch;
    }).toList();
  }

  int _countForFilter(String filter) {
    return filter == 'All'
        ? _properties.length
        : _properties.where((property) => property['status'] == filter).length;
  }

  void _onSearchChanged(String value) {
    setState(() {});
  }

  void _onFilterChanged(String filter) {
    if (_selectedFilter == filter) return;
    setState(() {
      _selectedFilter = filter;
    });
  }

  Future<void> _onPropertyTap(Map<String, dynamic> property) async {
    if (property['status'] == 'Draft') {
      Navigator.pushNamed(context, '/list_property');
      return;
    }

    final result = await Navigator.pushNamed(
      context,
      '/landlord_property_management',
      arguments: property,
    );

    if (result is Map<String, dynamic>) {
      final action = result['action'] as String?;
      final id = result['id'] as String?;
      if (action == 'delete' && id != null) {
        setState(() {
          _properties.removeWhere((item) => item['id'] == id);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Property removed from your portfolio.')),
          );
        }
      } else if (action == 'confirm_rented' && id != null) {
        setState(() {
          final index = _properties.indexWhere((item) => item['id'] == id);
          if (index >= 0) {
            _properties[index]['status'] = 'Rented';
          }
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Property marked as rented.')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Background Gradient
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFE8F6EF), Colors.white],
                ),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                _buildFilterTabs(),
                _buildSearchBar(),
                Expanded(
                  child:
                      _isLoading ? _buildSkeletonList() : _buildPropertyList(),
                ),
              ],
            ),
          ),
          _buildFloatingAddButton(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'My Properties',
            style: GoogleFonts.poppins(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF111827),
            ),
          ),
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pushNamed(context, '/landlord_tenants'),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: Color(0xFFE5E7EB),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.people,
                      size: 24, color: Color(0xFF111827)),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: Color(0xFFE5E7EB),
                  shape: BoxShape.circle,
                ),
                child:
                    Icon(PhosphorIcons.bell(PhosphorIconsStyle.fill), size: 24),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTabs() {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: _filters.length,
        itemBuilder: (context, index) {
          final filter = _filters[index];
          final isSelected = _selectedFilter == filter;
          return GestureDetector(
            onTap: () => _onFilterChanged(filter),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                color:
                    isSelected ? const Color(0xFFCFF1E1) : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              alignment: Alignment.center,
              child: Text(
                filter == 'All'
                    ? 'All(${_countForFilter('All')})'
                    : '$filter(${_countForFilter(filter)})',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? const Color(0xFF059669)
                      : const Color(0xFF6B7280),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
      child: Row(
        children: [
          Expanded(
            child: _GlassContainer(
              opacity: 0.4,
              borderRadius: BorderRadius.circular(16),
              padding: EdgeInsets.zero,
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Search listings',
                  hintStyle: GoogleFonts.poppins(
                      color: const Color(0xFF9CA3AF), fontSize: 14),
                  prefixIcon: Icon(PhosphorIcons.magnifyingGlass(),
                      color: const Color(0xFF111827), size: 22),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Icon(PhosphorIcons.slidersHorizontal(PhosphorIconsStyle.bold),
              size: 22),
          const SizedBox(width: 8),
          Text(
            'Filters',
            style:
                GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15),
          )
        ],
      ),
    );
  }

  Widget _buildPropertyList() {
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 18),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadProperties,
                child: Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final filtered = _filteredProperties;

    if (filtered.isEmpty) {
      return _buildNoResults();
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 140),
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, index) => _PropertyCard(
        data: filtered[index],
        onTap: () => _onPropertyTap(filtered[index]),
      ),
    );
  }

  Widget _buildNoResults() {
    if (_properties.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.home_outlined,
                  size: 48, color: const Color(0xFF9CA3AF)),
              const SizedBox(height: 18),
              Text(
                'No properties yet.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tap the + button to add your first property.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: const Color(0xFF9CA3AF),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(PhosphorIcons.magnifyingGlass(),
                size: 48, color: const Color(0xFF9CA3AF)),
            const SizedBox(height: 18),
            Text(
              'No properties match your search or filter.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      itemCount: 3,
      itemBuilder: (context, index) => Container(
        height: 130,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(24)),
      ),
    );
  }

  Widget _buildFloatingAddButton() {
    return Positioned(
      bottom: 100,
      left: 24,
      right: 24,
      child: _GlassContainer(
        opacity: 0.7,
        color: const Color(0xFF86C8A7),
        borderRadius: BorderRadius.circular(20),
        padding: EdgeInsets.zero,
        child: InkWell(
          onTap: widget.onAddProperty,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            height: 60,
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.add, color: Colors.white, size: 28),
                const SizedBox(width: 8),
                Text(
                  'Add New Property',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PropertyCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onTap;

  const _PropertyCard({required this.data, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: _GlassContainer(
        padding: EdgeInsets.zero,
        borderRadius: BorderRadius.circular(28),
        child: SizedBox(
          height: 140,
          child: Row(
            children: [
              ClipRRect(
                borderRadius:
                    const BorderRadius.horizontal(left: Radius.circular(28)),
                child: buildPropertyImage(
                  (data['image_url'] ?? data['image'] ?? '') as String,
                  width: 115,
                  height: 140,
                  fit: BoxFit.cover,
                  errorPlaceholder: Container(
                    width: 115,
                    height: 140,
                    color: const Color(0xFFE8F6EF),
                    child: Icon(
                      PhosphorIcons.buildings(PhosphorIconsStyle.fill),
                      size: 30,
                      color: const Color(0xFF059669),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 16, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (data['title'] ?? '').toString(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        (data['city'] ?? data['location'] ?? '').toString(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF9CA3AF),
                        ),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Expanded(
                            child: RichText(
                              overflow: TextOverflow.ellipsis,
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text: 'Kes. ${data['price']}',
                                    style: GoogleFonts.poppins(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF111827),
                                    ),
                                  ),
                                  TextSpan(
                                    text: '/month',
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      color: const Color(0xFF9CA3AF),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildStatusBadge(
                              (data['status'] ?? 'Available').toString()),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(
                            PhosphorIcons.eye(),
                            size: 16,
                            color: const Color(0xFF9CA3AF),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            (data['views'] ?? '0').toString(),
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: const Color(0xFF9CA3AF),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Icon(
                            PhosphorIcons.heart(PhosphorIconsStyle.fill),
                            size: 16,
                            color: const Color(0xFFF43F5E),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            (data['likes'] ?? '0').toString(),
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: const Color(0xFF9CA3AF),
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
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    bool isDraft = status == 'Draft';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isDraft ? const Color(0xFFF3F4F6) : const Color(0xFFD1FAE5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status,
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: isDraft ? const Color(0xFF6B7280) : const Color(0xFF059669),
        ),
      ),
    );
  }
}

// Reusable Glassmorphism Container
class _GlassContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;
  final double opacity;
  final Color? color;

  const _GlassContainer({
    required this.child,
    required this.padding,
    required this.borderRadius,
    this.opacity = 0.5,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: (color ?? Colors.white).withOpacity(opacity),
            borderRadius: borderRadius,
            border: Border.all(color: Colors.white.withOpacity(0.4)),
          ),
          child: child,
        ),
      ),
    );
  }
}
