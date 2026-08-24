const fs = require('fs');
const file = 'backend/src/routes/uploads.ts';
let text = fs.readFileSync(file, 'utf8');

text = text.replace(/import\s+(\*\s+as\s+)?path\s+from\s+['"]path['"];\r?\n?/g, '');
text = text.replace(/import\s*\{\s*path\s*\}\s*from\s+['"]path['"];\r?\n?/g, '');

fs.writeFileSync(file, text, 'utf8');
console.log('Removed unused path import');
