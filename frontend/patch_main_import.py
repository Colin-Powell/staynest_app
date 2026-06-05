from pathlib import Path
p = Path('lib/main.dart')
t = p.read_text(encoding='utf-8')
old = "import 'session/app_session.dart';\n"
new = "import 'app_theme.dart';\nimport 'session/app_session.dart';\n"
if old not in t:
    raise SystemExit('import line not found')
t = t.replace(old, new)
p.write_text(t, encoding='utf-8')
print('patched main import')
