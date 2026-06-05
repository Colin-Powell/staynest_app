import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:latlong2/latlong.dart';
import 'theme.dart';
import 'data.dart';
import 'models/property.dart';
import 'screens/screens.dart'
    hide LandlordVerificationEntry, VerificationCenter;
import 'screens/dashboard/landlord_property_management_page.dart';
import 'screens/dashboard/landlord_tenants_page.dart';
import 'screens/landlord/verification_flow.dart' show VerificationCenter;
import 'app_theme.dart';
import 'session/app_session.dart';
import 'screens/privacy_policy.dart';
import 'screens/auth/tenant_survey.dart';
import 'services/property_service.dart';
import 'services/socket_service.dart';
import 'screens/landlord/landlord_dashboard_view.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: '.env');
  } on FileNotFoundError {
    debugPrint('No .env file found; using fallback API_BASE_URL values.');
  } catch (err) {
    debugPrint('dotenv load failed: $err');
  }

  if (kDebugMode) {
    debugPrint('Effective API_BASE_URL = ${AppSession.apiBaseUrl}');
  }

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
  ));
  runApp(const PropertyApp());
}

class PropertyApp extends StatefulWidget {
  const PropertyApp({super.key});

  @override
  State<PropertyApp> createState() => _PropertyAppState();
}

class _PropertyAppState extends State<PropertyApp> {
  late String _role;

  @override
  void initState() {
    super.initState();
    _role = AppSession.currentRole;
    AppSession.currentRoleNotifier.addListener(_handleRoleChange);
  }

  @override
  void dispose() {
    AppSession.currentRoleNotifier.removeListener(_handleRoleChange);
    super.dispose();
  }

