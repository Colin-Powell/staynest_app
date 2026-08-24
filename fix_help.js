const fs = require('fs');
const file = 'frontend/lib/screens/dashboard/landlord_settings_page.dart';
let text = fs.readFileSync(file, 'utf8');

text = text.replace(
  `import 'package:property_app/screens/home/how_it_works_view.dart';`,
  `import 'package:property_app/screens/home/how_it_works_view.dart';\nimport 'package:property_app/screens/help_support_view.dart';`
);

text = text.replace(
  `const HowItWorksView(
                              title: 'Landlord Support',
                              subtitle:
                                  'Managing your properties and tenants on StayNest.',
                              details:
                                  'Find comprehensive guides on optimizing your listings, managing booking requests, and tracking your business performance analytics.',
                            )`,
  `HelpSupportView(onBack: () => Navigator.pop(context))`
);

fs.writeFileSync(file, text, 'utf8');
