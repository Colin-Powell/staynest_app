import re

with open(r'D:\StayNest\landing\update.html', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace(
    '<main class="min-h-[60vh] flex flex-col items-center justify-center py-20 px-4">',
    '<main class="min-h-screen flex flex-col items-center pt-24 pb-12 px-4">'
)

# Let's also make the padding responsive on the cards
content = content.replace(
    'bg-white p-10 rounded-3xl',
    'bg-white p-6 sm:p-10 rounded-3xl'
)
content = content.replace(
    'bg-white p-8 rounded-3xl',
    'bg-white p-5 sm:p-8 rounded-3xl'
)

with open(r'D:\StayNest\landing\update.html', 'w', encoding='utf-8') as f:
    f.write(content)
print("Fixed responsiveness")
