const fs = require('fs');
const path = require('path');
const pool = require('./db');

async function importStops() {
    try {
        // 1. Leer el archivo JSON de paradas de Flutter
        const stopsFilePath = path.join(__dirname, '../assets/stops.json');
        const rawData = fs.readFileSync(stopsFilePath, 'utf8');
        const stops = JSON.parse(rawData);

        console.log(`Encontradas ${stops.length} paradas en el archivo JSON.`);

        // 2. Limpiar la tabla actual (opcional, para no duplicar)
        await pool.query('TRUNCATE TABLE stops RESTART IDENTITY');
        console.log('Tabla stops limpiada.');

        // 3. Insertar cada parada en la base de datos
        let insertedCount = 0;
        for (const stop of stops) {
            // Guardar el array de líneas como JSON
            const linesJson = JSON.stringify(stop.lines || []);

            await pool.query(
                'INSERT INTO stops (id, name, lat, lng, lines) VALUES ($1, $2, $3, $4, $5)',
                [stop.id, stop.name, stop.lat, stop.lng, linesJson]
            );
            insertedCount++;
        }

        console.log(`✅ Importación completada: ${insertedCount} paradas insertadas en PostgreSQL.`);
    } catch (error) {
        console.error('❌ Error importando paradas:', error);
    } finally {
        // Cerrar la conexión a la base de datos
        pool.end();
    }
}

importStops();