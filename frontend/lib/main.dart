import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:property_app/utils/responsive_modal_sheet.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:property_app/screens/dashboard/landlord_overview_page.dart';
import 'data.dart';
import 'models/property.dart';
import 'screens/screens.dart'
    hide LandlordVerificationEntry, VerificationCenter;
import 'services/google_auth_service.dart';
import 'screens/dashboard/landlord_property_management_page.dart';
import 'package:property_app/services/analytics/analytics_service.dart';
import 'screens/dashboard/landlord_tenants_page.dart';
import 'screens/dashboard/landlord_messages_page.dart';
import 'screens/landlord/verification_flow.dart' show VerificationCenter;
import 'app_theme.dart';
import 'session/app_session.dart';
import 'session/onboarding_prefs.dart';
import 'screens/dashboard/landlord_bookings_page.dart';
import 'screens/home/become_host_view.dart';
import 'screens/privacy_policy.dart';
import 'screens/auth/tenant_survey.dart';
import 'repository/remote_database_repository.dart';
import 'screens/notification_settings_view.dart';
import 'screens/property/write_review_view.dart';

import 'services/property_service.dart';
import 'services/device_location_service.dart';
import 'services/socket_service.dart';
import 'services/fcm_service.dart';
import 'services/message_service.dart';
import 'services/notification_api.dart';
import 'services/auth_service.dart';
import 'services/version_service.dart';
import 'screens/super_admin/super_admin_shell.dart';
import 'screens/super_admin/super_admin_login.dart';
import 'package:property_app/firebase_options.dart';

Future<void> _initializeFirebaseAsync() async {
  // ── Step 1: Core Firebase init ────────────────────────────────────────────
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      debugPrint('[Firebase] initialized');
    } else {
      Firebase.app();
      debugPrint('[Firebase] already initialized');
    }
  } catch (err, stackTrace) {
    debugPrint('[Firebase] initializeApp failed: $err');
    debugPrintStack(stackTrace: stackTrace);
    // Do NOT return — FCMService may still work via the native SDK.
  }

  // ── Step 2: Analytics (non-critical) ─────────────────────────────────────
  try {
    await AnalyticsService.initialize();
  } catch (err) {
    debugPrint('[Firebase] Analytics init failed: $err');
  }

  // ── Step 3: FCM service — completely isolated ─────────────────────────────
  // Must never be skipped by a failure in steps 1 or 2.
  try {
    FCMService.instance.navigatorKey = navigatorKey;
    if (!kIsWeb) {
      await FCMService.instance.initialize();
      await FCMService.instance.subscribeToTopic('new_listings');
    }
  } catch (err, stackTrace) {
    debugPrint('[FCM] service init failed: $err');
    debugPrintStack(stackTrace: stackTrace);
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await OnboardingPrefs.init();

  try {
    await dotenv.load(fileName: 'config.env');
  } on FileNotFoundError {
    debugPrint('No .env file found; using fallback API_BASE_URL values.');
  } catch (err) {
    debugPrint('dotenv load failed: $err');
  }

  await AppSession.restoreSession();
  await AppSession.initializeAppInfo();

  await _initializeFirebaseAsync();
  if (AppSession.currentUserId != null) {
    AuthService.instance.syncFCMToken();
  }

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
  ));
  runApp(const PropertyApp());
  unawaited(DeviceLocationService.instance.initialize());
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class PropertyApp extends StatefulWidget {
  const PropertyApp({super.key});

  @override
  State<PropertyApp> createState() => _PropertyAppState();
}

class _PropertyAppState extends State<PropertyApp> {
  late String _role;
  bool _isCompletingModalLogin = false;

