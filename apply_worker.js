const fs = require('fs');
const file = 'backend/src/index.ts';
let text = fs.readFileSync(file, 'utf8');

text = text.replace(
  `import { startCronJobs } from './services/cron.js';`,
  `import { startCronJobs } from './services/cron.js';\nimport './workers/mediaWorker.js';`
);

fs.writeFileSync(file, text, 'utf8');
console.log('Imported media worker');
