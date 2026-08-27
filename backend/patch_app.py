import re

with open('src/app.ts', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace("import draftsRouter from './routes/drafts.js';", "import draftsRouter from './routes/drafts.js';\nimport versionRouter from './routes/version.js';\nimport path from 'path';\nimport { fileURLToPath } from 'url';")
content = content.replace("app.use(express.urlencoded({ extended: false }));", "app.use(express.urlencoded({ extended: false }));\n\nconst __dirname = path.dirname(fileURLToPath(import.meta.url));\napp.use(express.static(path.join(__dirname, '../public')));")
content = content.replace("app.use('/api/drafts', draftsRouter);", "app.use('/api/drafts', draftsRouter);\napp.use('/api/version', versionRouter);")

with open('src/app.ts', 'w', encoding='utf-8') as f:
    f.write(content)
