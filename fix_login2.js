const fs = require('fs');
const file = 'frontend/lib/screens/super_admin/super_admin_login.dart';
let text = fs.readFileSync(file, 'utf8');

text = text.replace(/TextButton\(\s*onPressed: \(\) => Navigator\.pushReplacementNamed\(context, '\/login'\),\s*child: Text\(\s*'Return to public login',\s*style: GoogleFonts\.poppins\(color: StayNestColors\.textSecondaryLight\),\s*\),\s*\),/g, '');

fs.writeFileSync(file, text, 'utf8');
