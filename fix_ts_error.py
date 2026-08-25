import re

with open("backend/src/routes/admin.ts", "r", encoding="utf-8") as f:
    code = f.read()

code = code.replace(
    "router.get('/overview', requireAuth, authorize('admin'), async (req: Request, res: Response, next: NextFunction)",
    "router.get('/overview', requireAuth, authorize('admin'), async (_req: Request, res: Response, next: NextFunction)"
)

with open("backend/src/routes/admin.ts", "w", encoding="utf-8") as f:
    f.write(code)
print("Fixed TS error")
