// ==========================================
// import_stops.js — Importador de paradas desde JSON a PostgreSQL
// ==========================================
// Script de utilidad que lee el archivo assets/stops.json (usado por la app Flutter)
// e inserta todas las paradas en la tabla 'stops' de PostgreSQL.
//
// Proceso:
// 1. Lee el archivo JSON con las paradas (nombre, coordenadas, líneas).
// 2. Limpia la tabla 'stops' completamente (TRUNCATE) para evitar duplicados.
// 3. Inserta cada parada una por una con su ID, nombre, lat, lng y líneas.
//
// IMPORTANTE: Este script BORRA todas las paradas existentes antes de importar.
// Solo ejecutar cuando se quiera sincronizar la DB con el archivo JSON.
//
// Uso: node import_stops.js

const fs = require('fs');       // Módulo nativo para leer archivos del sistema
const path = require('path');   // Módulo nativo para construir rutas multiplataforma
const pool = require('./db');   // Pool de conexiones a PostgreSQL

async function importStops() {
    try {
        // 1. Leer el archivo JSON de paradas de Flutter
        // El archivo está en la raíz del proyecto Flutter: assets/stops.json
        const stopsFilePath = path.join(__dirname, '../assets/stops.json');
        const rawData = fs.readFileSync(stopsFilePath, 'utf8');
        const stops = JSON.parse(rawData); // Parsear el JSON a un array de objetos

        console.log(`Encontradas ${stops.length} paradas en el archivo JSON.`);

        // 2. Limpiar la tabla actual completamente
        // RESTART IDENTITY reinicia el contador del ID (SERIAL) a 1.
        // Esto asegura que los IDs coincidan con los del archivo JSON.
        await pool.query('TRUNCATE TABLE stops RESTART IDENTITY');
        console.log('Tabla stops limpiada.');

        // 3. Insertar cada parada en la base de datos
        let insertedCount = 0;
        for (const stop of stops) {
            // Convertir el array de líneas a JSON string para almacenarlo en JSONB
            // Ejemplo: ["L1", "L2"] → '["L1","L2"]'
            const linesJson = JSON.stringify(stop.lines || []);

            // Insertar con consulta parametrizada ($1, $2...) para prevenir SQL injection
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
        // Cerrar la conexión a la base de datos (obligatorio en scripts CLI)
        pool.end();
    }
}

// Ejecutar la importación inmediatamente
importStops();