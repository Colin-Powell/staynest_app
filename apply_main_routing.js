const fs = require('fs');

const file = 'frontend/lib/main.dart';
let text = fs.readFileSync(file, 'utf8');

// 1. Add /admin route
text = text.replace(
  `'/portal': (context) => const LandlordDashboardView(),`,
  `'/portal': (context) => const LandlordDashboardView(),
          '/admin': (context) => const SuperAdminShell(),`
);

// 2. Update onLogin routing
text = text.replace(
  `// Landlords bypass tenant preferences
                if (AppSession.isLandlord) {`,
  `// Admins go to Super Admin panel
                if (AppSession.currentRole.toLowerCase() == 'admin') {
                  Navigator.pushReplacementNamed(context, '/admin');
                  return;
                }

                // Landlords bypass tenant preferences
                if (AppSession.isLandlord) {`
);

// 3. Update onGoogleSignIn routing
text = text.replace(
  `if (AppSession.isLandlord) {
                    Navigator.pushReplacementNamed(context, '/portal');
                    return;
                  }`,
  `if (AppSession.currentRole.toLowerCase() == 'admin') {
                      Navigator.pushReplacementNamed(context, '/admin');
                      return;
                    }
                    if (AppSession.isLandlord) {
                      Navigator.pushReplacementNamed(context, '/portal');
                      return;
                    }`
);

fs.writeFileSync(file, text, 'utf8');
console.log('Fixed main routing for admin');
