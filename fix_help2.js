const fs = require('fs');
const file = 'frontend/lib/screens/dashboard/landlord_settings_page.dart';
let text = fs.readFileSync(file, 'utf8');

text = text.replace(
  /const HowItWorksView\([\s\S]*?analytics\.',\s*\)/m,
  `HelpSupportView(onBack: () => Navigator.pop(context))`
);

fs.writeFileSync(file, text, 'utf8');
