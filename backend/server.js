const express = require('express');
const cors = require('cors');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const pool = require('./db');
require('dotenv').config();

const app = express();

// Middlewares
app.use(cors());
app.use(express.json()); // Para poder leer JSON en el body de las peticiones

// Middleware para registrar las peticiones a la API
app.use((req, res, next) => {
    const start = Date.now();
    res.on('finish', () => {
        const duration = Date.now() - start;
        // No registrar las peticiones de stats para no inflar los números
        if (!req.path.startsWith('/api/stats')) {
            pool.query(
                'INSERT INTO api_logs (endpoint, method, duration_ms) VALUES ($1, $2, $3)',
                [req.path, req.method, duration]
            ).catch(err => console.error('Error logging API request:', err));
        }
    });
    next();
});

const PORT = process.env.PORT || 3000;

// ==========================================
// RUTAS DE AUTENTICACIÓN (LOGIN / REGISTRO)
// ==========================================

// 1. Registro de usuario
app.post('/api/register', async (req, res) => {
    const { email, password } = req.body;

    if (!email || !password) {
        return res.status(400).json({ error: 'Email y contraseña son obligatorios' });
    }

    try {
        // Verificar si el usuario ya existe
        const userExists = await pool.query('SELECT * FROM users WHERE email = $1', [email]);
        if (userExists.rows.length > 0) {
            return res.status(400).json({ error: 'El usuario ya existe' });
        }

        // Encriptar la contraseña (10 rondas de sal)
        const saltRounds = 10;
        const passwordHash = await bcrypt.hash(password, saltRounds);

        // Guardar en la base de datos
        const newUser = await pool.query(
            'INSERT INTO users (email, password_hash) VALUES ($1, $2) RETURNING id, email',
            [email, passwordHash]
        );

        res.status(201).json({ 
            message: 'Usuario registrado con éxito', 
            user: newUser.rows[0] 
        });
    } catch (error) {
        console.error('Error en registro:', error);
        res.status(500).json({ error: 'Error interno del servidor' });
    }
});

// 2. Login de usuario
app.post('/api/login', async (req, res) => {
    const { email, password } = req.body;

    if (!email || !password) {
        return res.status(400).json({ error: 'Email y contraseña son obligatorios' });
    }

    try {
        // Buscar al usuario por email
        const result = await pool.query('SELECT * FROM users WHERE email = $1', [email]);
        if (result.rows.length === 0) {
            return res.status(401).json({ error: 'Credenciales inválidas' });
        }

        const user = result.rows[0];

        // Comparar la contraseña enviada con el hash guardado
        const validPassword = await bcrypt.compare(password, user.password_hash);
        if (!validPassword) {
            return res.status(401).json({ error: 'Credenciales inválidas' });
        }

        // Generar el token JWT
        const token = jwt.sign(
            { id: user.id, email: user.email }, 
            process.env.JWT_SECRET, 
            { expiresIn: '24h' } // El token caduca en 24 horas
        );

        res.json({ 
            message: 'Login exitoso', 
            token: token,
            user: { id: user.id, email: user.email }
        });
    } catch (error) {
        console.error('Error en login:', error);
        res.status(500).json({ error: 'Error interno del servidor' });
    }
});

// ==========================================
// RUTAS DE PARADAS DE AUTOBÚS
// ==========================================

// 3. Obtener todas las paradas
app.get('/api/stops', async (req, res) => {
    try {
        const result = await pool.query('SELECT * FROM stops ORDER BY id ASC');
        res.json(result.rows);
    } catch (error) {
        console.error('Error al obtener paradas:', error);
        res.status(500).json({ error: 'Error al obtener las paradas' });
    }
});

// 4. Crear una nueva parada
app.post('/api/stops', async (req, res) => {
    const { name, lat, lng, lines } = req.body;
    try {
        const linesJson = JSON.stringify(lines || []);
        const result = await pool.query(
            'INSERT INTO stops (name, lat, lng, lines) VALUES ($1, $2, $3, $4) RETURNING *',
            [name, lat, lng, linesJson]
        );
        res.status(201).json(result.rows[0]);
    } catch (error) {
        console.error('Error al crear parada:', error);
        res.status(500).json({ error: 'Error al crear la parada' });
    }
});

// 5. Actualizar una parada existente
app.put('/api/stops/:id', async (req, res) => {
    const { id } = req.params;
    const { name, lat, lng, lines } = req.body;
    try {
        const linesJson = JSON.stringify(lines || []);
        const result = await pool.query(
            'UPDATE stops SET name = $1, lat = $2, lng = $3, lines = $4 WHERE id = $5 RETURNING *',
            [name, lat, lng, linesJson, id]
        );
        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Parada no encontrada' });
        }
        res.json(result.rows[0]);
    } catch (error) {
        console.error('Error al actualizar parada:', error);
        res.status(500).json({ error: 'Error al actualizar la parada' });
    }
});

