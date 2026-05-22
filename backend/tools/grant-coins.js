#!/usr/bin/env node
// ==========================================
// tools/grant-coins.js
// ==========================================
// Script de admin para regalar monedas / desbloquear skins a un usuario
// concreto desde la Pi vía SSH. Útil para testing del autor o para
// compensaciones puntuales (ej: usuario reporta bug y pierde monedas).
//
// Uso:
//   docker compose exec backend node tools/grant-coins.js <email> <coins> [--all-skins]
//
// Ejemplos:
//   docker compose exec backend node tools/grant-coins.js bcarreres55@gmail.com 1000
//   docker compose exec backend node tools/grant-coins.js bcarreres55@gmail.com 5000 --all-skins
//   docker compose exec backend node tools/grant-coins.js bcarreres55@gmail.com 0 --all-skins
//
// No requiere ninguna autenticación porque corre dentro del contenedor
// (que solo es accesible desde la Pi vía SSH).

const path = require('path');
const pool = require(path.join(__dirname, '..', 'db'));

// Lista de skins conocidos. Mantener en sync con lib/models/albus_skin.dart.
const ALL_SKIN_IDS = [
    'default',
    'fallero',
    'capurullo',
    'lluvia',
    'graduado',
    'navidad',
    'alzira_fc',
];

async function main() {
    const [email, coinsArg, ...flags] = process.argv.slice(2);

    if (!email || coinsArg === undefined) {
        console.error('Uso: node tools/grant-coins.js <email> <coins> [--all-skins]');
        console.error('');
        console.error('Ejemplos:');
        console.error('  node tools/grant-coins.js bcarreres55@gmail.com 1000');
        console.error('  node tools/grant-coins.js bcarreres55@gmail.com 5000 --all-skins');
        process.exit(1);
    }

    const coinsToAdd = parseInt(coinsArg, 10);
    if (Number.isNaN(coinsToAdd)) {
        console.error(`Error: "${coinsArg}" no es un número válido.`);
        process.exit(1);
    }

    const unlockAll = flags.includes('--all-skins');

    try {
        // 1. Buscar usuario
        const userRes = await pool.query(
            'SELECT id, email, game_coins, owned_skins FROM users WHERE email = $1',
            [email]
        );
        if (userRes.rows.length === 0) {
            console.error(`❌ Usuario con email "${email}" no encontrado.`);
            process.exit(1);
        }

        const user = userRes.rows[0];
        console.log(`✅ Usuario encontrado: id=${user.id}, email=${user.email}`);
        console.log(`   Estado actual:`);
        console.log(`     game_coins:  ${user.game_coins}`);
        console.log(`     owned_skins: ${user.owned_skins}`);
        console.log('');

        // 2. Actualizar monedas
        const newCoins = (user.game_coins || 0) + coinsToAdd;
        await pool.query('UPDATE users SET game_coins = $1 WHERE id = $2',
            [newCoins, user.id]);
        console.log(`💰 Monedas: ${user.game_coins} → ${newCoins} (Δ ${coinsToAdd >= 0 ? '+' : ''}${coinsToAdd})`);

        // 3. Si --all-skins, desbloquear todos
        if (unlockAll) {
            const existingSkins = (user.owned_skins || 'default').split(',').filter(Boolean);
            const allUnique = Array.from(new Set([...existingSkins, ...ALL_SKIN_IDS])).join(',');
            await pool.query('UPDATE users SET owned_skins = $1 WHERE id = $2',
                [allUnique, user.id]);
            console.log(`🎭 Skins desbloqueados: ${allUnique}`);
        }

        console.log('');
        console.log('✅ Hecho. El usuario verá los cambios al volver a abrir la app');
        console.log('   (o cuando refresque desde la tienda — el reconcile se');
        console.log('    dispara al abrir el Vestidor).');
    } catch (err) {
        console.error('❌ Error:', err.message);
        if (err.code === '42703') {
            console.error('');
            console.error('⚠️  Las columnas game_coins / owned_skins no existen.');
            console.error('    Ejecuta primero la migración:');
            console.error('    docker compose exec backend node db_migrate_game_coins.js');
        }
        process.exit(1);
    } finally {
        await pool.end();
    }
}

main();
