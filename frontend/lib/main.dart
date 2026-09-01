import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'theme.dart';
import 'data.dart';
import 'models/property.dart';
import 'screens/screens.dart'
    hide LandlordVerificationEntry, VerificationCenter;
import 'services/google_auth_service.dart';
import 'screens/dashboard/landlord_property_management_page.dart';
import 'package:property_app/services/analytics/analytics_service.dart';
import 'screens/dashboard/landlord_tenants_page.dart';
import 'screens/landlord/verification_flow.dart' show VerificationCenter;
import 'app_theme.dart';
import 'session/app_session.dart';
import 'session/onboarding_prefs.dart';
import 'screens/dashboard/landlord_bookings_page.dart';
import 'screens/privacy_policy.dart';
import 'screens/auth/tenant_survey.dart';
import 'repository/remote_database_repository.dart';
import 'screens/notification_settings_view.dart';

import 'services/property_service.dart';
import 'services/socket_service.dart';
import 'services/fcm_service.dart';
import 'services/auth_service.dart'; // Import AuthService
import 'screens/landlord/landlord_dashboard_view.dart';
import 'screens/super_admin/super_admin_shell.dart';
import 'screens/super_admin/super_admin_login.dart';
import 'package:property_app/firebase_options.dart';
import 'utils/responsive_layout.dart';

