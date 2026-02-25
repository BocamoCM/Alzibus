const pool = require('./db');

async function migrate() {
    try {
        console.log('Running database migration...');
        await pool.query('ALTER TABLE users ADD COLUMN IF NOT EXISTS is_verified BOOLEAN DEFAULT FALSE;');
        await pool.query('ALTER TABLE users ADD COLUMN IF NOT EXISTS verification_code VARCHAR(10);');
        console.log('Migration completed successfully!');
    } catch (err) {
        console.error('Migration failed:', err);
    } finally {
        pool.end();
    }
}

migrate();
