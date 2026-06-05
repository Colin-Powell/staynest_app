from pathlib import Path

replacements = {
    'const BorderSide(color: AppColors.primary)': 'BorderSide(color: AppColors.primary)',
    'const BorderSide(color: AppColors.primary, width: 1.5)': 'BorderSide(color: AppColors.primary, width: 1.5)',
    'style: const TextStyle(\n                    fontSize: 10,\n                    fontWeight: FontWeight.w800,\n                    color: AppColors.primary,': 'style: TextStyle(\n                    fontSize: 10,\n                    fontWeight: FontWeight.w800,\n                    color: AppColors.primary,',
}

paths = [
    Path('lib/main.dart'),
    Path('lib/screens/landlord/listing_flow.dart'),
    Path('lib/screens/landlord/verification_flow.dart'),
]
for path in paths:
    text = path.read_text(encoding='utf-8')
    for old, new in replacements.items():
        if old in text:
            text = text.replace(old, new)
    path.write_text(text, encoding='utf-8')
print('patched const AppColors usage')