// 6. Eliminar una parada
app.delete('/api/stops/:id', async (req, res) => {
    const { id } = req.params;
    try {
        const result = await pool.query('DELETE FROM stops WHERE id = $1 RETURNING *', [id]);
        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Parada no encontrada' });
        }
        res.json({ message: 'Parada eliminada con éxito' });
    } catch (error) {
        console.error('Error al eliminar parada:', error);
        res.status(500).json({ error: 'Error al eliminar la parada' });
    }
});

// ==========================================
// RUTAS DE ESTADÍSTICAS (ADMIN PANEL)
// ==========================================

// 7. Obtener estadísticas generales
app.get('/api/stats', async (req, res) => {
    try {
        const stopsCount = await pool.query('SELECT COUNT(*) FROM stops');
        const usersCount = await pool.query('SELECT COUNT(*) FROM users');
        const todayQueries = await pool.query('SELECT COUNT(*) FROM api_logs WHERE created_at >= CURRENT_DATE');
        const avgResponseTime = await pool.query('SELECT AVG(duration_ms) FROM api_logs');
        
        // Calcular rutas únicas (L1, L2, L3)
        const routesResult = await pool.query(`
            SELECT DISTINCT jsonb_array_elements_text(lines) as line 
            FROM stops 
            WHERE lines IS NOT NULL AND jsonb_typeof(lines) = 'array'
        `);

        res.json({
            totalStops: parseInt(stopsCount.rows[0].count),
            totalRoutes: routesResult.rows.length,
            activeUsers: parseInt(usersCount.rows[0].count),
            todayQueries: parseInt(todayQueries.rows[0].count),
            weeklyGrowth: 5.2, // Simulado por ahora
            avgResponseTime: parseFloat(avgResponseTime.rows[0].avg || 0).toFixed(2),
        });
    } catch (error) {
        console.error('Error al obtener estadísticas:', error);
        res.status(500).json({ error: 'Error al obtener estadísticas' });
    }
});

// 8. Obtener uso por día (últimos 7 días)
app.get('/api/stats/usage', async (req, res) => {
    try {
        const result = await pool.query(`
            SELECT 
                to_char(created_at, 'Dy') as day,
                COUNT(*) as queries
            FROM api_logs
            WHERE created_at >= CURRENT_DATE - INTERVAL '6 days'
            GROUP BY to_char(created_at, 'Dy'), DATE(created_at)
            ORDER BY DATE(created_at) ASC
        `);
        
        // Si no hay datos suficientes, rellenar con 0
        const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
        const esDays = {'Sun': 'Dom', 'Mon': 'Lun', 'Tue': 'Mar', 'Wed': 'Mie', 'Thu': 'Jue', 'Fri': 'Vie', 'Sat': 'Sab'};
        
        const usageData = result.rows.map(row => ({
            day: esDays[row.day] || row.day,
            queries: parseInt(row.queries)
        }));

        res.json(usageData.length > 0 ? usageData : [
            {'day': 'Lun', 'queries': 0},
            {'day': 'Mar', 'queries': 0},
            {'day': 'Mie', 'queries': 0},
            {'day': 'Jue', 'queries': 0},
            {'day': 'Vie', 'queries': 0},
            {'day': 'Sab', 'queries': 0},
            {'day': 'Dom', 'queries': 0},
        ]);
    } catch (error) {
        console.error('Error al obtener uso:', error);
        res.status(500).json({ error: 'Error al obtener uso' });
    }
});

// 9. Obtener actividad reciente
app.get('/api/stats/activity', async (req, res) => {
    try {
        const result = await pool.query(`
            SELECT 
                endpoint as action,
                method as user,
                to_char(created_at, 'HH24:MI:SS') as time,
                'system' as type
            FROM api_logs
            ORDER BY created_at DESC
            LIMIT 5
        `);
        
        const activity = result.rows.map(row => ({
            action: `Petición ${row.action}`,
            user: row.user,
            time: row.time,
            type: row.user === 'GET' ? 'system' : 'update'
        }));

        res.json(activity.length > 0 ? activity : [
            {'action': 'Sin actividad reciente', 'user': '-', 'time': '-', 'type': 'system'}
        ]);
    } catch (error) {
        console.error('Error al obtener actividad:', error);
        res.status(500).json({ error: 'Error al obtener actividad' });
    }
});

// Iniciar el servidor
app.listen(PORT, () => {
    console.log(`🚀 Servidor corriendo en http://localhost:${PORT}`);
});