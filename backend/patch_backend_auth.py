import re

with open('src/config.ts', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace("googleClientId: process.env.GOOGLE_CLIENT_ID || '',", "googleClientId: process.env.GOOGLE_CLIENT_ID || '193200636263-d0l88jln8tojkbli1f6utkod9r4gm6u8.apps.googleusercontent.com',")

with open('src/config.ts', 'w', encoding='utf-8') as f:
    f.write(content)
