const fs = require('fs');
const file = 'backend/src/app.ts';
let text = fs.readFileSync(file, 'utf8');

text = text.replace(
  "app.use(cors({ origin: env.corsOrigin, allowedHeaders: ['Content-Type', 'Authorization'] }));",
  "app.use(cors()); // Totally open CORS for all origins, headers, and methods"
);

fs.writeFileSync(file, text, 'utf8');
console.log('Fully opened CORS');
