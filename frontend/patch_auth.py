import re

with open('lib/services/google_auth_service.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Add serverClientId
replacement = """  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    serverClientId: const String.fromEnvironment('GOOGLE_CLIENT_ID', defaultValue: '193200636263-d0l88jln8tojkbli1f6utkod9r4gm6u8.apps.googleusercontent.com'),
  );"""

content = re.sub(r'final GoogleSignIn _googleSignIn = GoogleSignIn\(\s*scopes: \[\'email\', \'profile\'\],\s*\);', replacement, content)

with open('lib/services/google_auth_service.dart', 'w', encoding='utf-8') as f:
    f.write(content)