void _initializeFirebaseAsync() async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } else {
      Firebase.app();
    }
    await AnalyticsService.initialize();

    void logFcm(RemoteMessage m, {String source = 'unknown'}) {
      final data = m.data;
      final title = m.notification?.title;
      final body = m.notification?.body;
      final senderId = data['senderId']?.toString();
      final chatId = data['chatId']?.toString();
      final clickAction = data['click_action']?.toString();
      debugPrint(
        '[FCM][$source] title=${title ?? '-'} body=${body ?? '-'} senderId=${senderId ?? '-'} chatId=${chatId ?? '-'} click_action=${clickAction ?? '-'} data=${data.isEmpty ? '{}' : data} ',
      );
    }

    FCMService.instance.navigatorKey = navigatorKey;
    if (!kIsWeb) {
      await FCMService.instance.initialize();
      await FCMService.instance.subscribeToTopic('new_listings');
      FirebaseMessaging.onMessage.listen((m) => logFcm(m, source: 'onMessage'));
      FirebaseMessaging.onMessageOpenedApp
          .listen((m) => logFcm(m, source: 'onMessageOpenedApp'));
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) logFcm(initial, source: 'getInitialMessage');
    }
  } catch (err, stackTrace) {
    debugPrint('Firebase initialization failed; continuing without it: $err');
    debugPrintStack(stackTrace: stackTrace);
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await OnboardingPrefs.init();

  // GoogleFonts.config.allowRuntimeFetching = false;

  // Defer firebase init so it doesn't block startup
  _initializeFirebaseAsync();

  try {
    await dotenv.load(fileName: 'config.env');
  } on FileNotFoundError {
    debugPrint('No .env file found; using fallback API_BASE_URL values.');
  } catch (err) {
    debugPrint('dotenv load failed: $err');
  }

  await AppSession.restoreSession();

  if (AppSession.currentUserId != null) {
    AuthService.instance.syncFCMToken();
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

// Define the Global Navigator Key here
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

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

  Future<void> _enforceTenantPreferencesIfMissing(BuildContext context) async {
    if (AppSession.isLandlord) return;
    // If user is not verified, the app routes to OTP/verification first.
    if (!AppSession.currentUserVerified) return;

    final repo = RemoteDatabaseRepository();

    try {
      final tenantProfile = await repo.fetchTenantProfileMe();
      final hasPrefs = tenantProfile != null;

      if (!hasPrefs) {
        // Strict: un-dismissible bottom sheet
        await showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          isDismissible: false,
          enableDrag: false,
          useSafeArea: true,
          backgroundColor: Colors.transparent,
          builder: (sheetContext) {
            return WillPopScope(
              onWillPop: () async => false,
              child: const Material(
                color: Colors.transparent,
                child: TenantSurveyView(),
              ),
            );
          },
        );
      }
    } catch (_) {
      // Fail-safe: do nothing if preferences cannot be checked.
    }
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
      navigatorKey: navigatorKey, // Assign the navigator key to MaterialApp
      navigatorObservers: [AnalyticsObserver()],
      debugShowCheckedModeBanner: false,
      theme: AppTheme.themeForRole(_role),
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashView(),
        '/login': (context) => LoginView(
              onLogin: () async {
                if (!AppSession.currentUserVerified) {
                  Navigator.pushReplacementNamed(context, '/otp');
                  return;
                }

                if (AppSession.currentRole.toLowerCase() == 'admin') {
                  Navigator.pushReplacementNamed(context, '/super_admin');
                  return;
                }

                // Landlords must complete KYC before the portal becomes available.
                if (AppSession.isLandlord) {
                  Navigator.pushReplacementNamed(
                      context, '/verification_center');
                  return;
                }

                // Tenants: enforce preferences via strict, un-dismissible modal
                await _enforceTenantPreferencesIfMissing(context);

                // Once modal is shown (or preferences already exist), go home.
                Navigator.pushReplacementNamed(context, '/home');
                AuthService.instance.syncFCMToken(); // Sync FCM token
              },
              onRegister: () => Navigator.pushNamed(context, '/register'),
              onGoogleSignIn: () async {
                final success =
                    await GoogleAuthService.instance.signInWithGoogle();
                if (!success) throw Exception("Sign in failed");
                if (success) {
                  if (!AppSession.currentUserVerified) {
                    Navigator.pushReplacementNamed(context, '/otp');
                    return;
                  }

                  if (AppSession.currentRole.toLowerCase() == 'admin') {
                    Navigator.pushReplacementNamed(context, '/super_admin');
                    return;
                  }
                  if (AppSession.isLandlord) {
                    Navigator.pushReplacementNamed(
                        context, '/verification_center');
                    return;
                  }
                  await _enforceTenantPreferencesIfMissing(context);
                  Navigator.pushReplacementNamed(context, '/home');
                  AuthService.instance.syncFCMToken();
                }
              },
            ),

        '/register': (context) => RoleSelectionView(
            onBack: () => Navigator.pop(context),
            onSelect: (r) {
              AppSession.setRole(r);
              Navigator.pushReplacementNamed(context, '/register_form');
            }),
        '/register_form': (context) => RegisterView(
              onGoogleSignIn: () async {
                final success =
                    await GoogleAuthService.instance.signInWithGoogle();
                if (!success) throw Exception("Sign in failed");
                if (success) {
                  if (!AppSession.currentUserVerified) {
                    Navigator.pushReplacementNamed(context, '/otp');
                    return;
                  }

                  if (AppSession.currentRole.toLowerCase() == 'admin') {
                    Navigator.pushReplacementNamed(context, '/super_admin');
                    return;
                  }
                  if (AppSession.isLandlord) {
                    Navigator.pushReplacementNamed(
                        context, '/verification_center');
                    return;
                  }
                  await _enforceTenantPreferencesIfMissing(context);
                  Navigator.pushReplacementNamed(context, '/home');
                  AuthService.instance.syncFCMToken();
                }
              },
            ),
        '/survey': (context) => const TenantSurveyView(),
        '/privacy': (context) => const PrivacyPolicyView(),
        '/otp': (context) => const OtpView(),
        '/home': (context) => const AppShell(),
        '/landlord_dashboard': (context) => LandlordDashboardView(
              onLogout: () async {
                await AppSession.reset();
                if (context.mounted) {
                  Navigator.pushReplacementNamed(context, '/');
                }
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
                  case 'Notification Settings': // New setting
                    Navigator.pushNamed(context, '/notification_settings');
                    break;
                  default:
                    break;
                }
              },
              onLogout: () async {
                await AppSession.reset();
                if (context.mounted) {
                  Navigator.pushReplacementNamed(context, '/');
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
            }),
        '/portal': (context) => LandlordPortalView(
              onAddProperty: () =>
                  Navigator.pushNamed(context, '/list_property'),
            ),
        '/search': (context) => SearchView(
              onSelectProperty: (id) {}, // Placeholder
              onToggleMap: (visible) {}, // Placeholder
              onOpenFilters: () {}, // Placeholder
              activeFilters: const {}, // Placeholder
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
        // Redirect legacy route to the primary portal page
        '/landlord_bookings': (context) => const LandlordBookingsPage(),
        '/help_support': (context) =>
            HelpSupportView(onBack: () => Navigator.pop(context)),
        '/settings': (context) => SettingView(
              onBack: () => Navigator.pop(context),
              onLogout: () async {
                await AppSession.reset();
                // Consider clearing FCM token from backend on logout
                if (context.mounted) {
                  Navigator.pushReplacementNamed(context, '/');
                }
              },
              onItemTap: (title) {
                if (title == 'Help & Support') {
                  Navigator.pushNamed(context, '/help_support');
                } else if (title == 'Notification Settings') {
                  Navigator.pushNamed(
                    context,
                    '/notification_settings',
                    arguments: {
                      'title': title,
                      'subtitle': title,
                    },
                  );
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
        '/list_property': (context) => AddListingFlow(
              property: ModalRoute.of(context)?.settings.arguments
                  as Map<String, dynamic>?,
            ),
        '/verification_center': (context) => const VerificationCenter(),
        '/super_admin': (context) => const SuperAdminShell(),
        '/super_admin/login': (context) => const SuperAdminLoginView(),
        '/referral': (context) => const ReferralView(),
        '/reviews': (context) {
          final args = ModalRoute.of(context)!.settings.arguments
              as Map<String, dynamic>?;
          return ReviewsView(
            propertyId: args?['propertyId'] ?? '',
            propertyName: args?['propertyName'] ?? '',
            bookingId: args?['bookingId'],
            averageRating: (args?['averageRating'] as num?)?.toDouble() ?? 0.0,
            reviewCount: args?['reviewCount'] ?? 0,
            canReview: args?['canReview'] ?? false,
            hasReviewed: args?['hasReviewed'] ?? false,
          );
        },
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
        '/landlord_info': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          return LandlordInfoView(
            onClose: () => Navigator.pop(context),
            property: args is Property ? args : null,
          );
        },
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
        '/notification_settings': (context) => const NotificationSettingsView(),
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
  final int _savedTab = 0;

  @override
  void initState() {
    super.initState();
    try {
      SocketService.instance
          .connect(url: AppSession.apiBaseUrl, token: AppSession.apiToken);
      SocketService.instance.messages.listen((msg) {
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
  String? _selectedChatAvatar; // nullable — API avatars may be absent
  bool _showPhotoGallery = false;
  bool _showAmenities = false;
  bool _showLocation = false;
  bool _showLandlordInfo = false;
  bool _isMessageSelectionMode = false;
  Map<String, dynamic> _activeFilters = {};

  void _goTo(_AppScreen s) {
    if (s == _AppScreen.search || s == _AppScreen.home) {
      // Removed resetSessionImpressions
    }
    setState(() => _screen = s);
  }

  void _openFilter() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FilterView(
        onClose: () => Navigator.of(context).pop(),
        onApplyFilters: (filters) {
          // Removed resetSessionImpressions
          setState(() => _activeFilters = filters);
        },
      ),
    );
  }

  void _openPhotoGallery() => setState(() => _showPhotoGallery = true);
  void _closePhotoGallery() => setState(() => _showPhotoGallery = false);

  void _openAmenities() => setState(() => _showAmenities = true);
  void _closeAmenities() => setState(() => _showAmenities = false);

  void _openLocation() => setState(() => _showLocation = true);
  void _closeLocation() => setState(() => _showLocation = false);

  void _openLandlordInfo() => setState(() => _showLandlordInfo = true);
  void _closeLandlordInfo() => setState(() => _showLandlordInfo = false);

  Future<void> _openProperty(Property initialProperty) async {
    setState(() {
      _selectedPropertyId = initialProperty.id;
      _selectedProperty = initialProperty;
      _loadingPropertyDetails = false; // No spinner
    });

    AnalyticsService.logListingInteraction(AnalyticsEvents.listingClick,
        listingId: initialProperty.id);
    AnalyticsService.logListingInteraction(AnalyticsEvents.listingView,
        listingId: initialProperty.id);
    AnalyticsService.logListingInteraction(AnalyticsEvents.listingView,
        listingId: initialProperty.id);

    try {
      final property =
          await _propertyService.fetchPropertyById(initialProperty.id);
      if (!mounted) return;

      if (property != null) {
        setState(() {
          _selectedProperty = property;
        });
      }
    } catch (e) {
      // Ignore fetch errors to keep displaying the initial property
    }
  }

  void _closeProperty() {
    setState(() {
      _selectedPropertyId = null;
      _selectedProperty = null;
      _loadingPropertyDetails = false;
    });
  }

  // FIX: avatar is now String? to match MessagesViewScreen.onSelectChat
  void _openChat(String userId, String name, String? avatar) {
    if (_selectedPropertyId != null) {
      AnalyticsService.logListingInteraction(AnalyticsEvents.landlordContacted,
          listingId: _selectedPropertyId!);
    }
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
      _selectedPropertyId != null ||
      _selectedChatName != null ||
      _showPhotoGallery ||
      _showAmenities ||
      _showLocation ||
      _showLandlordInfo;

  @override
  Widget build(BuildContext context) {
    final baseScreen = AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: _buildScreen(),
    );

    final bool hideBottomNav = _isOverlayOpen || _isMessageSelectionMode;
    final isCompactScreen = ResponsiveLayout.isCompact(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Row(
            children: [
              if (!isCompactScreen)
                NavigationRail(
                  selectedIndex: _screen.index,
                  onDestinationSelected: (index) =>
                      _goTo(_AppScreen.values[index]),
                  labelType: NavigationRailLabelType.selected,
                  backgroundColor: AppColors.white,
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.home_outlined),
                      selectedIcon: Icon(Icons.home_rounded),
                      label: Text('Home'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.search_outlined),
                      selectedIcon: Icon(Icons.search_rounded),
                      label: Text('Search'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.bookmark_border),
                      selectedIcon: Icon(Icons.bookmark),
                      label: Text('Saved'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.chat_bubble_outline_rounded),
                      selectedIcon: Icon(Icons.chat_bubble_rounded),
                      label: Text('Messages'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.person_outline),
                      selectedIcon: Icon(Icons.person),
                      label: Text('Profile'),
                    ),
                  ],
                ),
              Expanded(child: baseScreen),
            ],
          ),
          if (_selectedPropertyId != null) _buildPropertyDetailsOverlay(),
          if (_showPhotoGallery) _buildPhotoGalleryOverlay(),
          if (_showAmenities) _buildAmenitiesOverlay(),
          if (_showLocation) _buildLocationOverlay(),
          if (_showLandlordInfo) _buildLandlordInfoOverlay(),
          if (_selectedChatName != null) _buildChatOverlay(),
          if (isCompactScreen)
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 16,
              left: 0,
              right: 0,
              child: AnimatedSlide(
                offset: hideBottomNav ? const Offset(0, 1.5) : Offset.zero,
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutQuad,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: hideBottomNav ? 0.0 : 1.0,
                  child:
                      Center(child: _BottomNav(current: _screen, onTap: _goTo)),
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
          onSeeCategory: (cat) {
            if (cat.isNotEmpty) {
              setState(() => _activeFilters = {'propertyType': cat});
            } else {
              setState(() => _activeFilters = {});
            }
            _goTo(_AppScreen.search);
          },
          onNotifications: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const NotificationsView()),
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
          onFiltersChanged: (f) => setState(() => _activeFilters = f),
        );
      case _AppScreen.saved:
        return SavedView(
          key: const ValueKey('saved'),
          onSelectProperty: (property) => _openProperty(property),
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
          onLogout: () async {
            await AppSession.reset();
            if (context.mounted) {
              Navigator.pushReplacementNamed(context, '/');
            }
          },
          onListProperty: () => Navigator.pushNamed(context, '/list_property'),
          onVerificationCenter: () =>
              Navigator.pushNamed(context, '/verification_center'),
        );
    }
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
      ),
    );
  }

  Property? get _activeProperty {
    if (_selectedProperty != null) return _selectedProperty;
    if (_selectedPropertyId == null) return null;
    try {
      return properties.firstWhere((p) => p.id == _selectedPropertyId);
    } catch (_) {
      return null;
    }
  }

  Widget _buildPhotoGalleryOverlay() {
    final property = _activeProperty;
    final photos = property?.images.isNotEmpty == true
        ? property!.images
        : (property != null && property.image.isNotEmpty
            ? [property.image]
            : null);

    return Material(
      color: Colors.transparent,
      child: PhotoGalleryView(
        onClose: _closePhotoGallery,
        photos: photos,
      ),
    );
  }

  Widget _buildAmenitiesOverlay() {
    final property = _activeProperty;
    return Material(
      color: Colors.transparent,
      child: AmenitiesView(
        onClose: _closeAmenities,
        amenities: property?.amenities ?? const [],
      ),
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
    final property = _activeProperty;
    return Material(
      color: Colors.transparent,
      child: LandlordInfoView(
        onClose: _closeLandlordInfo,
        property: property,
      ),
    );
  }

  Widget _buildChatOverlay() {
    // FIX: use ?? '' fallback since _selectedChatAvatar is now String?
    return Material(
      color: Colors.transparent,
      child: ChatView(
        onBack: _closeChat,
        userId: _selectedChatId!,
        name: _selectedChatName!,
        avatar: _selectedChatAvatar ?? '',
        onCall: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CallingView(
                userId: _selectedChatId!,
                name: _selectedChatName!,
                avatar: _selectedChatAvatar ?? '',
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _NavItem(
            icon: Icons.home_outlined,
            activeIcon: Icons.home_rounded,
            label: 'Home',
            active: current == _AppScreen.home,
            onTap: () => onTap(_AppScreen.home),
          ),
          const SizedBox(width: 4),
          _NavItem(
            icon: Icons.search_outlined,
            activeIcon: Icons.search_rounded,
            label: 'Search',
            active: current == _AppScreen.search,
            onTap: () => onTap(_AppScreen.search),
          ),
          const SizedBox(width: 4),
          _NavItem(
            icon: Icons.bookmark_border,
            activeIcon: Icons.bookmark,
            label: 'Saved',
            active: current == _AppScreen.saved,
            onTap: () => onTap(_AppScreen.saved),
          ),
          const SizedBox(width: 4),
          _NavItem(
            icon: Icons.chat_bubble_outline_rounded,
            activeIcon: Icons.chat_bubble_rounded,
            label: 'Messages',
            active: current == _AppScreen.messages,
            onTap: () => onTap(_AppScreen.messages),
          ),
          const SizedBox(width: 4),
          _NavItem(
            icon: Icons.person_outline,
            activeIcon: Icons.person,
            label: 'Profile',
            active: current == _AppScreen.profile,
            onTap: () => onTap(_AppScreen.profile),
            isProfile: true,
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
  final bool isProfile;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.active,
    required this.onTap,
    this.isProfile = false,
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
              if (widget.isProfile)
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: widget.active
                          ? AppColors.primary
                          : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: AppSession.buildAvatar(AppSession.currentUserAvatar),
                )
              else
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
