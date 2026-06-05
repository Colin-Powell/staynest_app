from pathlib import Path
path = Path('lib/app_theme.dart')
text = path.read_text(encoding='utf-8')
replacements = {
    'static const Color background = StayNestColors.backgroundLight;': 'static Color get background => AppColors.background;',
    'static const Color primary = StayNestColors.primary;': 'static Color get primary => AppColors.primary;',
    'static const Color primaryLight = StayNestColors.primaryLight;': 'static Color get primaryLight => AppColors.primaryLight;',
    'backgroundColor: StayNestColors.primary,': 'backgroundColor: AppColors.primary,',
    'disabledBackgroundColor: StayNestColors.primary.withOpacity(0.4),': 'disabledBackgroundColor: AppColors.primary.withOpacity(0.4),',
    'foregroundColor: StayNestColors.primary,': 'foregroundColor: AppColors.primary,',
    'side: const BorderSide(color: StayNestColors.primary, width: 1.5),': 'side: BorderSide(color: AppColors.primary, width: 1.5),',
    'floatingLabelStyle: const TextStyle(\n          color: StayNestColors.primary,': 'floatingLabelStyle: TextStyle(\n          color: AppColors.primary,',
    'selectedItemColor: StayNestColors.primary,': 'selectedItemColor: AppColors.primary,',
    'selectedColor: StayNestColors.primaryLight,': 'selectedColor: AppColors.primaryLight,',
    'primary: StayNestColors.primary,': 'primary: AppColors.primary,',
    'primary: StayNestColors.primary,\n    onPrimary: Colors.white,': 'primary: AppColors.primary,\n    onPrimary: Colors.white,',
}
for old, new in replacements.items():
    if old not in text:
        print(f'WARNING: did not find exact text: {old}')
    text = text.replace(old, new)
path.write_text(text, encoding='utf-8')
print('patched app_theme replacements')