  @override
  void initState() {
    super.initState();
    _role = AppSession.currentRole;
    AppSession.currentRoleNotifier.addListener(_handleRoleChange);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navigatorContext = navigatorKey.currentState?.overlay?.context;
      if (navigatorContext != null) {
        VersionService.checkVersion(navigatorContext);
      }
    });
  }

  @override
  void dispose() {
    AppSession.currentRoleNotifier.removeListener(_handleRoleChange);
    super.dispose();
  }

  Future<void> _enforceTenantPreferencesIfMissing(BuildContext context) async {
    if (AppSession.isLandlord) return;
    if (!AppSession.currentUserVerified) return;

    final repo = RemoteDatabaseRepository();

    try {
      final tenantProfile = await repo.fetchTenantProfileMe();
      final hasPrefs = tenantProfile != null;

      if (!hasPrefs) {
        await showResponsiveModalSheet<void>(
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
    } catch (_) {}
  }

  void _handleRoleChange() {
    if (mounted) {
      setState(() => _role = AppSession.currentRole);
    }
  }

  Future<String> _resolveLandlordRoute() async {
    try {
      final user = await RemoteDatabaseRepository().loadCurrentUser();
      AppSession.updateCurrentUser(user);
      await AppSession.persistSession();
    } catch (_) {
      // Persisted session roles remain the offline fallback; backend endpoints reauthorize.
    }
    return AppSession.hasLandlordAccess ? '/landlord' : '/home';
  }

  Future<void> _switchActivePortal(String portal) async {
    if (portal == 'landlord' && !AppSession.hasLandlordAccess) return;
    final target = portal == 'landlord' ? '/landlord' : '/home';
    AppSession.setRole(portal);
    await AppSession.persistSession();
    navigatorKey.currentState?.pushNamedAndRemoveUntil<void>(
      target,
      (route) => false,
    );
  }

  void _scheduleLandlordPortalActivation() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !AppSession.hasLandlordAccess || AppSession.isLandlord) {
        return;
      }
      AppSession.setRole('landlord');
      unawaited(AppSession.persistSession());
    });
  }

  Widget _landlordOnlyRoute(Widget Function() builder) {
    if (AppSession.hasLandlordAccess) {
      _scheduleLandlordPortalActivation();
      return builder();
    }
    return AppShell(onRequireLogin: _showLoginModal);
  }

  Widget _landlordPortalRoute() {
    if (!AppSession.hasLandlordAccess) {
      return AppShell(onRequireLogin: _showLoginModal);
    }
    _scheduleLandlordPortalActivation();
    return LandlordPortalView(
      onSwitchToTenantPortal: () => _switchActivePortal('tenant'),
    );
  }

  Future<void> _completeModalLogin(
    BuildContext dialogContext, {
    VoidCallback? onAuthenticated,
  }) async {
    if (_isCompletingModalLogin) return;
    _isCompletingModalLogin = true;

    try {
      if (!AppSession.isEmailVerified) {
        _closeLoginModal(dialogContext, routeName: '/otp');
        return;
      }

      await AuthService.instance.syncFCMToken();
      AppSession.isGuest = false;

      if (AppSession.isAdmin) {
        _closeLoginModal(dialogContext, routeName: '/super_admin');
        return;
      }

      if (AppSession.isLandlord) {
        final target = await _resolveLandlordRoute();
        if (!mounted || !dialogContext.mounted) return;
        _closeLoginModal(dialogContext, routeName: target);
        return;
      }

      await _enforceTenantPreferencesIfMissing(dialogContext);
      if (!mounted || !dialogContext.mounted) return;
      _closeLoginModal(dialogContext, onClosed: onAuthenticated);
    } finally {
      _isCompletingModalLogin = false;
    }
  }

  void _closeLoginModal(
    BuildContext dialogContext, {
    String? routeName,
    VoidCallback? onClosed,
  }) {
    Navigator.of(dialogContext).pop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (routeName != null) {
        navigatorKey.currentState?.pushNamedAndRemoveUntil<void>(
          routeName,
          (route) => false,
        );
      } else {
        onClosed?.call();
      }
    });
  }

  Future<void> _completePageLogin(
    BuildContext context, {
    VoidCallback? onAuthenticated,
  }) async {
    if (!AppSession.isEmailVerified) {
      Navigator.pushReplacementNamed(context, '/otp');
      return;
    }

    await AuthService.instance.syncFCMToken();
    if (AppSession.isAdmin) {
      Navigator.pushReplacementNamed(context, '/super_admin');
      return;
    }
    if (AppSession.isLandlord) {
      final target = await _resolveLandlordRoute();
      if (!context.mounted) return;
      Navigator.pushReplacementNamed(context, target);
      return;
    }

    await _enforceTenantPreferencesIfMissing(context);
    if (!context.mounted) return;
    Navigator.pushReplacementNamed(context, '/home');
    onAuthenticated?.call();
  }

  Future<void> _completeGoogleSignIn(
    BuildContext context, {
    required bool isDesktopModal,
    VoidCallback? onAuthenticated,
  }) async {
    final success = await GoogleAuthService.instance.signInWithGoogle();
    if (!success) throw Exception('Sign in failed');
    if (isDesktopModal) {
      await _completeModalLogin(context, onAuthenticated: onAuthenticated);
    } else {
      await _completePageLogin(context, onAuthenticated: onAuthenticated);
    }
  }

  Future<void> _showLoginModal(
    BuildContext context, {
    VoidCallback? onAuthenticated,
  }) async {
    if (MediaQuery.sizeOf(context).width < 768) {
      await Navigator.of(context, rootNavigator: true).pushNamed<void>(
        '/login',
        arguments: onAuthenticated,
      );
      return;
    }

    await showDialog<void>(
      context: context,
      useRootNavigator: true,
      builder: (dialogContext) {
        final size = MediaQuery.sizeOf(dialogContext);
        return Dialog(
          child: SizedBox(
            width: (size.width - 48).clamp(320.0, 560.0).toDouble(),
            height: (size.height - 48).clamp(420.0, 760.0).toDouble(),
            child: LoginView(
              onLogin: () => _completeModalLogin(
                dialogContext,
                onAuthenticated: onAuthenticated,
              ),
              onRegister: () {
                Navigator.of(dialogContext).pop();
                navigatorKey.currentState?.pushNamed('/register');
              },
              onGoogleSignIn: () async {
                final success =
                    await GoogleAuthService.instance.signInWithGoogle();
                if (!success) throw Exception('Sign in failed');
                await _completeModalLogin(
                  dialogContext,
                  onAuthenticated: onAuthenticated,
                );
              },
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = AppTheme.themeForRole(_role);

    return MaterialApp(
      title: 'Property App',
      navigatorKey: navigatorKey,
      navigatorObservers: [AnalyticsObserver()],
      debugShowCheckedModeBanner: false,
      theme: appTheme,
      builder: (context, child) {
        final isDesktop = MediaQuery.sizeOf(context).width >= 768;
        return Theme(
          data: appTheme.copyWith(
            snackBarTheme: appTheme.snackBarTheme.copyWith(
              behavior: isDesktop ? SnackBarBehavior.floating : null,
              width: isDesktop ? 440 : null,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      initialRoute: '/',
      routes: {
        '/': (context) {
          final isDesktop = MediaQuery.sizeOf(context).width >= 768;
          if (isDesktop) {
            AppSession.isGuest = true;
            return AppShell(onRequireLogin: _showLoginModal);
          }
          return const SplashView();
        },
        '/onboarding': (context) {
          final isDesktop = MediaQuery.sizeOf(context).width >= 768;
          if (isDesktop) {
            AppSession.isGuest = true;
            return AppShell(onRequireLogin: _showLoginModal);
          }
          return OnboardingView(
            onFinish: () =>
                Navigator.pushReplacementNamed(context, '/register'),
          );
        },
        '/privacy': (context) => const PrivacyPolicyView(),
        '/home': (context) => AppShell(onRequireLogin: _showLoginModal),
        '/explore': (context) => AppShell(onRequireLogin: _showLoginModal),
        '/landlord': (context) => _landlordPortalRoute(),
        '/dashboard': (context) => _landlordOnlyRoute(
              () => LandlordOverviewPage(
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
            ),
        '/profile': (context) => ProfileView(
              onBack: () => Navigator.pop(context),
              onBecomeHost: () => Navigator.pushNamed(context, '/become_host'),
              onSwitchRole: () => _switchActivePortal('landlord'),
              onViewBookings: () {
                if (AppSession.isLandlord) {
                  Navigator.pushNamed(context, '/landlord_bookings');
                } else {
                  Navigator.pushNamed(context, '/tenant_bookings');
                }
              },
              onEditProfile: () =>
                  Navigator.pushNamed(context, '/edit_profile'),
              onMyProfile: () =>
                  Navigator.pushNamed(context, '/tenant_profile'),
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
                  case 'Notification Settings':
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
              onListProperty: () =>
                  Navigator.pushNamed(context, '/list_property'),
              onVerificationCenter: () =>
                  Navigator.pushNamed(context, '/verification_center'),
            ),
        '/portal': (context) => _landlordPortalRoute(),
        '/become_host': (context) => AppSession.currentUserId == null
            ? AppShell(onRequireLogin: _showLoginModal)
            : BecomeHostView(
                onBack: () => Navigator.maybePop(context),
                onSubmitted: () {
                  AppSession.notifyHostApplicationChanged();
                  navigatorKey.currentState?.popUntil(
                    (route) => route.settings.name == '/home' || route.isFirst,
                  );
                },
                onSwitchToLandlord: () => _switchActivePortal('landlord'),
              ),
        '/search': (context) => SearchView(
              onSelectProperty: (id) {},
              onShowMap: (properties, query) {},
              onOpenFilters: () {},
              activeFilters: const {},
            ),
        '/landlord_properties': (context) => _landlordOnlyRoute(
              () => LandlordPropertiesView(
                  onAddProperty: () =>
                      Navigator.pushNamed(context, '/list_property')),
            ),
        '/landlord_property_management': (context) => _landlordOnlyRoute(() {
              final args = ModalRoute.of(context)!.settings.arguments
                  as Map<String, dynamic>?;
              return LandlordPropertyManagementPage(
                  property: args ?? <String, dynamic>{});
            }),
        '/landlord_tenants': (context) =>
            _landlordOnlyRoute(() => const LandlordTenantsPage()),
        '/nearby': (context) => NearbyServicesView(
              onClose: () => Navigator.pop(context),
              onViewMap: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => MapViewScreen(
                            onBack: () => Navigator.pop(context),
                            onFilter: () {})));
              },
            ),
        '/payment_methods': (context) =>
            PaymentMethodsViewScreen(onBack: () => Navigator.pop(context)),
        '/photo_gallery': (context) =>
            PhotoGalleryView(onClose: () => Navigator.pop(context)),
        '/saved': (context) =>
            SavedView(onSelectProperty: (id) => Navigator.pop(context)),
        '/my_bookings': (context) =>
            MyBookingsViewScreen(onBack: () => Navigator.pop(context)),
        '/tenant_bookings': (context) =>
            TenantBookingsView(onBack: () => Navigator.pop(context)),
        '/landlord_bookings': (context) =>
            _landlordOnlyRoute(() => const LandlordBookingsPage()),
        '/help_support': (context) =>
            HelpSupportView(onBack: () => Navigator.pop(context)),
        '/settings': (context) => SettingView(
              onBack: () => Navigator.pop(context),
              onLogout: () async {
                await AppSession.reset();
                if (context.mounted) {
                  Navigator.pushReplacementNamed(context, '/');
                }
              },
              onItemTap: (title) {
                switch (title) {
                  case 'Help & Support':
                    Navigator.pushNamed(context, '/help_support');
                    break;
                  case 'Notifications':
                  case 'Notification Settings':
                    Navigator.pushNamed(context, '/notification_settings');
                    break;
                  case 'Privacy & Security':
                    Navigator.pushNamed(context, '/privacy');
                    break;
                  case 'About StayNest':
                    Navigator.pushNamed(context, '/about');
                    break;
                }
              },
            ),
        '/about': (context) => const AboutView(),
        '/how_it_works': (context) => HowItWorksView.fromArguments(
            ModalRoute.of(context)!.settings.arguments),
        '/edit_profile': (context) => EditProfileView(
            onBack: () => Navigator.pop(context),
            onSave: () => Navigator.pop(context)),
        '/tenant_profile': (context) => TenantProfileView(
              onBack: () => Navigator.pop(context),
            ),
        '/list_property': (context) => _landlordOnlyRoute(
              () => AddListingFlow(
                  property: ModalRoute.of(context)?.settings.arguments
                      as Map<String, dynamic>?),
            ),
        '/verification_center': (context) => const VerificationCenter(),
        '/super_admin': (context) => const SuperAdminShell(),
        '/referral': (context) => const ReferralView(),
        '/wallet': (context) => const WalletView(),
        '/amenities': (context) =>
            AmenitiesView(onClose: () => Navigator.pop(context)),
        '/location': (context) {
          final property = ModalRoute.of(context)?.settings.arguments;
          return LocationView(
            property: property is Property ? property : null,
            onClose: () => Navigator.pop(context),
            onNearbyPlaces: () {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                Navigator.pushNamed(context, '/nearby');
              });
            },
            onGetDirections: () {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                Navigator.pushNamed(context, '/commute', arguments: {
                  if (property is Property) 'targetProperty': property,
                });
              });
            },
          );
        },
        '/landlord_info': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          return LandlordInfoView(
            onClose: () => Navigator.pop(context),
            property: args is Property ? args : null,
            onRequireAuthentication: ({onAuthenticated}) => _showLoginModal(
              context,
              onAuthenticated: onAuthenticated,
            ),
          );
        },
        '/commute': (context) => CommuteMethodsView(
              targetLocation: (ModalRoute.of(context)?.settings.arguments
                  as Map<String, dynamic>?)?['targetLocation'] as LatLng?,
              targetProperty: (ModalRoute.of(context)?.settings.arguments
                  as Map<String, dynamic>?)?['property'] as Property?,
              onClose: () => Navigator.pop(context),
              onStartNavigation: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => MapViewScreen(
                            onBack: () => Navigator.pop(context),
                            onFilter: () {},
                            isNavigation: true,
                            navOrigin: null,
                            navDestination: null)));
              },
            ),
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
      onGenerateRoute: (settings) =>
          _buildReviewRoute(settings) ??
          _buildMessageModalRoute(settings) ??
          _buildAuthRoute(settings),
    );
  }

  Route<bool?>? _buildReviewRoute(RouteSettings settings) {
    const reviewRoutes = {
      '/reviews',
      '/all_reviews',
      '/write_review',
      '/landlord_reviews',
    };
    if (!reviewRoutes.contains(settings.name)) return null;

    final rawArguments = settings.arguments;
    final arguments = rawArguments is Map ? rawArguments : const {};
    Widget buildScreen(BuildContext context) {
      switch (settings.name) {
        case '/reviews':
          return ReviewsView(
            propertyId: arguments['propertyId']?.toString() ?? '',
            propertyName: arguments['propertyName']?.toString() ?? '',
            bookingId: arguments['bookingId']?.toString(),
            averageRating:
                (arguments['averageRating'] as num?)?.toDouble() ?? 0.0,
            reviewCount: (arguments['reviewCount'] as num?)?.toInt() ?? 0,
            canReview: arguments['canReview'] == true,
            hasReviewed: arguments['hasReviewed'] == true,
          );
        case '/all_reviews':
          return AllReviewsView(
            propertyId: arguments['propertyId']?.toString() ?? '',
            propertyName: arguments['propertyName']?.toString() ?? '',
            bookingId: arguments['bookingId']?.toString(),
            hasReviewed: arguments['hasReviewed'] == true,
          );
        case '/write_review':
          return WriteReviewView(
            propertyId: arguments['propertyId']?.toString() ?? '',
            propertyName: arguments['propertyName']?.toString() ?? '',
            bookingId: arguments['bookingId']?.toString() ?? '',
          );
        case '/landlord_reviews':
          if (!AppSession.hasLandlordAccess) {
            return AppShell(onRequireLogin: _showLoginModal);
          }
          return LandlordReviewsView(
            onClose: () => Navigator.of(context).pop(),
          );
        default:
          return const SizedBox.shrink();
      }
    }

    final navigatorContext = navigatorKey.currentContext;
    final isDesktop = navigatorContext != null &&
        MediaQuery.sizeOf(navigatorContext).width >= 768;
    if (!isDesktop) {
      return MaterialPageRoute<bool?>(
        settings: settings,
        builder: buildScreen,
      );
    }

    return PageRouteBuilder<bool?>(
      settings: settings,
      opaque: false,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      pageBuilder: (context, animation, secondaryAnimation) {
        final size = MediaQuery.sizeOf(context);
        final width = (size.width - 64).clamp(480.0, 1040.0).toDouble();
        final height = (size.height - 64).clamp(420.0, 900.0).toDouble();
        return Center(
          child: Dialog(
            insetPadding: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: SizedBox(
              width: width,
              height: height,
              child: buildScreen(context),
            ),
          ),
        );
      },
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.97, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  Route<dynamic>? _buildAuthRoute(RouteSettings settings) {
    const authRoutes = {
      '/login',
      '/register',
      '/register_form',
      '/otp',
      '/survey',
      '/onboarding',
      '/role',
      '/super_admin/login',
    };
    if (!authRoutes.contains(settings.name)) return null;

    final navigatorContext = navigatorKey.currentContext;
    final isDesktop = navigatorContext != null &&
        MediaQuery.sizeOf(navigatorContext).width >= 768;
    if (!isDesktop) {
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (context) => _buildAuthScreen(
          settings.name!,
          context,
          false,
          onAuthenticated: settings.arguments is VoidCallback
              ? settings.arguments as VoidCallback
              : null,
        ),
      );
    }

    return PageRouteBuilder<void>(
      settings: settings,
      opaque: false,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      pageBuilder: (context, animation, secondaryAnimation) {
        final screen = _buildAuthScreen(
          settings.name!,
          context,
          true,
          onAuthenticated: settings.arguments is VoidCallback
              ? settings.arguments as VoidCallback
              : null,
        );

        final size = MediaQuery.sizeOf(context);
        final width = (size.width - 48).clamp(360.0, 600.0).toDouble();
        final height = (size.height - 48).clamp(360.0, 820.0).toDouble();
        return Center(
          child: Dialog(
            insetPadding: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            child: SizedBox(width: width, height: height, child: screen),
          ),
        );
      },
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.97, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  Widget _buildAuthScreen(
    String route,
    BuildContext context,
    bool isDesktop, {
    VoidCallback? onAuthenticated,
  }) {
    switch (route) {
      case '/login':
        return LoginView(
          onLogin: () => isDesktop
              ? _completeModalLogin(context, onAuthenticated: onAuthenticated)
              : _completePageLogin(context, onAuthenticated: onAuthenticated),
          onRegister: () => Navigator.pushNamed(context, '/register'),
          onGoogleSignIn: () => _completeGoogleSignIn(
            context,
            isDesktopModal: isDesktop,
            onAuthenticated: onAuthenticated,
          ),
        );
      case '/register':
        return RoleSelectionView(
          onBack: () => Navigator.pop(context),
          onSelect: (role) {
            AppSession.setRole(role);
            Navigator.pushReplacementNamed(context, '/register_form');
          },
        );
      case '/register_form':
        return RegisterView(
          onGoogleSignIn: () => _completeGoogleSignIn(
            context,
            isDesktopModal: isDesktop,
          ),
        );
      case '/otp':
        return const OtpView();
      case '/survey':
        return const TenantSurveyView();
      case '/onboarding':
        return OnboardingView(
          onFinish: () => Navigator.pushReplacementNamed(context, '/register'),
        );
      case '/role':
        return RoleSelectionView(
          onBack: () => Navigator.pushReplacementNamed(context, '/'),
          onSelect: AppSession.setRole,
        );
      case '/super_admin/login':
        return const SuperAdminLoginView();
      default:
        return const SizedBox.shrink();
    }
  }

  Route<dynamic>? _buildMessageModalRoute(RouteSettings settings) {
    if (settings.name != '/chat' && settings.name != '/messages') return null;

    final isChat = settings.name == '/chat';
    final rawArguments = settings.arguments;
    final arguments = rawArguments is Map ? rawArguments : const {};

    return PageRouteBuilder<void>(
      settings: settings,
      opaque: false,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.36),
      pageBuilder: (context, animation, secondaryAnimation) {
        final size = MediaQuery.sizeOf(context);
        final inset = size.width < 768 ? 8.0 : 24.0;
        final width = (size.width - inset * 2)
            .clamp(0.0, isChat ? 680.0 : 860.0)
            .toDouble();
        final height = (size.height - inset * 2)
            .clamp(0.0, isChat ? 800.0 : 840.0)
            .toDouble();

        Widget content;
        if (isChat) {
          content = ChatView(
            onBack: () => Navigator.of(context).pop(),
            userId: arguments['userId']?.toString() ?? '',
            name: arguments['name']?.toString() ?? 'Agent',
            avatar: arguments['avatar']?.toString() ?? '',
          );
        } else if (AppSession.isLandlord) {
          content = Stack(
            children: [
              Positioned.fill(
                child: LandlordMessagesPage(
                  onChatOpen: () {},
                  onChatClose: () {},
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  tooltip: 'Close messages',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
            ],
          );
        } else if (AppSession.isGuest) {
          content = Center(
            child: AlertDialog(
              title: const Text('Login required'),
              content: const Text(
                'Log in to access your messages and conversations.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
                FilledButton(
                  onPressed: () => _showLoginModal(
                    context,
                    onAuthenticated: () {
                      Navigator.of(context).pop();
                      navigatorKey.currentState?.pushNamed('/messages');
                    },
                  ),
                  child: const Text('Log in'),
                ),
              ],
            ),
          );
        } else {
          content = MessagesViewScreen(
            onClose: () => Navigator.of(context).pop(),
            onSelectChat: (userId, name, avatar) {
              Navigator.of(context).pop();
              WidgetsBinding.instance.addPostFrameCallback((_) {
                navigatorKey.currentState?.pushNamed(
                  '/chat',
                  arguments: {
                    'userId': userId,
                    'name': name,
                    'avatar': avatar ?? '',
                  },
                );
              });
            },
          );
        }

        return Center(
          child: Dialog(
            insetPadding: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: SizedBox(width: width, height: height, child: content),
          ),
        );
      },
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.97, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Responsive App Shell (Tenant View)
// ─────────────────────────────────────────────────────────────────────────────

enum _AppScreen { home, search, map, saved, messages, profile }

class AppShell extends StatefulWidget {
  final Future<void> Function(BuildContext context,
      {VoidCallback? onAuthenticated})? onRequireLogin;

  const AppShell({super.key, this.onRequireLogin});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  _AppScreen _screen = _AppScreen.home;
  final PropertyService _propertyService = PropertyService.instance;
  List<Property> _mapProperties = const [];
  String? _mapSearchQuery;

  String? _selectedPropertyId;
  String? _bookingPropertyId;
  Property? _selectedProperty;
  bool _loadingPropertyDetails = false;
  bool _showPhotoGallery = false;
  bool _showAmenities = false;
  bool _showLocation = false;
  bool _showLandlordInfo = false;
  bool _isMessageSelectionMode = false;
  bool _showDesktopNotifications = false;
  bool _showDesktopMessages = false;
  String? _desktopProfileHelperRoute;
  int _unreadNotificationCount = 0;
  int _unreadMessageCount = 0;
  Map<String, dynamic> _activeFilters = {};
  List<Property>? _searchCollectionProperties;
  String? _searchCollectionTitle;

  @override
  void initState() {
    super.initState();
    if (AppSession.isGuest) return;
    try {
      SocketService.instance
          .connect(url: AppSession.apiBaseUrl, token: AppSession.apiToken);
    } catch (_) {}
    _refreshDesktopCounts();
  }

  void _goTo(_AppScreen s) {
    if (s == _AppScreen.messages) {
      _openMessagesModal();
      return;
    }
    if (AppSession.isGuest &&
        (s == _AppScreen.saved || s == _AppScreen.profile)) {
      _requireAuthentication(onAuthenticated: () => _goTo(s));
      return;
    }
    setState(() {
      _screen = s;
      _showDesktopNotifications = false;
      _showDesktopMessages = false;
      _desktopProfileHelperRoute = null;
    });
    if (s == _AppScreen.messages) _refreshDesktopCounts();
  }

  Future<void> _switchToLandlordPortal() async {
    if (!AppSession.hasLandlordAccess) return;
    AppSession.setRole('landlord');
    await AppSession.persistSession();
    if (!mounted) return;
    navigatorKey.currentState?.pushNamedAndRemoveUntil<void>(
      '/landlord',
      (route) => false,
    );
  }

  Future<void> _refreshDesktopCounts() async {
    if (AppSession.isGuest) return;
    try {
      final results = await Future.wait<dynamic>([
        NotificationApi.fetchNotifications(limit: 1),
        MessageService.instance.fetchConversations(),
      ]);
      final notificationResponse = results[0] as Map<String, dynamic>;
      final meta = notificationResponse['meta'];
      final unreadNotifications = meta is Map
          ? int.tryParse(meta['unreadCount']?.toString() ?? '') ?? 0
          : 0;
      final conversations = results[1] as List<ConversationModel>;
      final unreadMessages = conversations.fold<int>(
        0,
        (total, conversation) => total + conversation.unreadCount,
      );
      if (!mounted) return;
      setState(() {
        _unreadNotificationCount = unreadNotifications;
        _unreadMessageCount = unreadMessages;
      });
    } catch (_) {
      // Counts are supplementary; keep the desktop actions usable on failure.
    }
  }

  void _toggleDesktopNotifications() {
    if (AppSession.isGuest) {
      _requireAuthentication(onAuthenticated: _toggleDesktopNotifications);
      return;
    }
    final show = !_showDesktopNotifications;
    setState(() {
      _showDesktopNotifications = show;
      _showDesktopMessages = false;
    });
    if (show) _refreshDesktopCounts();
  }

  void _toggleDesktopMessages() {
    final show = !_showDesktopMessages;
    setState(() {
      _showDesktopMessages = show;
      _showDesktopNotifications = false;
    });
    if (show) _refreshDesktopCounts();
  }

  void _closeDesktopPanels() {
    if (!_showDesktopNotifications && !_showDesktopMessages) return;
    setState(() {
      _showDesktopNotifications = false;
      _showDesktopMessages = false;
    });
    _refreshDesktopCounts();
  }

  void _openProfileHelper(String route) {
    if (route == '/reviews') {
      Navigator.pushNamed(context, route);
      return;
    }
    if (MediaQuery.sizeOf(context).width >= 900) {
      setState(() => _desktopProfileHelperRoute = route);
      return;
    }
    Navigator.pushNamed(context, route);
  }

  void _closeProfileHelper() {
    setState(() => _desktopProfileHelperRoute = null);
  }

  Widget _buildDesktopProfileHelper() {
    switch (_desktopProfileHelperRoute) {
      case '/edit_profile':
        return EditProfileView(
          onBack: _closeProfileHelper,
          onSave: _closeProfileHelper,
        );
      case '/tenant_profile':
        return TenantProfileView(onBack: _closeProfileHelper);
      case '/tenant_bookings':
        return TenantBookingsView(onBack: _closeProfileHelper);
      case '/landlord_bookings':
        return LandlordBookingsPage(onBack: _closeProfileHelper);
      case '/payment_methods':
        return PaymentMethodsViewScreen(onBack: _closeProfileHelper);
      case '/wallet':
        return WalletView(onBack: _closeProfileHelper);
      case '/referral':
        return ReferralView(onBack: _closeProfileHelper);
      case '/settings':
        return SettingView(
          onBack: _closeProfileHelper,
          onLogout: () async {
            await AppSession.reset();
            if (mounted) Navigator.pushReplacementNamed(context, '/');
          },
          onItemTap: (title) {
            if (title == 'Help & Support') {
              _openProfileHelper('/help_support');
            } else if (title == 'Notifications' ||
                title == 'Notification Settings') {
              _openProfileHelper('/notification_settings');
            } else if (title == 'Privacy & Security') {
              _openProfileHelper('/privacy');
            } else if (title == 'About StayNest') {
              _openProfileHelper('/about');
            }
          },
        );
      case '/help_support':
        return HelpSupportView(onBack: _closeProfileHelper);
      case '/notification_settings':
        return NotificationSettingsView(onBack: _closeProfileHelper);
      case '/privacy':
        return PrivacyPolicyView(onBack: _closeProfileHelper);
      case '/about':
        return AboutView(onBack: _closeProfileHelper);
      case '/verification_center':
        return VerificationCenter(onBack: _closeProfileHelper);
      case '/become_host':
        return BecomeHostView(
          onBack: _closeProfileHelper,
          onSubmitted: () {
            navigatorKey.currentState?.popUntil(
              (route) => route.settings.name == '/home' || route.isFirst,
            );
            _closeProfileHelper();
          },
          onSwitchToLandlord: _switchToLandlordPortal,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  void _openMessagesModal() {
    if (AppSession.isGuest) {
      _requireAuthentication(onAuthenticated: _openMessagesModal);
      return;
    }

    if (MediaQuery.sizeOf(context).width >= 768) {
      _toggleDesktopMessages();
      return;
    }

    showResponsiveModalSheet<void>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final height = MediaQuery.sizeOf(sheetContext).height * 0.94;
        void closeSheet() {
          setState(() => _isMessageSelectionMode = false);
          Navigator.of(sheetContext).pop();
        }

        return SizedBox(
          height: height,
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(20),
            ),
            child: MessagesViewScreen(
              onClose: closeSheet,
              onSelectionModeChanged: (isSelecting) {
                setState(() => _isMessageSelectionMode = isSelecting);
              },
              onSelectChat: (userId, name, avatar) {
                closeSheet();
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _openChat(userId, name, avatar);
                });
              },
            ),
          ),
        );
      },
    ).whenComplete(() {
      if (mounted) setState(() => _isMessageSelectionMode = false);
      _refreshDesktopCounts();
    });
  }

  void _handleNotificationsTap() {
    if (AppSession.isGuest) {
      _requireAuthentication(onAuthenticated: _handleNotificationsTap);
      return;
    }
    if (MediaQuery.sizeOf(context).width >= 768) {
      _toggleDesktopNotifications();
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NotificationsView()),
    );
  }

  void _showSearchMap(List<Property> properties, String searchQuery) {
    setState(() {
      _mapProperties = properties;
      _mapSearchQuery = searchQuery;
      _screen = _AppScreen.map;
    });
  }

  Future<void> _openLogin() => _requireAuthentication();

  void _openHostListing() {
    if (AppSession.isGuest) {
      _requireAuthentication(
        onAuthenticated: () => Navigator.pushNamed(context, '/list_property'),
      );
      return;
    }
    Navigator.pushNamed(context, '/list_property');
  }

  Future<void> _requireAuthentication({VoidCallback? onAuthenticated}) async {
    if (!AppSession.isGuest) return;
    await widget.onRequireLogin?.call(
      context,
      onAuthenticated: onAuthenticated,
    );
    if (!mounted) return;
    setState(() {});
    if (!AppSession.isGuest) {
      try {
        SocketService.instance
            .connect(url: AppSession.apiBaseUrl, token: AppSession.apiToken);
      } catch (_) {}
      _refreshDesktopCounts();
    }
  }

  Widget _buildGuestLoginPrompt(String title, IconData icon) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                    color: const Color(0xFF3F37C9).withOpacity(0.1),
                    shape: BoxShape.circle),
                child: Icon(icon, size: 48, color: const Color(0xFF3F37C9)),
              ),
              const SizedBox(height: 24),
              Text(title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF111827),
                      letterSpacing: -0.5)),
              const SizedBox(height: 12),
              Text('Log in to use this feature and access your account.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                      color: const Color(0xFF9CA3AF), fontSize: 14)),
              const SizedBox(height: 32),
              SizedBox(
                width: 180,
                height: 48,
                child: ElevatedButton(
                  onPressed: _openLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3F37C9),
                    minimumSize: Size.zero,
                    fixedSize: const Size(180, 48),
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24)),
                    elevation: 0,
                  ),
                  child: Text('Log in',
                      style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openFilter() {
    final screenSize = MediaQuery.sizeOf(context);

    if (screenSize.width >= 768) {
      showDialog<void>(
        context: context,
        builder: (dialogContext) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: SizedBox(
            width: (screenSize.width - 48).clamp(0, 760).toDouble(),
            height: (screenSize.height - 48).clamp(0, 820).toDouble(),
            child: _buildFilterView(dialogContext, desktop: true),
          ),
        ),
      );
      return;
    }

    showResponsiveModalSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _buildFilterView(sheetContext),
    );
  }

  Widget _buildFilterView(BuildContext routeContext, {bool desktop = false}) {
    return FilterView(
      desktopLayout: desktop,
      onClose: () => Navigator.of(routeContext).pop(),
      onApplyFilters: (filters) {
        setState(() => _activeFilters = filters);
      },
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
      _loadingPropertyDetails = false;
    });

    try {
      final property =
          await _propertyService.fetchPropertyById(initialProperty.id);
      if (mounted && property != null) {
        setState(() => _selectedProperty = property);
      }
    } catch (_) {}
  }

  void _closeProperty() {
    setState(() {
      _selectedPropertyId = null;
      _selectedProperty = null;
      _loadingPropertyDetails = false;
    });
  }

  void _openChat(String userId, String name, String? avatar) {
    Navigator.of(context, rootNavigator: true).pushNamed(
      '/chat',
      arguments: {
        'userId': userId,
        'name': name,
        'avatar': avatar ?? '',
      },
    );
  }

  bool get _isOverlayOpen =>
      _selectedPropertyId != null ||
      _bookingPropertyId != null ||
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

    return LayoutBuilder(builder: (context, constraints) {
      final isMobile = constraints.maxWidth < 768;
      final isExpandedDesktop = constraints.maxWidth >= 1200;

      if (!isMobile) {
        final panelWidth =
            (constraints.maxWidth - 32).clamp(320.0, 420.0).toDouble();
        final panelHeight =
            (constraints.maxHeight - 110).clamp(320.0, 640.0).toDouble();
        return Scaffold(
          backgroundColor: const Color(0xFFFAFAFA),
          body: Stack(
            children: [
              Column(
                children: [
                  _DesktopHeader(
                    current: _screen,
                    isExpanded: isExpandedDesktop,
                    onSelect: _goTo,
                    onHost: _openHostListing,
                    onNotifications: _toggleDesktopNotifications,
                    onMessages: _openMessagesModal,
                    unreadNotificationCount: _unreadNotificationCount,
                    unreadMessageCount: _unreadMessageCount,
                    notificationsOpen: _showDesktopNotifications,
                    messagesOpen: _showDesktopMessages,
                    onMenuAction: (action) {
                      switch (action) {
                        case _DesktopMenuAction.profile:
                          _goTo(_AppScreen.profile);
                        case _DesktopMenuAction.help:
                          Navigator.pushNamed(context, '/help_support');
                        case _DesktopMenuAction.privacy:
                          Navigator.pushNamed(context, '/privacy');
                      }
                    },
                  ),
                  Expanded(
                    child: ClipRect(
                      child: Stack(
                        children: [
                          Positioned.fill(child: baseScreen),
                          ..._buildOverlays(),
                        ],
                      ),
                    ),
                  ),
                  const _DesktopFooter(),
                ],
              ),
              if (_showDesktopNotifications || _showDesktopMessages)
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _closeDesktopPanels,
                    child: ColoredBox(
                      color: Colors.black.withValues(alpha: 0.06),
                    ),
                  ),
                ),
              if (_showDesktopNotifications)
                Positioned(
                  top: 76,
                  right: 190,
                  width: panelWidth,
                  height: panelHeight,
                  child: Material(
                    elevation: 16,
                    clipBehavior: Clip.antiAlias,
                    borderRadius: BorderRadius.circular(16),
                    child: NotificationsView(onClose: _closeDesktopPanels),
                  ),
                ),
              if (_showDesktopMessages)
                Positioned(
                  right: 24,
                  bottom: 24,
                  width: panelWidth,
                  height: panelHeight,
                  child: Material(
                    elevation: 16,
                    clipBehavior: Clip.antiAlias,
                    borderRadius: BorderRadius.circular(16),
                    child: MessagesViewScreen(
                      onClose: _closeDesktopPanels,
                      onSelectChat: (userId, name, avatarUrl) {
                        _closeDesktopPanels();
                        _openChat(userId, name, avatarUrl);
                      },
                    ),
                  ),
                ),
            ],
          ),
        );
      }

      return Scaffold(
        backgroundColor: const Color(0xFFFAFAFA),
        body: Stack(
          children: [
            Row(children: [Expanded(child: baseScreen)]),
            ..._buildOverlays(),
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 16,
              left: 0,
              right: 0,
              child: AnimatedSlide(
                offset: hideBottomNav ? const Offset(0, 1.5) : Offset.zero,
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: hideBottomNav ? 0.0 : 1.0,
                  child: Center(
                    child: _BottomNav(current: _screen, onTap: _goTo),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  List<Widget> _buildOverlays() => [
        if (_selectedPropertyId != null && _bookingPropertyId == null)
          _buildPropertyDetailsOverlay(),
        if (_bookingPropertyId != null)
          Positioned.fill(
            child: BookingView(
              key: ValueKey(_bookingPropertyId),
              propertyId: _bookingPropertyId!,
              embedded: true,
              onBack: () => setState(() => _bookingPropertyId = null),
              onComplete: _finishBookingInShell,
            ),
          ),
        if (_showPhotoGallery) _buildPhotoGalleryOverlay(),
        if (_showAmenities) _buildAmenitiesOverlay(),
        if (_showLocation) _buildLocationOverlay(),
        if (_showLandlordInfo) _buildLandlordInfoOverlay(),
      ];

  Widget _buildScreen() {
    switch (_screen) {
      case _AppScreen.home:
        return HomeView(
          key: const ValueKey('home'),
          onSelectProperty: _openProperty,
          onRequireAuthentication: _requireAuthentication,
          onSeeCategory: (cat) {
            setState(() {
              _searchCollectionProperties = null;
              _searchCollectionTitle = null;
              _activeFilters =
                  cat.isNotEmpty ? {'propertyType': cat} : <String, dynamic>{};
            });
            _goTo(_AppScreen.search);
          },
          onSeeCollection: (title, properties) {
            setState(() {
              _activeFilters = {};
              _searchCollectionProperties =
                  List<Property>.unmodifiable(properties);
              _searchCollectionTitle = title;
            });
            _goTo(_AppScreen.search);
          },
          onNotifications: _handleNotificationsTap,
        );
      case _AppScreen.search:
        return SearchView(
          key: const ValueKey('search'),
          onSelectProperty: _openProperty,
          onRequireAuthentication: _requireAuthentication,
          onShowMap: _showSearchMap,
          onOpenFilters: _openFilter,
          activeFilters: _activeFilters,
          onFiltersChanged: (f) => setState(() => _activeFilters = f),
          initialProperties: _searchCollectionProperties,
          initialTitle: _searchCollectionTitle,
        );
      case _AppScreen.map:
        return MapViewScreen(
          key: const ValueKey('search-map'),
          onBack: () => _goTo(_AppScreen.search),
          onFilter: _openFilter,
          onRequireAuthentication: _requireAuthentication,
          onSelectProperty: _openProperty,
          properties: _mapProperties,
          searchQuery: _mapSearchQuery,
        );
      case _AppScreen.saved:
        if (AppSession.isGuest) {
          return _buildGuestLoginPrompt(
              'Your saved properties', PhosphorIconsRegular.heart);
        }
        return SavedView(
          key: const ValueKey('saved'),
          onSelectProperty: (property) => _openProperty(property),
        );
      case _AppScreen.messages:
        return const SizedBox.shrink();
      case _AppScreen.profile:
        if (AppSession.isGuest) {
          return _buildGuestLoginPrompt(
              'Your profile', PhosphorIconsRegular.user);
        }
        return ProfileView(
          key: const ValueKey('profile'),
          onBack: () => _goTo(_AppScreen.home),
          desktopSelectedRoute: _desktopProfileHelperRoute,
          desktopHelperContent: _desktopProfileHelperRoute == null
              ? null
              : _buildDesktopProfileHelper(),
          onCloseDesktopHelper: _closeProfileHelper,
          onBecomeHost: () => _openProfileHelper('/become_host'),
          onSwitchRole: _switchToLandlordPortal,
          onViewBookings: () => _openProfileHelper(AppSession.isLandlord
              ? '/landlord_bookings'
              : '/tenant_bookings'),
          onEditProfile: () => _openProfileHelper('/edit_profile'),
          onMyProfile: () => _openProfileHelper('/tenant_profile'),
          onRefer: () => _openProfileHelper('/referral'),
          onSetting: (setting) {
            switch (setting) {
              case 'Personal Information':
                _openProfileHelper('/edit_profile');
                break;
              case 'Payment Methods':
                _openProfileHelper('/payment_methods');
                break;
              case 'Wallet':
                _openProfileHelper('/wallet');
                break;
              case 'Reviews':
                _openProfileHelper('/reviews');
                break;
              case 'Settings':
                _openProfileHelper('/settings');
                break;
              case 'Help & Support':
                _openProfileHelper('/help_support');
                break;
              case 'Notification Settings':
                _openProfileHelper('/notification_settings');
                break;
            }
          },
          onLogout: () async {
            await AppSession.reset();
            if (context.mounted) Navigator.pushReplacementNamed(context, '/');
          },
          onListProperty: () => Navigator.pushNamed(context, '/list_property'),
          onVerificationCenter: () =>
              _openProfileHelper('/verification_center'),
        );
    }
  }

  // Overlay builders
  Property? get _activeProperty {
    if (_selectedProperty != null) return _selectedProperty;
    if (_selectedPropertyId == null) return null;
    try {
      return properties.firstWhere((p) => p.id == _selectedPropertyId);
    } catch (_) {
      return null;
    }
  }

  Widget _buildPropertyDetailsOverlay() {
    if (_loadingPropertyDetails) {
      return const Material(
          color: Colors.transparent,
          child: Center(child: CircularProgressIndicator()));
    }
    final property = _activeProperty;
    if (property == null) return const SizedBox.shrink();
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
        onBookNow: () => setState(() => _bookingPropertyId = property.id),
        onRequireAuthentication: _requireAuthentication,
      ),
    );
  }

  void _finishBookingInShell() {
    setState(() {
      _bookingPropertyId = null;
      _selectedPropertyId = null;
      _selectedProperty = null;
      _screen = _AppScreen.profile;
      _desktopProfileHelperRoute = '/tenant_bookings';
    });
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
            videoUrl: property?.videoUrl));
  }

  Widget _buildAmenitiesOverlay() {
    final isDesktop = MediaQuery.sizeOf(context).width >= 900;
    final view = AmenitiesView(
      onClose: _closeAmenities,
      amenities: _activeProperty?.amenities ?? const [],
      customFeatures: _activeProperty?.customFeatures ?? const [],
    );

    if (!isDesktop) {
      return Material(color: Colors.transparent, child: view);
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        ModalBarrier(
          color: Colors.black.withValues(alpha: 0.32),
          dismissible: true,
          onDismiss: _closeAmenities,
          semanticsLabel: 'Close amenities dialog',
        ),
        Center(child: view),
      ],
    );
  }

  Widget _buildLocationOverlay() {
    if (_loadingPropertyDetails || _activeProperty == null) {
      return const Material(
          color: Colors.transparent,
          child: Center(child: CircularProgressIndicator()));
    }
    return Material(
      color: Colors.transparent,
      child: LocationView(
        property: _activeProperty,
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
            Navigator.pushNamed(context, '/commute', arguments: {
              'targetProperty': _activeProperty,
            });
          });
        },
      ),
    );
  }

  Widget _buildLandlordInfoOverlay() {
    return Material(
        color: Colors.transparent,
        child: LandlordInfoView(
          onClose: _closeLandlordInfo,
          property: _activeProperty,
          onRequireAuthentication: _requireAuthentication,
        ));
  }
}

