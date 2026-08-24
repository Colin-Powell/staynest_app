const fs = require('fs');

function fixKyc() {
  const file = 'frontend/lib/screens/super_admin/super_admin_kyc.dart';
  let text = fs.readFileSync(file, 'utf8');

  text = text.replace(/AppColors\.outlineLight/g, 'StayNestColors.outlineLight');
  text = text.replace(/AppColors\.gray300/g, 'const Color(0xFFD1D5DB)');
  text = text.replace(/AppColors\.gray50/g, 'StayNestColors.surfaceVariantLight');
  text = text.replace(/AppTheme\.background/g, 'AppColors.background');
  text = text.replace(/PhosphorIcons\.fileSearch/g, 'PhosphorIcons.fileMagnifyingGlass');

  fs.writeFileSync(file, text, 'utf8');
  console.log('Fixed KYC dart errors');
}

fixKyc();
