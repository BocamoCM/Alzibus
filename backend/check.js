// ==========================================
// check.js — Utilidad para inspeccionar la estructura de una tabla
// ==========================================
// Script rápido de diagnóstico que muestra las columnas de la tabla 'stops'
// con su nombre, tipo de dato y valor por defecto.
// Útil para verificar que las migraciones se han aplicado correctamente.
//
// Uso: node check.js
// Salida: Array de objetos con { column_name, data_type, column_default }

const pool = require('./db'); // Pool de conexiones a PostgreSQL

// Consultar el esquema de la tabla 'stops' desde information_schema
// (catálogo interno de PostgreSQL que describe la estructura de todas las tablas)
pool.query("SELECT column_name, data_type, column_default FROM information_schema.columns WHERE table_name = 'stops'")
  .then(res => console.log(res.rows))   // Mostrar las columnas encontradas
  .catch(e => console.error(e))          // Mostrar error si la consulta falla
  .finally(() => pool.end());            // Cerrar la conexión al terminar