enum _DesktopMenuAction { profile, help, privacy }

class _DesktopHeader extends StatelessWidget {
  final _AppScreen current;
  final ValueChanged<_AppScreen> onSelect;
  final VoidCallback onHost;
  final VoidCallback onNotifications;
  final VoidCallback onMessages;
  final ValueChanged<_DesktopMenuAction> onMenuAction;
  final bool isExpanded;
  final int unreadNotificationCount;
  final int unreadMessageCount;
  final bool notificationsOpen;
  final bool messagesOpen;

  const _DesktopHeader({
    required this.current,
    required this.onSelect,
    required this.onHost,
    required this.onNotifications,
    required this.onMessages,
    required this.onMenuAction,
    required this.isExpanded,
    required this.unreadNotificationCount,
    required this.unreadMessageCount,
    required this.notificationsOpen,
    required this.messagesOpen,
  });

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = isExpanded ? 36.0 : 20.0;
    return Container(
      height: 96,
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      color: Colors.white,
      child: Row(
        children: [
          Semantics(
            button: true,
            label: 'StayNest home',
            child: InkWell(
              onTap: () => onSelect(_AppScreen.home),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/images/logo.webp',
                    width: isExpanded ? 228 : 180,
                    height: isExpanded ? 70 : 54,
                    fit: BoxFit.contain,
                  ),
                ],
              ),
            ),
          ),
          const Spacer(flex: 2),
          for (final destination in [
            (_AppScreen.home, 'Explore', PhosphorIconsRegular.compass),
            (_AppScreen.search, 'Search', PhosphorIconsRegular.magnifyingGlass),
            (_AppScreen.saved, 'Saved', PhosphorIconsRegular.heart),
          ])
            _DesktopHeaderTab(
              label: destination.$2,
              icon: destination.$3,
              selected: current == destination.$1 ||
                  (current == _AppScreen.map &&
                      destination.$1 == _AppScreen.search),
              onTap: () => onSelect(destination.$1),
            ),
          const Spacer(flex: 2),
          TextButton(
            onPressed: onHost,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF111827),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            child: Text(
              isExpanded ? 'Become a host' : 'Host your property',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Notifications',
            onPressed: onNotifications,
            style: IconButton.styleFrom(
              backgroundColor: notificationsOpen
                  ? const Color(0xFFE3F2FD)
                  : Colors.transparent,
            ),
            icon: _HeaderCountIcon(
              icon: PhosphorIconsRegular.bell,
              count: unreadNotificationCount,
            ),
          ),
          IconButton(
            tooltip: 'Messages',
            onPressed: onMessages,
            style: IconButton.styleFrom(
              backgroundColor:
                  messagesOpen ? const Color(0xFFE3F2FD) : Colors.transparent,
            ),
            icon: _HeaderCountIcon(
              icon: PhosphorIconsRegular.chatTeardropText,
              count: unreadMessageCount,
            ),
          ),
          PopupMenuButton<_DesktopMenuAction>(
            tooltip: 'Account menu',
            onSelected: onMenuAction,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: _DesktopMenuAction.profile,
                child: Text('Profile'),
              ),
              const PopupMenuItem(
                value: _DesktopMenuAction.help,
                child: Text('Help & Support'),
              ),
              const PopupMenuItem(
                value: _DesktopMenuAction.privacy,
                child: Text('Privacy'),
              ),
            ],
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFD1D5DB)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.menu_rounded,
                      size: 18, color: Color(0xFF4B5563)),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 30,
                    height: 30,
                    child: ClipOval(
                      child:
                          AppSession.buildAvatar(AppSession.currentUserAvatar),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderCountIcon extends StatelessWidget {
  final IconData icon;
  final int count;

  const _HeaderCountIcon({required this.icon, required this.count});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon, size: 21, color: const Color(0xFF2196F3)),
        if (count > 0)
          Positioned(
            top: -8,
            right: -10,
            child: Container(
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: Color(0xFF2196F3),
                shape: BoxShape.circle,
              ),
              child: Text(
                count > 99 ? '99+' : '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _DesktopHeaderTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _DesktopHeaderTab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? const Color(0xFF111827) : const Color(0xFF6B7280);
    return SizedBox(
      width: 78,
      height: 84,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
            ),
            const SizedBox(height: 9),
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              height: 2,
              width: selected ? 34 : 0,
              color: const Color(0xFF111827),
            ),
          ],
        ),
      ),
    );
  }
}

