const fs = require('fs');

function fixKyc() {
  const file = 'frontend/lib/screens/super_admin/super_admin_kyc.dart';
  let text = fs.readFileSync(file, 'utf8');

  // Fix surfaceVariantLight0 -> surfaceVariantLight
  text = text.replace(/StayNestColors\.surfaceVariantLight0/g, 'const Color(0xFFD1D5DB)'); // gray500 fallback
  text = text.replace(/const const Color/g, 'const Color');
  
  // Also remove the `intl` import and rewrite the date formatting to a simple split
  text = text.replace(/import 'package:intl\/intl.dart';\n/g, '');
  text = text.replace(/DateFormat\.yMMMd\(\)\.format\(DateTime\.parse\(item\['created_at'\]\)\)/g, "item['created_at'].toString().split('T')[0]");

  fs.writeFileSync(file, text, 'utf8');
  console.log('Fixed KYC dart errors');
}

function fixShell() {
  const file = 'frontend/lib/screens/super_admin/super_admin_shell.dart';
  let text = fs.readFileSync(file, 'utf8');

  text = text.replace(/AppSession\.currentUser\?\.name/g, "AppSession.currentUser?['name']");
  text = text.replace(/AppSession\.currentUser\?\[\'name\'\]/g, "(AppSession.currentUser != null ? AppSession.currentUser!['name'] : 'Admin')");
  // Clean up duplicate default
  text = text.replace(/AppSession\.currentUser \!= null \? AppSession\.currentUser!\['name'\] : 'Admin' \?\? 'Admin'/g, "(AppSession.currentUser != null ? AppSession.currentUser!['name'] : 'Admin')");

  fs.writeFileSync(file, text, 'utf8');
  console.log('Fixed Shell dart errors');
}

fixKyc();
fixShell();
