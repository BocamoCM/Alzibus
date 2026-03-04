const pool = require('./db');

async function migrate() {
    try {
        console.log('Running Premium Status migration...');
        await pool.query('ALTER TABLE users ADD COLUMN IF NOT EXISTS is_premium BOOLEAN DEFAULT FALSE;');
        console.log('Migration completed!');
    } catch (err) {
        console.error('Migration failed:', err);
    } finally {
        pool.end();
    }
}

migrate();
