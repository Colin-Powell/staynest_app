import re

with open("backend/src/routes/admin.ts", "r", encoding="utf-8") as f:
    code = f.read()

code = code.replace(
    "p.status,\n        p.created_at,\n        p.updated_at,",
    "p.status,\n        p.created_at,\n        p.created_at as updated_at,"
)

with open("backend/src/routes/admin.ts", "w", encoding="utf-8") as f:
    f.write(code)

print("Removed p.updated_at from properties query")
