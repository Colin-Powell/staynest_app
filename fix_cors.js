const fs = require('fs');
const file = 'backend/src/config.ts';
let text = fs.readFileSync(file, 'utf8');

text = text.replace(
  "corsOrigin: process.env.CORS_ORIGIN || 'http://localhost:8080',",
  "corsOrigin: process.env.CORS_ORIGIN || '*', // Changed to * to support random local Flutter ports"
);

fs.writeFileSync(file, text, 'utf8');
console.log('Fixed CORS');
