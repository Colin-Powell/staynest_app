from pathlib import Path
path = Path('lib/screens/home/home_view.dart')
text = path.read_text(encoding='utf-8')
text = text.replace('const AppColors.primaryText = Color(0xFF4F70F8);', 'const _primaryText = Color(0xFF4F70F8);')
path.write_text(text, encoding='utf-8')
print('fixed home_view top constant')
