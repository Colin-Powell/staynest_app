import 'package:property_app/data/mock_data.dart';

const mockRepositoryProvider = MockRepository();

final propertiesProvider = mockRepositoryProvider.properties;
final bookingsProvider = mockRepositoryProvider.bookings;
final tenantsProvider = mockRepositoryProvider.tenants;
final conversationsProvider = mockRepositoryProvider.conversations;
final revenueTrendProvider = mockRepositoryProvider.revenueTrend;
final landlordProfileProvider = mockRepositoryProvider.landlordProfile;

String? selectedPropertyProvider;
int? selectedConversationProvider;
