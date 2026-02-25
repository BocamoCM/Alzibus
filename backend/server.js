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

// ==========================================
// MIDDLEWARE: VALIDACIÓN DE API KEY
// ==========================================
// Todas las rutas /api/* requieren el header X-API-Key correcto.
const validateApiKey = (req, res, next) => {
    const apiKey = req.headers['x-api-key'];
    if (!apiKey || apiKey !== process.env.API_KEY) {
        console.warn(`[API Key] Petición rechazada desde ${req.ip} — clave inválida o ausente`);
        return res.status(401).json({ error: 'API Key inválida o no proporcionada' });
    }
    next();
};

app.use('/api', validateApiKey);

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
// MIDDLEWARE: AUTENTICACIÓN JWT
// ==========================================
// Protege rutas que requieren usuario autenticado.
const authenticateToken = (req, res, next) => {
    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1]; // Bearer <token>
    if (!token) return res.status(401).json({ error: 'Token requerido' });
    jwt.verify(token, process.env.JWT_SECRET, (err, user) => {
        if (err) return res.status(403).json({ error: 'Token inválido o expirado' });
        req.user = user;
        next();
    });
};



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
        const result = await pool.query('SELECT * FROM users WHERE email = $1', [email]);
        if (result.rows.length === 0) {
            return res.status(401).json({ error: 'Credenciales inválidas' });
        }

        const user = result.rows[0];

        // Verificar que la cuenta está activa
        if (user.active === false) {
            return res.status(403).json({ error: 'Cuenta desactivada. Contacta con el administrador.' });
        }

        const validPassword = await bcrypt.compare(password, user.password_hash);
        if (!validPassword) {
            return res.status(401).json({ error: 'Credenciales inválidas' });
        }

        // Actualizar last_access (no bloqueante — puede fallar si columna aún no existe)
        pool.query('UPDATE users SET last_access = NOW() WHERE id = $1', [user.id])
            .catch(err => console.warn('[Login] No se pudo actualizar last_access:', err.message));

        const token = jwt.sign(
            { id: user.id, email: user.email },
            process.env.JWT_SECRET,
            { expiresIn: '24h' }
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
// RUTAS DE PERFIL DE USUARIO
// ==========================================

// 16. Obtener perfil del usuario + estadísticas de viajes
app.get('/api/users/profile', authenticateToken, async (req, res) => {
    try {
        const userResult = await pool.query(
            'SELECT id, email, created_at, last_access FROM users WHERE id = $1',
            [req.user.id]
        );
        if (userResult.rows.length === 0) {
            return res.status(404).json({ error: 'Usuario no encontrado' });
        }
        const user = userResult.rows[0];

        // Stats de viajes
        const totalTrips = await pool.query('SELECT COUNT(*) FROM trips WHERE user_id = $1', [req.user.id]);
        const lineUsage = await pool.query(
            `SELECT line, COUNT(*) as count FROM trips WHERE user_id = $1 GROUP BY line ORDER BY count DESC LIMIT 1`,
            [req.user.id]
        );
        const thisMonthTrips = await pool.query(
            `SELECT COUNT(*) FROM trips WHERE user_id = $1 AND timestamp >= date_trunc('month', NOW())`,
            [req.user.id]
        );

        res.json({
            id: user.id,
            email: user.email,
            createdAt: user.created_at,
            lastAccess: user.last_access,
            stats: {
                totalTrips: parseInt(totalTrips.rows[0].count),
                mostUsedLine: lineUsage.rows[0]?.line || null,
                thisMonthTrips: parseInt(thisMonthTrips.rows[0].count),
            }
        });
    } catch (error) {
        console.error('Error en perfil:', error);
        res.status(500).json({ error: 'Error interno del servidor' });
    }
});

// 17. Actualizar email del usuario
app.put('/api/users/profile', authenticateToken, async (req, res) => {
    const { email } = req.body;
    if (!email) return res.status(400).json({ error: 'Email requerido' });
    try {
        const exists = await pool.query('SELECT id FROM users WHERE email = $1 AND id != $2', [email, req.user.id]);
        if (exists.rows.length > 0) return res.status(400).json({ error: 'El email ya está en uso' });
        await pool.query('UPDATE users SET email = $1 WHERE id = $2', [email, req.user.id]);
        res.json({ message: 'Email actualizado' });
    } catch (error) {
        console.error('Error actualizando email:', error);
        res.status(500).json({ error: 'Error interno del servidor' });
    }
});

// 18. Cambiar contraseña del usuario
app.put('/api/users/password', authenticateToken, async (req, res) => {
    const { currentPassword, newPassword } = req.body;
    if (!currentPassword || !newPassword) {
        return res.status(400).json({ error: 'Contraseñas requeridas' });
    }
    if (newPassword.length < 6) {
        return res.status(400).json({ error: 'La contraseña debe tener al menos 6 caracteres' });
    }
    try {
        const result = await pool.query('SELECT password_hash FROM users WHERE id = $1', [req.user.id]);
        const user = result.rows[0];
        const valid = await bcrypt.compare(currentPassword, user.password_hash);
        if (!valid) return res.status(401).json({ error: 'Contraseña actual incorrecta' });
        const newHash = await bcrypt.hash(newPassword, 10);
        await pool.query('UPDATE users SET password_hash = $1 WHERE id = $2', [newHash, req.user.id]);
        res.json({ message: 'Contraseña actualizada' });
    } catch (error) {
        console.error('Error cambiando contraseña:', error);
        res.status(500).json({ error: 'Error interno del servidor' });
    }
});

// ==========================================
// RUTAS DE ADMINISTRACIÓN DE USUARIOS
// ==========================================

// 19. Listar todos los usuarios (solo admin — protegido por API key)
app.get('/api/admin/users', async (req, res) => {
    try {
        const result = await pool.query(`
            SELECT
                u.id, u.email, u.active, u.created_at, u.last_access,
                COUNT(t.id)::int AS trip_count
            FROM users u
            LEFT JOIN trips t ON t.user_id = u.id
            GROUP BY u.id
            ORDER BY u.created_at DESC
        `);
        res.json(result.rows);
    } catch (error) {
        console.error('Error listando usuarios:', error);
        res.status(500).json({ error: 'Error interno del servidor' });
    }
});

// 20. Activar/desactivar usuario (solo admin)
app.patch('/api/admin/users/:id/toggle', async (req, res) => {
    const { id } = req.params;
    try {
        const result = await pool.query(
            'UPDATE users SET active = NOT active WHERE id = $1 RETURNING id, email, active',
            [id]
        );
        if (result.rows.length === 0) return res.status(404).json({ error: 'Usuario no encontrado' });
        res.json(result.rows[0]);
    } catch (error) {
        console.error('Error toggling usuario:', error);
        res.status(500).json({ error: 'Error interno del servidor' });
    }
});

// ==========================================
// RUTAS DE AVISOS / INCIDENCIAS
// ==========================================

// 21. Obtener avisos activos (público)
app.get('/api/notices', async (req, res) => {
    try {
        const result = await pool.query(`
            SELECT id, title, body, line, active, expires_at, created_at
            FROM notices
            WHERE active = TRUE
              AND (expires_at IS NULL OR expires_at > NOW())
            ORDER BY created_at DESC
        `);
        res.json(result.rows);
    } catch (error) {
        console.error('Error obteniendo avisos:', error);
        res.status(500).json({ error: 'Error interno del servidor' });
    }
});

// 22. Obtener TODOS los avisos (admin)
app.get('/api/admin/notices', async (req, res) => {
    try {
        const result = await pool.query(
            'SELECT * FROM notices ORDER BY created_at DESC'
        );
        res.json(result.rows);
    } catch (error) {
        console.error('Error obteniendo avisos admin:', error);
        res.status(500).json({ error: 'Error interno del servidor' });
    }
});

// 23. Crear aviso
app.post('/api/admin/notices', async (req, res) => {
    const { title, body, line, expiresAt } = req.body;
    if (!title || !body) return res.status(400).json({ error: 'Título y cuerpo requeridos' });
    try {
        const result = await pool.query(
            'INSERT INTO notices (title, body, line, expires_at) VALUES ($1, $2, $3, $4) RETURNING *',
            [title, body, line || null, expiresAt || null]
        );
        res.status(201).json(result.rows[0]);
    } catch (error) {
        console.error('Error creando aviso:', error);
        res.status(500).json({ error: 'Error interno del servidor' });
    }
});

// 24. Activar/desactivar aviso
app.patch('/api/admin/notices/:id/toggle', async (req, res) => {
    const { id } = req.params;
    try {
        const result = await pool.query(
            'UPDATE notices SET active = NOT active WHERE id = $1 RETURNING *',
            [id]
        );
        if (result.rows.length === 0) return res.status(404).json({ error: 'Aviso no encontrado' });
        res.json(result.rows[0]);
    } catch (error) {
        console.error('Error toggling aviso:', error);
        res.status(500).json({ error: 'Error interno del servidor' });
    }
});

// 25. Eliminar aviso
app.delete('/api/admin/notices/:id', async (req, res) => {
    const { id } = req.params;
    try {
        const result = await pool.query('DELETE FROM notices WHERE id = $1 RETURNING id', [id]);
        if (result.rows.length === 0) return res.status(404).json({ error: 'Aviso no encontrado' });
        res.json({ message: 'Aviso eliminado' });
    } catch (error) {
        console.error('Error eliminando aviso:', error);
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

        // Calcular crecimiento semanal REAL comparando esta semana vs la anterior
        const thisWeek = await pool.query(
            `SELECT COUNT(*) FROM api_logs WHERE created_at >= CURRENT_DATE - INTERVAL '6 days'`
        );
        const lastWeek = await pool.query(
            `SELECT COUNT(*) FROM api_logs WHERE created_at >= CURRENT_DATE - INTERVAL '13 days' AND created_at < CURRENT_DATE - INTERVAL '6 days'`
        );
        const thisWeekCount = parseInt(thisWeek.rows[0].count);
        const lastWeekCount = parseInt(lastWeek.rows[0].count);
        const weeklyGrowth = lastWeekCount > 0
            ? parseFloat(((thisWeekCount - lastWeekCount) / lastWeekCount * 100).toFixed(1))
            : 0;

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
            weeklyGrowth,
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
        const esDays = { 'Sun': 'Dom', 'Mon': 'Lun', 'Tue': 'Mar', 'Wed': 'Mie', 'Thu': 'Jue', 'Fri': 'Vie', 'Sat': 'Sab' };

        const usageData = result.rows.map(row => ({
            day: esDays[row.day] || row.day,
            queries: parseInt(row.queries)
        }));

        res.json(usageData.length > 0 ? usageData : [
            { 'day': 'Lun', 'queries': 0 },
            { 'day': 'Mar', 'queries': 0 },
            { 'day': 'Mie', 'queries': 0 },
            { 'day': 'Jue', 'queries': 0 },
            { 'day': 'Vie', 'queries': 0 },
            { 'day': 'Sab', 'queries': 0 },
            { 'day': 'Dom', 'queries': 0 },
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
            { 'action': 'Sin actividad reciente', 'user': '-', 'time': '-', 'type': 'system' }
        ]);
    } catch (error) {
        console.error('Error al obtener actividad:', error);
        res.status(500).json({ error: 'Error al obtener actividad' });
    }
});

// 10. Paradas más visitadas (desde trips — cada viaje confirmado cuenta como visita)
app.get('/api/stats/top-stops', async (req, res) => {
    try {
        const result = await pool.query(`
            SELECT
                stop_id   AS "stopId",
                stop_name AS name,
                COUNT(*)  AS visits
            FROM trips
            GROUP BY stop_id, stop_name
            ORDER BY visits DESC
            LIMIT 10
        `);

        if (result.rows.length === 0) {
            // Sin viajes aún, devolver paradas existentes con 0 visitas
            const stops = await pool.query('SELECT id, name FROM stops ORDER BY id ASC LIMIT 10');
            return res.json(stops.rows.map(s => ({ stopId: s.id, name: s.name, visits: 0 })));
        }

        res.json(result.rows.map(r => ({
            stopId: parseInt(r.stopId),
            name: r.name,
            visits: parseInt(r.visits),
        })));
    } catch (error) {
        console.error('Error top-stops:', error);
        res.status(500).json({ error: 'Error al obtener paradas más visitadas' });
    }
});


// 11. Horas pico (desde api_logs, agrupado por hora)
app.get('/api/stats/peak-hours', async (req, res) => {
    try {
        const result = await pool.query(`
            SELECT
                EXTRACT(HOUR FROM created_at)::int AS hour,
                COUNT(*) AS requests
            FROM api_logs
            WHERE created_at >= NOW() - INTERVAL '30 days'
            GROUP BY hour
            ORDER BY hour ASC
        `);

        if (result.rows.length === 0) {
            return res.json([]);
        }

        const maxRequests = Math.max(...result.rows.map(r => parseInt(r.requests)));

        const peaks = result.rows.map(row => {
            const h = parseInt(row.hour);
            const count = parseInt(row.requests);
            const level = maxRequests > 0 ? count / maxRequests : 0;
            let label;
            if (level >= 0.85) label = 'Pico';
            else if (level >= 0.6) label = 'Alto';
            else if (level >= 0.35) label = 'Medio';
            else label = 'Bajo';

            return {
                hour: `${String(h).padStart(2, '0')}:00`,
                requests: count,
                level: parseFloat(level.toFixed(2)),
                label,
            };
        });

        res.json(peaks);
    } catch (error) {
        console.error('Error peak-hours:', error);
        res.status(500).json({ error: 'Error al obtener horas pico' });
    }
});

// ==========================================
// RUTAS DE HISTORIAL DE VIAJES
// ==========================================
// Todas protegidas por JWT (el usuario solo ve sus propios viajes)

// 12. Obtener historial de viajes del usuario
app.get('/api/trips', authenticateToken, async (req, res) => {
    try {
        const result = await pool.query(
            `SELECT id, line, destination, stop_name AS "stopName", stop_id AS "stopId",
             timestamp, confirmed
             FROM trips
             WHERE user_id = $1
             ORDER BY timestamp DESC`,
            [req.user.id]
        );
        res.json(result.rows);
    } catch (error) {
        console.error('Error al obtener viajes:', error);
        res.status(500).json({ error: 'Error al obtener el historial' });
    }
});

// 13. Guardar un nuevo viaje
app.post('/api/trips', authenticateToken, async (req, res) => {
    const { line, destination, stopName, stopId, timestamp, confirmed } = req.body;
    if (!line || !destination || !stopName || stopId === undefined || !timestamp) {
        return res.status(400).json({ error: 'Datos del viaje incompletos' });
    }
    try {
        const result = await pool.query(
            `INSERT INTO trips (user_id, line, destination, stop_name, stop_id, timestamp, confirmed)
             VALUES ($1, $2, $3, $4, $5, $6, $7)
             RETURNING id, line, destination, stop_name AS "stopName", stop_id AS "stopId", timestamp, confirmed`,
            [req.user.id, line, destination, stopName, stopId, timestamp, confirmed ?? false]
        );
        res.status(201).json(result.rows[0]);
    } catch (error) {
        console.error('Error al guardar viaje:', error);
        res.status(500).json({ error: 'Error al guardar el viaje' });
    }
});

// 14. Eliminar un viaje por ID
app.delete('/api/trips/:id', authenticateToken, async (req, res) => {
    const { id } = req.params;
    try {
        const result = await pool.query(
            'DELETE FROM trips WHERE id = $1 AND user_id = $2 RETURNING id',
            [id, req.user.id]
        );
        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Viaje no encontrado' });
        }
        res.json({ message: 'Viaje eliminado' });
    } catch (error) {
        console.error('Error al eliminar viaje:', error);
        res.status(500).json({ error: 'Error al eliminar el viaje' });
    }
});

// 15. Borrar todo el historial del usuario
app.delete('/api/trips', authenticateToken, async (req, res) => {
    try {
        await pool.query('DELETE FROM trips WHERE user_id = $1', [req.user.id]);
        res.json({ message: 'Historial borrado' });
    } catch (error) {
        console.error('Error al borrar historial:', error);
        res.status(500).json({ error: 'Error al borrar el historial' });
    }
});

// Iniciar el servidor
app.listen(PORT, () => {
    console.log(`🚀 Servidor corriendo en http://localhost:${PORT}`);
});
