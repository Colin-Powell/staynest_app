class SignupDraft {
  final String fullName;
  final String phoneNumber;
  final String email;
  final String password;
  final bool agreedToTerms;
  final bool emailVerified;
  final bool phoneVerified;

  const SignupDraft({
    required this.fullName,
    required this.phoneNumber,
    required this.email,
    required this.password,
    required this.agreedToTerms,
    required this.emailVerified,
    required this.phoneVerified,
  });
}

class VerificationState {
  final String label;
  final String value;
  final String status;
  final String message;
  final String? imageUrl;
  final int attemptsLeft;

  const VerificationState({
    required this.label,
    required this.value,
    required this.status,
    required this.message,
    this.imageUrl,
    required this.attemptsLeft,
  });
}

class SettingsOption {
  final String title;
  final String subtitle;
  final String icon;
  final bool enabled;
  final String route;

  const SettingsOption({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.enabled,
    required this.route,
  });
}

class UserProfileFallback {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String avatarUrl;
  final String location;
  final bool isVerified;
  final String bio;

  const UserProfileFallback({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.avatarUrl,
    required this.location,
    required this.isVerified,
    required this.bio,
  });
}

class PropertyAssetFallback {
  final String id;
  final String title;
  final String location;
  final String category;
  final int price;
  final double rating;
  final String heroImage;
  final List<String> galleryImages;
  final String agentName;
  final String agentAvatar;
  final List<String> amenities;
  final String description;

  const PropertyAssetFallback({
    required this.id,
    required this.title,
    required this.location,
    required this.category,
    required this.price,
    required this.rating,
    required this.heroImage,
    required this.galleryImages,
    required this.agentName,
    required this.agentAvatar,
    required this.amenities,
    required this.description,
  });
}

class MockAppData {
  static const demoUser = UserProfileFallback(
    id: 'user_1001',
    name: 'Amina Kariuki',
    email: 'amina.kariuki@example.com',
    phone: '+254 712 345 678',
    avatarUrl: 'assets/images/profile.jpg',
    location: 'Nairobi, Kenya',
    isVerified: true,
    bio: 'Landlord • Property enthusiast • Available for viewings',
  );

  static const signUpDrafts = [
    SignupDraft(
      fullName: 'Amina Kariuki',
      phoneNumber: '+254 712 345 678',
      email: 'amina.kariuki@example.com',
      password: 'Staynest@2026',
      agreedToTerms: true,
      emailVerified: true,
      phoneVerified: true,
    ),
    SignupDraft(
      fullName: 'James Okoth',
      phoneNumber: '+254 721 882 344',
      email: 'james.okoth@example.com',
      password: 'SecurePass123',
      agreedToTerms: true,
      emailVerified: false,
      phoneVerified: false,
    ),
    SignupDraft(
      fullName: 'Sofia Mwai',
      phoneNumber: '+254 733 450 891',
      email: 'sofia.mwai@example.com',
      password: 'HelloWorld!2026',
      agreedToTerms: true,
      emailVerified: true,
      phoneVerified: true,
    ),
  ];

  static const verificationStates = [
    VerificationState(
      label: 'Phone verification',
      value: '+254 712 345 678',
      status: 'verified',
      message: 'Phone number has been verified successfully.',
      imageUrl: 'assets/images/hero.jpg',
      attemptsLeft: 3,
    ),
    VerificationState(
      label: 'Email verification',
      value: 'amina.kariuki@example.com',
      status: 'pending',
      message:
          'Enter the 6-digit code sent to your email to finish verification.',
      imageUrl: 'assets/images/hero1.jpg',
      attemptsLeft: 2,
    ),
    VerificationState(
      label: 'ID verification',
      value: 'Passport • Verified',
      status: 'reviewing',
      message:
          'Your document review is in progress. We will update you shortly.',
      imageUrl: 'assets/images/apertment1.jpg',
      attemptsLeft: 1,
    ),
  ];

