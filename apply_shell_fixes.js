const fs = require('fs');

function fixShell() {
  const file = 'frontend/lib/screens/super_admin/super_admin_shell.dart';
  let text = fs.readFileSync(file, 'utf8');

  text = text.replace(/AppColors\.outlineLight/g, 'StayNestColors.outlineLight');
  text = text.replace(/AppColors\.gray/g, 'StayNestColors.textSecondaryLight'); // Fallback approximation for all grays
  text = text.replace(/AppColors\.white/g, 'StayNestColors.surfaceLight');
  text = text.replace(/AppColors\.red500/g, 'StayNestColors.error');
  text = text.replace(/StayNestColors\.textSecondaryLight900/g, 'StayNestColors.textPrimaryLight');
  text = text.replace(/StayNestColors\.textSecondaryLight500/g, 'StayNestColors.textSecondaryLight');
  text = text.replace(/StayNestColors\.textSecondaryLight600/g, 'StayNestColors.textSecondaryLight');
  text = text.replace(/StayNestColors\.textSecondaryLight700/g, 'StayNestColors.textSecondaryLight');
  text = text.replace(/StayNestColors\.textSecondaryLight50/g, 'StayNestColors.surfaceVariantLight');
  
  text = text.replace(/AppTheme\.background/g, 'AppColors.background');

  fs.writeFileSync(file, text, 'utf8');
  console.log('Fixed shell dart errors');
}

fixShell();