  void _handleRoleChange() {
    if (mounted) {
      setState(() {
        _role = AppSession.currentRole;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Property App',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.themeForRole(_role),
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashView(),
        '/login': (context) => LoginView(
              onLogin: () {
                // If user is not verified, send them to OTP verification first
                if (!AppSession.currentUserVerified) {
                  Navigator.pushReplacementNamed(context, '/otp');
                } else if (AppSession.isLandlord) {
                  Navigator.pushReplacementNamed(context, '/portal');
                } else {
                  Navigator.pushReplacementNamed(context, '/home');
                }
              },
              onRegister: () => Navigator.pushNamed(context, '/register'),
            ),
        '/register': (context) => RoleSelectionView(
            onBack: () => Navigator.pop(context),
            onSelect: (r) {
              AppSession.setRole(r);
              // Route to registration with selected role
              Navigator.pushReplacementNamed(context, '/register_form');
            }),
        '/register_form': (context) => const RegisterView(),
        '/survey': (context) => const TenantSurveyView(),
        '/privacy': (context) => const PrivacyPolicyView(),
        '/otp': (context) => const OtpView(),
        '/home': (context) => const AppShell(),
        '/landlord_dashboard': (context) => LandlordDashboardView(
              onLogout: () {
                AppSession.reset();
                Navigator.pushReplacementNamed(context, '/');
              },
              onAddProperty: () =>
                  Navigator.pushNamed(context, '/list_property'),
              onViewVerification: () =>
                  Navigator.pushNamed(context, '/verification_center'),
            ),
        '/profile': (context) => ProfileView(
              onBack: () => Navigator.pop(context),
              onViewBookings: () {
                if (AppSession.isLandlord) {
                  Navigator.pushNamed(context, '/landlord_bookings');
                } else {
                  Navigator.pushNamed(context, '/tenant_bookings');
                }
              },
              onViewSaved: () => Navigator.pushNamed(context, '/saved'),
              onEditProfile: () =>
                  Navigator.pushNamed(context, '/edit_profile'),
              onRefer: () => Navigator.pushNamed(context, '/referral'),
              onSetting: (setting) {
                switch (setting) {
                  case 'Personal Information':
                    Navigator.pushNamed(context, '/edit_profile');
                    break;
                  case 'Payment Methods':
                    Navigator.pushNamed(context, '/payment_methods');
                    break;
                  case 'Reviews':
                    Navigator.pushNamed(context, '/reviews');
                    break;
                  case 'Settings':
                    Navigator.pushNamed(context, '/settings');
                    break;
                  case 'Help & Support':
                    Navigator.pushNamed(context, '/help_support');
                    break;
                  default:
                    break;
                }
              },
            ),
        '/onboarding': (context) => OnboardingView(
            onFinish: () =>
                Navigator.pushReplacementNamed(context, '/register')),
        '/role': (context) => RoleSelectionView(
            onBack: () => Navigator.pushReplacementNamed(context, '/'),
            onSelect: (r) {
              AppSession.setRole(r);
              // After selecting role, this path should not be used anymore
              // Navigation now happens through /register flow above
            }),
        '/portal': (context) => LandlordPortalView(
              onAddProperty: () =>
                  Navigator.pushNamed(context, '/list_property'),
            ),
        '/landlord_properties': (context) => LandlordPropertiesView(
              onAddProperty: () =>
                  Navigator.pushNamed(context, '/list_property'),
            ),
        '/landlord_property_management': (context) {
          final args = ModalRoute.of(context)!.settings.arguments
              as Map<String, dynamic>?;
          return LandlordPropertyManagementPage(
            property: args ?? <String, dynamic>{},
          );
        },
        '/landlord_tenants': (context) => const LandlordTenantsPage(),
        '/nearby': (context) => NearbyServicesView(
              onClose: () => Navigator.pop(context),
              onViewMap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MapViewScreen(
                      onBack: () => Navigator.pop(context),
                      onFilter: () {},
                    ),
                  ),
                );
              },
            ),
        '/payment_methods': (context) =>
            PaymentMethodsViewScreen(onBack: () => Navigator.pop(context)),
        '/photo_gallery': (context) =>
            PhotoGalleryView(onClose: () => Navigator.pop(context)),
        '/saved': (context) => SavedView(
              onSelectProperty: (id) => Navigator.pop(context),
            ),
        '/my_bookings': (context) =>
            MyBookingsViewScreen(onBack: () => Navigator.pop(context)),
        '/tenant_bookings': (context) => TenantBookingsView(
              onBack: () => Navigator.pop(context),
            ),
        '/landlord_bookings': (context) => LandlordBookingsView(
              onBack: () => Navigator.pop(context),
            ),
        '/help_support': (context) =>
            HelpSupportView(onBack: () => Navigator.pop(context)),
        '/settings': (context) => SettingView(
              onBack: () => Navigator.pop(context),
              onLogout: () {
                AppSession.reset();
                Navigator.pushReplacementNamed(context, '/');
              },
              onItemTap: (title) {
                if (title == 'Help & Support') {
                  Navigator.pushNamed(context, '/help_support');
                } else {
                  Navigator.pushNamed(context, '/how_it_works', arguments: {
                    'title': title,
                    'subtitle': title,
                  });
                }
              },
            ),
        '/how_it_works': (context) => HowItWorksView.fromArguments(
              ModalRoute.of(context)!.settings.arguments,
            ),
        '/edit_profile': (context) => EditProfileView(
              onBack: () => Navigator.pop(context),
              onSave: () => Navigator.pop(context),
            ),
        '/list_property': (context) => const AddListingFlow(),
        '/verification_center': (context) => const VerificationCenter(),
        '/referral': (context) => const ReferralView(),
        '/reviews': (context) => const ReviewsView(),
        '/amenities': (context) =>
            AmenitiesView(onClose: () => Navigator.pop(context)),
        '/location': (context) => LocationView(
            onClose: () => Navigator.pop(context),
            onNearbyPlaces: () {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                Navigator.pushNamed(context, '/nearby');
              });
            },
            onGetDirections: () {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                Navigator.pushNamed(context, '/commute');
              });
            }),
        '/landlord_info': (context) => LandlordInfoView(
              onClose: () => Navigator.pop(context),
            ),
        '/commute': (context) => CommuteMethodsView(
              onClose: () => Navigator.pop(context),
              onStartNavigation: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MapViewScreen(
                      onBack: () => Navigator.pop(context),
                      onFilter: () {},
                      isNavigation: true,
                      navOrigin: const LatLng(-1.2921, 36.8219),
                      navDestination: const LatLng(-1.2800, 36.8150),
                    ),
                  ),
                );
              },
            ),
        '/chat': (context) {
          final args = ModalRoute.of(context)!.settings.arguments
              as Map<String, String>?;
          return ChatView(
              onBack: () => Navigator.pop(context),
              userId: args?['userId'] ?? '',
              name: args?['name'] ?? 'Agent',
              avatar: args?['avatar'] ?? 'https://i.pravatar.cc/150?img=11');
        },
        '/booking': (context) {
          final args = ModalRoute.of(context)!.settings.arguments
              as Map<String, String>?;
          return BookingView(
              propertyId: args?['propertyId'] ?? '',
              onBack: () => Navigator.pop(context),
              onComplete: () {
                Navigator.pop(context);
              });
        },
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// App Shell
// ─────────────────────────────────────────────────────────────────────────────

