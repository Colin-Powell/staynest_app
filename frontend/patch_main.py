import re

with open('lib/main.dart', 'r', encoding='utf-8') as f:
    content = f.read()

target = """  await AppSession.restoreSession();

  if (kDebugMode) {"""

replacement = """  await AppSession.restoreSession();
  
  if (AppSession.currentUserId != null) {
    AuthService.instance.syncFCMToken();
  }

  if (kDebugMode) {"""

if target in content:
    content = content.replace(target, replacement)
    with open('lib/main.dart', 'w', encoding='utf-8') as f:
        f.write(content)
    print("Patched main.dart")
else:
    print("Could not find target in main.dart")
