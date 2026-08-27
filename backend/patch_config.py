import re

with open('src/config.ts', 'r', encoding='utf-8') as f:
    content = f.read()

# Add missing env variables to the end of the `env` object before the closing `};`
replacement = """  googleClientId: process.env.GOOGLE_CLIENT_ID || '193200636263-02mmqpu8fa9urq35p46432bdinilc29l.apps.googleusercontent.com',
  firebaseServiceAccount: process.env.FIREBASE_SERVICE_ACCOUNT || '',
  appLatestVersion: process.env.APP_LATEST_VERSION || '1.0.0',
  appUpdateUrl: process.env.APP_UPDATE_URL || 'https://staynest.top/update.html',
  forceUpdate: process.env.FORCE_UPDATE === 'true',
};"""

content = re.sub(r'  googleClientId:.*?\n  firebaseServiceAccount:.*?\n};', replacement, content, flags=re.DOTALL)

with open('src/config.ts', 'w', encoding='utf-8') as f:
    f.write(content)
