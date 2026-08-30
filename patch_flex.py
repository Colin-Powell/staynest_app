import re

with open(r'D:\StayNest\landing\update.html', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace(
    '<main class="min-h-[60vh] flex items-center justify-center py-20 px-4">',
    '<main class="min-h-[60vh] flex flex-col items-center justify-center py-20 px-4">'
)

with open(r'D:\StayNest\landing\update.html', 'w', encoding='utf-8') as f:
    f.write(content)
print("Added flex-col to main")
