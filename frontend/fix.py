import re

with open('lib/services/uploads.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Fix string interpolations
content = content.replace('Bearer ', r'Bearer ')
content = content.replace(r'"$"{"token ?? AppSession.apiToken}"}"', r'')
content = content.replace(r'"$"{"response.statusCode"}"', r'')
content = content.replace(r'"$"{"response.body"}"', r'')
content = content.replace(r'"$"{"jobData[\'error\']"}"', r'')

with open('lib/services/uploads.dart', 'w', encoding='utf-8') as f:
    f.write(content)
