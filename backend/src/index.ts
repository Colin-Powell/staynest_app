import fs from 'fs/promises';
import path from 'path';
import app from './app.js';
import { env } from './config.js';
import { query } from './db.js';

function splitSqlStatements(sql: string): string[] {
  const statements: string[] = [];
  let current = '';
  let i = 0;

  while (i < sql.length) {
    const char = sql[i];
    const next = sql[i + 1] ?? '';

    if (char === '$' && next === '$') {
      const end = sql.indexOf('$$', i + 2);
      if (end === -1) {
        current += sql.slice(i);
        break;
      }

      current += sql.slice(i, end + 2);
      i = end + 2;
      continue;
    }

    if (char === ';') {
      const trimmed = current.trim();
      if (trimmed) statements.push(trimmed);
      current = '';
      i += 1;
      continue;
    }

    current += char;
    i += 1;
  }

  const trailing = current.trim();
  if (trailing) statements.push(trailing);

  return statements;
}

async function ensureDatabaseSchema() {
  const initSqlPath = path.resolve(process.cwd(), 'scripts', 'init-db.sql');
  try {
    const sql = await fs.readFile(initSqlPath, 'utf8');

    // Split into individual statements and execute sequentially so we can
    // ignore errors for objects that already exist (e.g. policies).
    const statements = splitSqlStatements(sql).filter((s) => s.length > 0);

    for (const stmt of statements) {
      try {
        await query(stmt);
      } catch (err: any) {
        // Ignore errors caused by attempting to create objects that already exist.
        // Postgres error codes for duplicate objects include:
        //  - 42710: duplicate_object (e.g. policy already exists)
        //  - 42P07: duplicate_table
        //  - 42701: duplicate_column
        const code = err && err.code;
        if (code === '42710' || code === '42P07' || code === '42701') {
          console.warn('Ignored expected DB init error:', err.message || err);
          continue;
        }
        throw err;
      }
    }

    console.log('Database schema initialized/updated from scripts/init-db.sql');
  } catch (error) {
    console.error('Failed to initialize database schema:', error);
    throw error;
  }
}

ensureDatabaseSchema()
  .then(async () => {
    // Use an explicit HTTP server so we can attach Socket.IO
    const http = await import('http');
    const server = http.createServer(app);

    // Initialize Socket.IO
    try {
      const { initSocket } = await import('./socket.js');
      initSocket(server);
      console.log('Socket.IO initialized');
    } catch (err) {
      console.warn('Socket.IO initialization skipped or failed:', err);
    }

    server.listen(env.port, () => {
      console.log(`staynest backend listening on http://localhost:${env.port}`);
    });
  })
.catch((_error) => {
    console.error('Backend startup failed due to database initialization error.');
    process.exit(1);
  });

