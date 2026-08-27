import re

with open('src/routes/version.ts', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace("router.get('/', (req, res) => {", "router.get('/', (_req, res) => {")

with open('src/routes/version.ts', 'w', encoding='utf-8') as f:
    f.write(content)
