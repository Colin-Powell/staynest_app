import re

with open('lib/services/google_auth_service.dart', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace(
    "'193200636263-d0l88jln8tojkbli1f6utkod9r4gm6u8.apps.googleusercontent.com'",
    "'193200636263-02mmqpu8fa9urq35p46432bdinilc29l.apps.googleusercontent.com'"
)

with open('lib/services/google_auth_service.dart', 'w', encoding='utf-8') as f:
    f.write(content)
