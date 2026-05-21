// ==========================================
// db_migrate_game_coins.js
// ==========================================
// Añade columna `game_coins` a `users` para persistir las monedas que el
// jugador acumula en los mini-juegos (Caza el Bus, Trivia, Memoria).
//
// La app las usa para desbloquear skins de Albus (Fallero, Capurullo…).
// Antes solo estaban en SharedPreferences local: se perdían al
// reinstalar la app o al cambiar de móvil. Ahora viven en la BD y la
// app sincroniza local↔servidor.
//
// Uso: docker compose exec backend node db_migrate_game_coins.js
// Idempotente (ADD COLUMN IF NOT EXISTS).

const pool = require('./db');

async function migrate() {
    try {
        console.log('Running game_coins migration...');
        await pool.query(`
            ALTER TABLE users
            ADD COLUMN IF NOT EXISTS game_coins INTEGER NOT NULL DEFAULT 0;
        `);
        await pool.query(`
            ALTER TABLE users
            ADD COLUMN IF NOT EXISTS owned_skins TEXT NOT NULL DEFAULT 'default';
        `);
        console.log('Migration completed!');
    } catch (err) {
        console.error('Migration failed:', err);
        process.exitCode = 1;
    } finally {
        pool.end();
    }
}

migrate();
