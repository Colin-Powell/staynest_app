const fs = require('fs');

const propFile = 'backend/src/routes/properties.ts';
let propText = fs.readFileSync(propFile, 'utf8');

// Add imports
propText = propText.replace(
  `import { requireAuth, requireLandlord, requireAdmin } from '../middleware/auth.js';`,
  `import { requireAuth, requireLandlord, requireAdmin } from '../middleware/auth.js';\nimport { routeCache } from '../middleware/cache.js';\nimport { cache } from '../services/cache.js';`
);

// Add caching to GET /
propText = propText.replace(
  `router.get('/', async (req: Request, res: Response, next: NextFunction) => {`,
  `router.get('/', routeCache(300), async (req: Request, res: Response, next: NextFunction) => {`
);

// Add caching to GET /:id
propText = propText.replace(
  `router.get('/:id', async (req: Request, res: Response, next: NextFunction) => {`,
  `router.get('/:id', routeCache(900), async (req: Request, res: Response, next: NextFunction) => {`
);

// Add invalidation to POST /
propText = propText.replace(
  `const insertRes = await query(`,
  `await cache.del('cache:/properties*');\n    const insertRes = await query(`
);

// Add invalidation to PUT /:id
propText = propText.replace(
  `const updateRes = await query(\n      \`UPDATE properties`,
  `await cache.del('cache:/properties*');\n    const updateRes = await query(\n      \`UPDATE properties`
);

// Add invalidation to DELETE /:id
propText = propText.replace(
  `await query('DELETE FROM properties WHERE id = $1', [id]);`,
  `await cache.del('cache:/properties*');\n    await query('DELETE FROM properties WHERE id = $1', [id]);`
);

fs.writeFileSync(propFile, propText, 'utf8');

const userFile = 'backend/src/routes/users.ts';
let userText = fs.readFileSync(userFile, 'utf8');

// Add imports
userText = userText.replace(
  `import bcrypt from 'bcrypt';`,
  `import bcrypt from 'bcrypt';\nimport { routeCache } from '../middleware/cache.js';\nimport { cache } from '../services/cache.js';`
);

// Add caching to GET /:id
userText = userText.replace(
  `router.get('/:id', async (req: Request, res: Response, next: NextFunction) => {`,
  `router.get('/:id', routeCache(3600), async (req: Request, res: Response, next: NextFunction) => {`
);

// Add invalidation to PATCH /profile
userText = userText.replace(
  `res.json({ data: result.rows[0] });`,
  `await cache.del('cache:/users*');\n    res.json({ data: result.rows[0] });`
);

fs.writeFileSync(userFile, userText, 'utf8');
console.log('Cache applied to properties and users routes');
