from pathlib import Path
p = Path('lib/main.dart')
t = p.read_text(encoding='utf-8')
t = t.replace("import 'app_theme.dart';\nimport 'app_theme.dart';\n", "import 'app_theme.dart';\n")
p.write_text(t, encoding='utf-8')
print('removed duplicate app_theme import')