class _DesktopFooter extends StatelessWidget {
  const _DesktopFooter();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Row(
        children: [
          Text(
            '© StayNest 2026',
            style: GoogleFonts.poppins(
                fontSize: 12, color: const Color(0xFF6B7280)),
          ),
          const Spacer(),
          TextButton(
            onPressed: () => Navigator.pushNamed(context, '/privacy'),
            child: Text('Privacy', style: GoogleFonts.poppins(fontSize: 12)),
          ),
          TextButton(
            onPressed: () => Navigator.pushNamed(context, '/help_support'),
            child: Text('Help & Support',
                style: GoogleFonts.poppins(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Mobile Pill Shaped Bottom Navigation Bar
// ─────────────────────────────────────────────────────────────────────────────

class _BottomNav extends StatelessWidget {
  final _AppScreen current;
  final void Function(_AppScreen) onTap;

  const _BottomNav({required this.current, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(40),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
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
              icon: PhosphorIconsRegular.house,
              activeIcon: PhosphorIconsFill.house,
              label: 'Home',
              active: current == _AppScreen.home,
              onTap: () => onTap(_AppScreen.home)),
          const SizedBox(width: 4),
          _NavItem(
              icon: PhosphorIconsRegular.magnifyingGlass,
              activeIcon: PhosphorIconsBold.magnifyingGlass,
              label: 'Search',
              active: current == _AppScreen.search || current == _AppScreen.map,
              onTap: () => onTap(_AppScreen.search)),
          const SizedBox(width: 4),
          _NavItem(
              icon: PhosphorIconsRegular.heart,
              activeIcon: PhosphorIconsFill.heart,
              label: 'Saved',
              active: current == _AppScreen.saved,
              onTap: () => onTap(_AppScreen.saved)),
          const SizedBox(width: 4),
          _NavItem(
              icon: PhosphorIconsRegular.chatTeardropText,
              activeIcon: PhosphorIconsFill.chatTeardropText,
              label: 'Messages',
              active: current == _AppScreen.messages,
              onTap: () => onTap(_AppScreen.messages)),
          const SizedBox(width: 4),
          _NavItem(
              icon: PhosphorIconsRegular.user,
              activeIcon: PhosphorIconsFill.user,
              label: 'Profile',
              active: current == _AppScreen.profile,
              onTap: () => onTap(_AppScreen.profile),
              isProfile: true),
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
      vsync: this, duration: const Duration(milliseconds: 150));
  late final Animation<double> _scale = Tween(begin: 1.0, end: 0.90)
      .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));

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
            color: widget.active
                ? const Color(0xFF3F37C9).withOpacity(0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.isProfile)
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: widget.active
                              ? const Color(0xFF3F37C9)
                              : Colors.transparent,
                          width: 2)),
                  clipBehavior: Clip.antiAlias,
                  child: AppSession.buildAvatar(AppSession.currentUserAvatar),
                )
              else
                Icon(widget.active ? widget.activeIcon : widget.icon,
                    color: widget.active
                        ? const Color(0xFF3F37C9)
                        : const Color(0xFF9CA3AF),
                    size: 24),
              if (widget.active) ...[
                const SizedBox(height: 3),
                Text(widget.label,
                    style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF3F37C9))),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
