import { Pool } from 'pg';
import { env } from './config.js';
export const pool = new Pool({ connectionString: env.databaseUrl });
pool.on('error', (error) => {
    console.error('Postgres client error:', error);
});
export async function query(queryText, params) {
    return pool.query(queryText, params);
}
export async function withAppUser(userId, callback) {
    const client = await pool.connect();
    try {
        // Postgres does not allow $1 placeholders directly in SET statements.
        // Use set_config() to set a local (transaction-scoped) GUC value instead.
        await client.query('SELECT set_config($1, $2, true)', ['app.current_user_id', userId]);
        return await callback(client);
    }
    finally {
        client.release();
    }
}
//# sourceMappingURL=db.js.map