enum _AppScreen { home, search, saved, messages, profile }

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  _AppScreen _screen = _AppScreen.home;

  @override
  void initState() {
    super.initState();
    // Connect websocket service so messaging & call signaling works app-wide
    try {
      SocketService.instance
          .connect(url: AppSession.apiBaseUrl, token: AppSession.apiToken);
      SocketService.instance.messages.listen((msg) {
        // Optionally show a brief notification for incoming messages
        // For now, just print to debug console
        // You can hook this into state to update message lists in real-time
        // ignore: avoid_print
        print('Incoming socket message from ${msg.from}: ${msg.text}');
      });
    } catch (err) {
      // ignore
    }
  }

  final PropertyService _propertyService = PropertyService.instance;
  String? _selectedPropertyId;
  Property? _selectedProperty;
  bool _loadingPropertyDetails = false;
  String? _selectedChatId;
  String? _selectedChatName;
  String? _selectedChatAvatar;
  bool _showPhotoGallery = false;
  bool _showAmenities = false;
  bool _showLocation = false;
  bool _showLandlordInfo = false;
  bool _showBooking = false;
  bool _showFilter = false;
  bool _isMessageSelectionMode = false;
  Map<String, dynamic> _activeFilters = {};

  void _goTo(_AppScreen s) => setState(() => _screen = s);

  void _openFilter() => setState(() => _showFilter = true);
  void _closeFilter() => setState(() => _showFilter = false);

  void _openPhotoGallery() => setState(() => _showPhotoGallery = true);
  void _closePhotoGallery() => setState(() => _showPhotoGallery = false);

  void _openAmenities() => setState(() => _showAmenities = true);
  void _closeAmenities() => setState(() => _showAmenities = false);

  void _openLocation() => setState(() => _showLocation = true);
  void _closeLocation() => setState(() => _showLocation = false);

  void _openLandlordInfo() => setState(() => _showLandlordInfo = true);
  void _closeLandlordInfo() => setState(() => _showLandlordInfo = false);

  void _openBooking() => setState(() => _showBooking = true);
  void _closeBooking() => setState(() => _showBooking = false);

  Future<void> _openProperty(String id) async {
    setState(() {
      _selectedPropertyId = id;
      _selectedProperty = null;
      _loadingPropertyDetails = true;
    });

    final property = await _propertyService.fetchPropertyById(id);
    if (!mounted) return;

    setState(() {
      _selectedProperty = property;
      _loadingPropertyDetails = false;
    });
  }

  void _closeProperty() {
    setState(() {
      _selectedPropertyId = null;
      _selectedProperty = null;
      _loadingPropertyDetails = false;
    });
  }

  void _openChat(String userId, String name, String avatar) {
    setState(() {
      _selectedChatId = userId;
      _selectedChatName = name;
      _selectedChatAvatar = avatar;
    });
  }

  void _closeChat() {
    setState(() {
      _selectedChatId = null;
      _selectedChatName = null;
      _selectedChatAvatar = null;
    });
  }

  bool get _isOverlayOpen =>
      _showFilter ||
      _selectedPropertyId != null ||
      _selectedChatName != null ||
      _showPhotoGallery ||
      _showAmenities ||
      _showLocation ||
      _showLandlordInfo ||
      _showBooking;

  @override
  Widget build(BuildContext context) {
    final baseScreen = AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: _buildScreen(),
    );

    final bool hideBottomNav = _isOverlayOpen || _isMessageSelectionMode;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          baseScreen,
          if (_showFilter) _buildFilterOverlay(),
          if (_selectedPropertyId != null) _buildPropertyDetailsOverlay(),
          if (_showPhotoGallery) _buildPhotoGalleryOverlay(),
          if (_showAmenities) _buildAmenitiesOverlay(),
          if (_showLocation) _buildLocationOverlay(),
          if (_showLandlordInfo) _buildLandlordInfoOverlay(),
          if (_showBooking) _buildBookingOverlay(),
          if (_selectedChatName != null && _selectedChatAvatar != null)
            _buildChatOverlay(),
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 16,
            left: 24,
            right: 24,
            child: AnimatedSlide(
              offset: hideBottomNav ? const Offset(0, 1.5) : Offset.zero,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutQuad,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: hideBottomNav ? 0.0 : 1.0,
                child: _BottomNav(current: _screen, onTap: _goTo),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScreen() {
    switch (_screen) {
      case _AppScreen.home:
        return HomeView(
          key: const ValueKey('home'),
          onSelectProperty: _openProperty,
          onNotifications: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Notifications tapped')),
            );
          },
        );
      case _AppScreen.search:
        return SearchView(
          key: const ValueKey('search'),
          onSelectProperty: _openProperty,
          onToggleMap: (visible) {},
          onOpenFilters: _openFilter,
          activeFilters: _activeFilters,
        );
      case _AppScreen.saved:
        return SavedView(
          key: const ValueKey('saved'),
          onSelectProperty: (id) => _openProperty(id),
        );
      case _AppScreen.messages:
        return MessagesViewScreen(
          key: const ValueKey('messages'),
          onSelectChat: _openChat,
          onSelectionModeChanged: (isSelecting) {
            setState(() {
              _isMessageSelectionMode = isSelecting;
            });
          },
        );
      case _AppScreen.profile:
        return ProfileView(
          key: const ValueKey('profile'),
          onBack: () => _goTo(_AppScreen.home),
          onViewBookings: () => Navigator.pushNamed(context, '/my_bookings'),
          onViewSaved: () => Navigator.pushNamed(context, '/saved'),
          onEditProfile: () => Navigator.pushNamed(context, '/edit_profile'),
          onRefer: () => Navigator.pushNamed(context, '/referral'),
          onSetting: (setting) {
            switch (setting) {
              case 'Personal Information':
                Navigator.pushNamed(context, '/edit_profile');
                break;
              case 'Payment Methods':
                Navigator.pushNamed(context, '/payment_methods');
                break;
              case 'Reviews':
                Navigator.pushNamed(context, '/reviews');
                break;
              case 'Settings':
                Navigator.pushNamed(context, '/settings');
                break;
              case 'Help & Support':
                Navigator.pushNamed(context, '/help_support');
                break;
              default:
                break;
            }
          },
          onLogout: () => Navigator.pushReplacementNamed(context, '/'),
          onListProperty: () => Navigator.pushNamed(context, '/list_property'),
          onVerificationCenter: () =>
              Navigator.pushNamed(context, '/verification_center'),
        );
    }
  }

  Widget _buildFilterOverlay() {
    return Material(
      color: Colors.black38,
      child: FilterView(
        onClose: _closeFilter,
        onApplyFilters: (filters) => setState(() => _activeFilters = filters),
      ),
    );
  }

  Widget _buildPropertyDetailsOverlay() {
    if (_loadingPropertyDetails) {
      return const Material(
        color: Colors.transparent,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final property = _selectedProperty ??
        properties.firstWhere(
          (p) => p.id == _selectedPropertyId,
          orElse: () => properties.first,
        );

    return Material(
      color: Colors.transparent,
      child: PropertyDetails(
        property: property,
        onBack: _closeProperty,
        onViewGallery: _openPhotoGallery,
        onViewAmenities: _openAmenities,
        onViewLocation: _openLocation,
        onViewLandlord: _openLandlordInfo,
        onMessage: (userId, name, avatar) => _openChat(userId, name, avatar),
        onBook: _openBooking,
      ),
    );
  }

  Widget _buildPhotoGalleryOverlay() {
    return Material(
      color: Colors.transparent,
      child: PhotoGalleryView(onClose: _closePhotoGallery),
    );
  }

  Widget _buildAmenitiesOverlay() {
    return Material(
      color: Colors.transparent,
      child: AmenitiesView(onClose: _closeAmenities),
    );
  }

  Widget _buildLocationOverlay() {
    if (_loadingPropertyDetails) {
      return const Material(
        color: Colors.transparent,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final property = _selectedProperty ??
        properties.firstWhere(
          (p) => p.id == _selectedPropertyId,
          orElse: () => properties.first,
        );

    return Material(
      color: Colors.transparent,
      child: LocationView(
        property: property,
        onClose: _closeLocation,
        onNearbyPlaces: () {
          _closeLocation();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.pushNamed(context, '/nearby');
          });
        },
        onGetDirections: () {
          _closeLocation();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.pushNamed(context, '/commute');
          });
        },
      ),
    );
  }

  Widget _buildLandlordInfoOverlay() {
    return Material(
      color: Colors.transparent,
      child: LandlordInfoView(onClose: _closeLandlordInfo),
    );
  }

  Widget _buildBookingOverlay() {
    if (_loadingPropertyDetails) {
      return const Material(
        color: Colors.transparent,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final id =
        _selectedProperty?.id ?? _selectedPropertyId ?? properties.first.id;
    return Material(
      color: Colors.transparent,
      child: BookingView(
        propertyId: id,
        onBack: _closeBooking,
        onComplete: () {
          _closeBooking();
        },
      ),
    );
  }

  Widget _buildChatOverlay() {
    return Material(
      color: Colors.transparent,
      child: ChatView(
        onBack: _closeChat,
        userId: _selectedChatId!,
        name: _selectedChatName!,
        avatar: _selectedChatAvatar!,
        onCall: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CallingView(
                userId: _selectedChatId!,
                name: _selectedChatName!,
                avatar: _selectedChatAvatar!,
                onEndCall: () => Navigator.pop(context),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pill Shaped Bottom Navigation Bar
// ─────────────────────────────────────────────────────────────────────────────

class _BottomNav extends StatelessWidget {
  final _AppScreen current;
  final void Function(_AppScreen) onTap;

  const _BottomNav({required this.current, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(40),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 20),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _NavItem(
            icon: Icons.home_outlined,
            activeIcon: Icons.home_rounded,
            label: 'Home',
            active: current == _AppScreen.home,
            onTap: () => onTap(_AppScreen.home),
          ),
          _NavItem(
            icon: Icons.search_outlined,
            activeIcon: Icons.search_rounded,
            label: 'Search',
            active: current == _AppScreen.search,
            onTap: () => onTap(_AppScreen.search),
          ),
          _NavItem(
            icon: Icons.bookmark_border,
            activeIcon: Icons.bookmark,
            label: 'Saved',
            active: current == _AppScreen.saved,
            onTap: () => onTap(_AppScreen.saved),
          ),
          _NavItem(
            icon: Icons.chat_bubble_outline_rounded,
            activeIcon: Icons.chat_bubble_rounded,
            label: 'Messages',
            active: current == _AppScreen.messages,
            onTap: () => onTap(_AppScreen.messages),
          ),
          _NavItem(
            icon: Icons.person_outline,
            activeIcon: Icons.person,
            label: 'Profile',
            active: current == _AppScreen.profile,
            onTap: () => onTap(_AppScreen.profile),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 150),
  );
  late final Animation<double> _scale = Tween(begin: 1.0, end: 0.90).animate(
    CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
  );

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: widget.active ? AppColors.primaryLight : Colors.transparent,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.active ? widget.activeIcon : widget.icon,
                color: widget.active ? AppColors.primary : AppColors.gray400,
                size: 22,
              ),
              if (widget.active) ...[
                const SizedBox(height: 3),
                Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
