// lib/screens/screens.dart

export 'auth/login_view.dart' hide main;
export 'auth/register_view.dart';
export 'auth/otp_view.dart';
export 'auth/splash_view.dart' hide main;
export 'auth/onboarding_view.dart' hide main;

export 'auth/role_selection_view.dart' hide main;

export 'home/home_view.dart';
export 'home/search_view.dart';
export 'home/saved_view.dart';
export 'home/messages_view.dart';
export 'home/profile_view.dart';
export 'home/setting_view.dart';
export 'home/help_support_view.dart';
export 'home/how_it_works_view.dart';
export 'home/referral_view.dart';
export 'home/nearby_services_view.dart';
export 'home/map_view.dart';

export 'edit_profile_view.dart';

export 'my_bookings_view.dart' hide Property, properties, AppScrollBehavior;

export 'property/property_details.dart';
export 'property/filter_view.dart';
export 'property/booking_view.dart';
export 'property/payment_methods_view.dart' hide AppScrollBehavior;
export 'property/photo_gallery_view.dart';
export 'property/amenities_view.dart';
export 'property/location_view.dart';
export 'property/commute_methods_view.dart';
export 'property/landlord_info_view.dart';
export 'property/landlord_properties_view.dart';
export 'property/landlord_reviews_view.dart';
export 'property/add_property_view.dart';

export 'landlord/verification_flow.dart';
export 'landlord/listing_flow.dart' hide ModalUtils;
export 'landlord/landlord_bookings_view.dart';

export 'tenant/tenant_bookings_view.dart';

export 'reviews_view.dart' hide AppScrollBehavior;

export 'dashboard/admin_dashboard_view.dart';
export 'dashboard/landlord_portal_view.dart';
export 'dashboard/landlord_settings_page.dart';

export 'communication/chat_view.dart';
export 'communication/calling_view.dart';
export 'communication/notifications_view.dart';