  static const propertyFallbacks = [
    PropertyAssetFallback(
      id: 'prop_001',
      title: '11 Green Bank',
      location: 'Kilifi, Kenya',
      category: 'Apartment',
      price: 14500,
      rating: 4.8,
      heroImage: 'assets/images/hero.jpg',
      galleryImages: [
        'assets/images/hero.jpg',
        'assets/images/apertment1.jpg',
        'assets/images/apertment2.jpg',
        'assets/images/apertment3.jpg',
      ],
      agentName: 'John Kamau',
      agentAvatar: 'assets/images/profile.jpg',
      amenities: ['wifi', 'parking', 'security', 'water'],
      description:
          'Modern luxury home with great access to amenities and transport. Ideal for buyers and renters testing property flows.',
    ),
    PropertyAssetFallback(
      id: 'prop_002',
      title: 'Azure Heights',
      location: 'Mombasa, Kenya',
      category: 'Apartment',
      price: 12000,
      rating: 4.6,
      heroImage: 'assets/images/hero1.jpg',
      galleryImages: [
        'assets/images/hero1.jpg',
        'assets/images/apertment2.jpg',
        'assets/images/apertment3.jpg',
        'assets/images/hero2.jpg',
      ],
      agentName: 'Mary Wanjiku',
      agentAvatar: 'assets/images/profile.jpg',
      amenities: ['wifi', 'water', 'security'],
      description:
          'Stylish apartment with spacious rooms and a calm neighborhood vibe. Great for listing, gallery, and chat preview testing.',
    ),
    PropertyAssetFallback(
      id: 'prop_003',
      title: 'Modern Studio',
      location: 'Nairobi, Kenya',
      category: 'Studio',
      price: 8000,
      rating: 4.5,
      heroImage: 'assets/images/apertment1.jpg',
      galleryImages: [
        'assets/images/apertment1.jpg',
        'assets/images/hero3.jpg',
        'assets/images/rec1.jpg',
        'assets/images/rec2.jpg',
      ],
      agentName: 'David Ochieng',
      agentAvatar: 'assets/images/profile.jpg',
      amenities: ['wifi', 'water'],
      description:
          'A compact studio with clean finishes and flexible use. Perfect for testing photo and detail flows.',
    ),
    PropertyAssetFallback(
      id: 'prop_004',
      title: 'Skyline Loft',
      location: 'Westlands, Nairobi',
      category: 'Penthouse',
      price: 18000,
      rating: 4.9,
      heroImage: 'assets/images/hero2.jpg',
      galleryImages: [
        'assets/images/hero2.jpg',
        'assets/images/hero3.jpg',
        'assets/images/rec3.jpg',
        'assets/images/apertment3.jpg',
      ],
      agentName: 'Aisha Njeri',
      agentAvatar: 'assets/images/profile.jpg',
      amenities: ['wifi', 'security', 'parking', 'water'],
      description:
          'A premium penthouse setup with rich interiors and curated visual assets for UI testing.',
    ),
  ];

  static final propertyFallbackMap = {
    for (final property in propertyFallbacks) property.id: property,
  };

  static const settingsOptions = [
    SettingsOption(
      title: 'Notifications',
      subtitle: 'Manage push, email, and SMS alerts',
      icon: 'assets/images/hero2.jpg',
      enabled: true,
      route: '/settings/notifications',
    ),
    SettingsOption(
      title: 'Privacy & Security',
      subtitle:
          'Two-factor authentication, device history, and privacy controls',
      icon: 'assets/images/apertment2.jpg',
      enabled: true,
      route: '/settings/privacy',
    ),
    SettingsOption(
      title: 'Payment Methods',
      subtitle: 'Saved cards and wallet preferences',
      icon: 'assets/images/apertment3.jpg',
      enabled: true,
      route: '/settings/payments',
    ),
    SettingsOption(
      title: 'Help & Support',
      subtitle: 'FAQs, chat support, and contact centre',
      icon: 'assets/images/rec1.jpg',
      enabled: true,
      route: '/settings/help',
    ),
    SettingsOption(
      title: 'About StayNest',
      subtitle: 'Version info, legal notices, and app updates',
      icon: 'assets/images/rec2.jpg',
      enabled: true,
      route: '/settings/about',
    ),
  ];

  static const localAssetImages = [
    'assets/images/hero.jpg',
    'assets/images/hero1.jpg',
    'assets/images/hero2.jpg',
    'assets/images/hero3.jpg',
    'assets/images/apertment1.jpg',
    'assets/images/apertment2.jpg',
    'assets/images/apertment3.jpg',
    'assets/images/profile.jpg',
    'assets/images/rec1.jpg',
    'assets/images/rec2.jpg',
    'assets/images/rec3.jpg',
  ];

  static const fallbackOtpCode = '624108';

  static const sampleVerificationResponse = {
    'status': 'success',
    'code': '624108',
    'message': 'Code verified successfully',
    'expiresInSeconds': 60,
  };
}
