import re

with open('src/config.ts', 'r', encoding='utf-8') as f:
    content = f.read()

target = "  forceUpdate: process.env.FORCE_UPDATE === 'true',\n};"
replacement = "  forceUpdate: process.env.FORCE_UPDATE === 'true',\n  redisUrl: process.env.REDIS_URL || 'redis://localhost:6379',\n};"

content = content.replace(target, replacement)

with open('src/config.ts', 'w', encoding='utf-8') as f:
    f.write(content)
