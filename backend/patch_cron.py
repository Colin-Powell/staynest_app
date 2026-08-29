import re

with open('src/services/cron.ts', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace("import { sendPushToUser } from './firebase.js';", "import { queueUserPush } from './queue.js';")
content = content.replace("await sendPushToUser(", "await queueUserPush(")

with open('src/services/cron.ts', 'w', encoding='utf-8') as f:
    f.write(content)
print("Patched cron.ts to use BullMQ queue for pushes")
