-- Crear tabla de usuarios
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Crear tabla de paradas
CREATE TABLE IF NOT EXISTS stops (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    lat DOUBLE PRECISION NOT NULL,
    lng DOUBLE PRECISION NOT NULL
);

-- Insertar algunas paradas de prueba (solo si la tabla está vacía)
INSERT INTO stops (name, lat, lng) 
SELECT 'Parada Central', 39.1234, -0.1234
WHERE NOT EXISTS (SELECT 1 FROM stops WHERE name = 'Parada Central');

INSERT INTO stops (name, lat, lng) 
SELECT 'Estación Norte', 39.1245, -0.1245
WHERE NOT EXISTS (SELECT 1 FROM stops WHERE name = 'Estación Norte');