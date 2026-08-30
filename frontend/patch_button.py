import re

with open(r'lib/screens/auth/otp_view.dart', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace("'Resend code',", "'Send code',")

with open(r'lib/screens/auth/otp_view.dart', 'w', encoding='utf-8') as f:
    f.write(content)
print("Updated button text")
