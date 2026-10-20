const pool = require('../../db');

// Mapa cerrado de periodos → literal INTERVAL válido en PostgreSQL.
// PostgreSQL NO acepta INTERVAL parametrizado vía $1 con el placeholder,
// así que sustituimos por interpolación PERO desde una whitelist hardcoded.
// Si `period` no está en el mapa devolvemos el default ('7 days') —
// nunca un valor proveniente del request del usuario llega al SQL.
const INTERVAL_MAP = Object.freeze({
    day:   '24 hours',
    week:  '7 days',
    month: '30 days',
    year:  '365 days',
});
function resolveInterval(period) {
    return INTERVAL_MAP[period] || INTERVAL_MAP.week;
}

class StatRepository {
    async getGeneralStats() {
        const stopsCount = await pool.query('SELECT COUNT(*) FROM stops');
        const usersCount = await pool.query('SELECT COUNT(*) FROM users');
        const todayQueries = await pool.query('SELECT COUNT(*) FROM api_logs WHERE created_at >= CURRENT_DATE');
        const avgResponseTime = await pool.query('SELECT AVG(duration_ms) FROM api_logs');

        const thisWeek = await pool.query(`SELECT COUNT(*) FROM api_logs WHERE created_at >= CURRENT_DATE - INTERVAL '6 days'`);
        const lastWeek = await pool.query(`SELECT COUNT(*) FROM api_logs WHERE created_at >= CURRENT_DATE - INTERVAL '13 days' AND created_at < CURRENT_DATE - INTERVAL '6 days'`);
        const thisWeekCount = parseInt(thisWeek.rows[0].count);
        const lastWeekCount = parseInt(lastWeek.rows[0].count);
        const weeklyGrowth = lastWeekCount > 0 ? parseFloat(((thisWeekCount - lastWeekCount) / lastWeekCount * 100).toFixed(1)) : 0;

        const routesResult = await pool.query(`
            SELECT DISTINCT jsonb_array_elements_text(lines) as line 
            FROM stops 
            WHERE lines IS NOT NULL AND jsonb_typeof(lines) = 'array'
        `);

        return {
            totalStops: parseInt(stopsCount.rows[0].count),
            totalRoutes: routesResult.rows.length,
            activeUsers: parseInt(usersCount.rows[0].count),
            todayQueries: parseInt(todayQueries.rows[0].count),
            weeklyGrowth,
            avgResponseTime: parseFloat(avgResponseTime.rows[0].avg || 0).toFixed(2),
        };
    }

    async getUsageStats(period = 'week') {
        const interval = resolveInterval(period);

        const result = await pool.query(`
            SELECT DATE(created_at) as day, COUNT(*) as queries
            FROM api_logs
            WHERE created_at >= NOW() - INTERVAL '${interval}'
            GROUP BY day ORDER BY day
        `);
        return result.rows.map(r => ({
            day: r.day.toISOString().split('T')[0],
            queries: parseInt(r.queries)
        }));
    }

    async getActivityStats() {
        const result = await pool.query(`
            SELECT endpoint as action, 'System' as user, created_at as time, 'system' as type
            FROM api_logs ORDER BY created_at DESC LIMIT 10
        `);
        return result.rows;
    }

    async getTopStops() {
        const result = await pool.query(`
            SELECT stop_name as name, COUNT(*) as visits 
            FROM trips GROUP BY stop_name ORDER BY visits DESC LIMIT 10
        `);
        return result.rows.map(r => ({
            ...r,
            visits: parseInt(r.visits)
        }));
    }

    async getPeakHours() {
        const result = await pool.query(`
            SELECT EXTRACT(HOUR FROM timestamp) || 'h' as hour, 
                COUNT(*)::float / NULLIF((SELECT MAX(cnt) FROM (SELECT COUNT(*) as cnt FROM trips GROUP BY EXTRACT(HOUR FROM timestamp)) s), 0) as level,
                CASE WHEN COUNT(*) > 50 THEN 'ALTA' WHEN COUNT(*) > 20 THEN 'MEDIA' ELSE 'BAJA' END as label
            FROM trips GROUP BY hour ORDER BY hour
        `);
        return result.rows;
    }

    async getDashboard(period = 'week') {
        const interval = resolveInterval(period);

        const [
            usersTotal, usersVerified, usersThisWeek, usersActive7d, tripsTotal, tripsConfirmed,
            tripsByLine, tripsByHour, topStops, dailyRegistrations, dailyTrips, apiPerf,
            noticesTotal, noticesActive, noticesByLine, todayQueries, queries7d, queriesPrev7d,
            avgResponseTime, totalStopsResult, premiumUsersResult, qrTotalResult, qrTodayResult,
            qrByStopResult, qrByDeviceResult, usersUnverifiedResult, usersAttemptsResult,
        ] = await Promise.all([
            pool.query("SELECT COUNT(*) FROM users WHERE is_verified = TRUE"),
            pool.query("SELECT COUNT(*) FROM users WHERE is_verified = true"),
            pool.query(`SELECT COUNT(*) FROM users WHERE created_at >= NOW() - INTERVAL '${interval}'`),
            pool.query(`SELECT COUNT(DISTINCT id) FROM users WHERE last_access >= NOW() - INTERVAL '${interval}'`),
            pool.query("SELECT COUNT(*) FROM trips"),
            pool.query("SELECT COUNT(*) FROM trips WHERE confirmed = true"),
            pool.query(`SELECT line, COUNT(*) as cnt FROM trips WHERE timestamp >= NOW() - INTERVAL '${interval}' GROUP BY line ORDER BY cnt DESC`),
            pool.query(`SELECT EXTRACT(HOUR FROM timestamp) as hour, COUNT(*) as cnt FROM trips WHERE timestamp >= NOW() - INTERVAL '${interval}' GROUP BY hour ORDER BY hour`),
            pool.query(`SELECT stop_name, COUNT(*) as cnt FROM trips WHERE timestamp >= NOW() - INTERVAL '${interval}' GROUP BY stop_name ORDER BY cnt DESC LIMIT 10`),
            pool.query(`SELECT DATE(created_at) as day, COUNT(*) as cnt FROM users WHERE created_at >= NOW() - INTERVAL '30 days' GROUP BY day ORDER BY day`),
            pool.query(`SELECT DATE(timestamp) as day, COUNT(*) as cnt FROM trips WHERE timestamp >= NOW() - INTERVAL '30 days' GROUP BY day ORDER BY day`),
            pool.query(`SELECT endpoint, ROUND(AVG(duration_ms)) as avg_ms, COUNT(*) as calls, ROUND(MAX(duration_ms)) as max_ms FROM api_logs WHERE created_at >= NOW() - INTERVAL '${interval}' GROUP BY endpoint ORDER BY calls DESC LIMIT 10`),
            pool.query("SELECT COUNT(*) FROM notices"),
            pool.query("SELECT COUNT(*) FROM notices WHERE active = true AND (expires_at IS NULL OR expires_at > NOW())"),
            pool.query("SELECT COALESCE(line, 'General') as line, COUNT(*) as cnt FROM notices GROUP BY line ORDER BY cnt DESC"),
            pool.query(`SELECT COUNT(*) FROM api_logs WHERE created_at >= NOW() - INTERVAL '${interval}'`),
            pool.query(`SELECT COUNT(*) FROM api_logs WHERE created_at >= NOW() - INTERVAL '${interval}'`),
            pool.query(`SELECT COUNT(*) FROM api_logs WHERE created_at < NOW() - INTERVAL '${interval}' AND created_at >= NOW() - INTERVAL '14 days'`),
            pool.query(`SELECT AVG(duration_ms) FROM api_logs WHERE created_at >= NOW() - INTERVAL '${interval}'`),
            pool.query("SELECT COUNT(*) FROM stops"),
            pool.query("SELECT COUNT(*) FROM users WHERE is_premium = TRUE"),
            pool.query("SELECT COUNT(*) AS count FROM qr_scans"),
            pool.query(`SELECT COUNT(*) AS count FROM qr_scans WHERE created_at >= NOW() - INTERVAL '${interval}'`),
            pool.query(`SELECT stop_name as name, COUNT(*) as cnt FROM qr_scans WHERE stop_name IS NOT NULL AND created_at >= NOW() - INTERVAL '${interval}' GROUP BY stop_name ORDER BY cnt DESC LIMIT 10`),
            pool.query(`SELECT device, COUNT(*) as cnt FROM qr_scans WHERE created_at >= NOW() - INTERVAL '${interval}' GROUP BY device ORDER BY cnt DESC`),
            pool.query(`SELECT COUNT(*) FROM users WHERE is_verified = FALSE AND created_at >= NOW() - INTERVAL '${interval}'`),
            pool.query(`SELECT COUNT(*) FROM users WHERE created_at >= NOW() - INTERVAL '${interval}'`),
        ]);

        const cur7 = parseInt(queries7d.rows[0].count);
        const prev7 = parseInt(queriesPrev7d.rows[0].count);
        const growth = prev7 > 0 ? ((cur7 - prev7) / prev7) * 100 : 0;

        return {
            todayQueries: parseInt(todayQueries.rows[0].count),
            weeklyGrowth: parseFloat(growth.toFixed(1)),
            avgResponseTime: Math.round(parseFloat(avgResponseTime.rows[0].avg || 0)),
            activeUsers: parseInt(usersActive7d.rows[0].count),
            totalStops: parseInt(totalStopsResult.rows[0].count || 0),
            premiumUsers: parseInt(premiumUsersResult.rows[0].count || 0),
            totalRevenue: (parseInt(premiumUsersResult.rows[0].count || 0) * 2.99).toFixed(2),
            users: {
                total: parseInt(usersTotal.rows[0].count), verified: parseInt(usersVerified.rows[0].count),
                thisWeek: parseInt(usersThisWeek.rows[0].count), active7d: parseInt(usersActive7d.rows[0].count),
                verificationRate: usersTotal.rows[0].count > 0 ? Math.round((usersVerified.rows[0].count / usersTotal.rows[0].count) * 100) : 0,
            },
            trips: {
                total: parseInt(tripsTotal.rows[0].count), confirmed: parseInt(tripsConfirmed.rows[0].count),
                confirmationRate: tripsTotal.rows[0].count > 0 ? Math.round((tripsConfirmed.rows[0].count / tripsTotal.rows[0].count) * 100) : 0,
                byLine: tripsByLine.rows.map(r => ({ ...r, cnt: parseInt(r.cnt) })),
                byHour: tripsByHour.rows.map(r => ({ ...r, cnt: parseInt(r.cnt) })),
                topStops: topStops.rows.map(r => ({ ...r, cnt: parseInt(r.cnt) })),
                dailyTrips: dailyTrips.rows.map(r => ({ ...r, cnt: parseInt(r.cnt), day: r.day })),
            },
            users_daily: dailyRegistrations.rows.map(r => ({ ...r, cnt: parseInt(r.cnt), day: r.day })),
            api: { endpoints: apiPerf.rows.map(r => ({ ...r, avg_ms: parseInt(r.avg_ms), calls: parseInt(r.calls), max_ms: parseInt(r.max_ms) })), totalQueries7d: cur7 },
            notices: { total: parseInt(noticesTotal.rows[0].count), active: parseInt(noticesActive.rows[0].count), byLine: noticesByLine.rows.map(r => ({ ...r, cnt: parseInt(r.cnt) })) },
        };
    }

    async getPublicStats() {
        const result = await pool.query("SELECT COUNT(*) FROM users");
        return { totalUsers: parseInt(result.rows[0].count) };
    }

    async logWebMetric(ip, userAgent, type, source, platform, browser, appVersion = null) {
        await pool.query(
            `INSERT INTO web_metrics (event_type, ip, user_agent, source, platform, browser, app_version)
             VALUES ($1, $2, $3, $4, $5, $6, $7)`,
            [type, ip, userAgent, source, platform, browser, appVersion]
        );
    }

    // ── Adopción de versiones de la app (quién actualiza y quién no) ──
    async getVersionAdoption(period = 'month') {
        const interval = resolveInterval(period);
        const res = await pool.query(`
            SELECT COALESCE(NULLIF(app_version, ''), 'desconocida') AS version,
                   COUNT(DISTINCT ip)::int AS devices,
                   COUNT(*)::int           AS events
            FROM web_metrics
            WHERE source = 'mobile_app' AND created_at >= NOW() - INTERVAL '${interval}'
            GROUP BY version
            ORDER BY devices DESC`);
        return { versions: res.rows };
    }

    /**
     * Devuelve la matriz `source × platform` para el dashboard.
     * Cuenta tanto eventos totales como IPs únicas en el último periodo.
     */
    async getTelemetryBreakdown(period = 'week') {
        const interval = resolveInterval(period);

        const byPlatformSource = await pool.query(`
            SELECT
              COALESCE(source, 'unknown')   AS source,
              COALESCE(platform, 'unknown') AS platform,
              COUNT(*)::int                 AS visits,
              COUNT(DISTINCT ip)::int       AS uniques
            FROM web_metrics
            WHERE event_type IN ('visit', 'app_open', 'login')
              AND created_at >= NOW() - INTERVAL '${interval}'
            GROUP BY source, platform
            ORDER BY visits DESC
        `);

        const byBrowser = await pool.query(`
            SELECT COALESCE(browser, 'unknown') AS browser, COUNT(*)::int AS visits
            FROM web_metrics
            WHERE event_type IN ('visit', 'app_open', 'login')
              AND created_at >= NOW() - INTERVAL '${interval}'
              AND source IN ('landing', 'web_app')
            GROUP BY browser
            ORDER BY visits DESC
        `);

        const totals = await pool.query(`
            SELECT
              COALESCE(source, 'unknown') AS source,
              COUNT(*)::int               AS visits,
              COUNT(DISTINCT ip)::int     AS uniques
            FROM web_metrics
            WHERE event_type IN ('visit', 'app_open', 'login')
              AND created_at >= NOW() - INTERVAL '${interval}'
            GROUP BY source
            ORDER BY visits DESC
        `);

        return {
            byPlatformSource: byPlatformSource.rows,
            byBrowser: byBrowser.rows,
            bySource: totals.rows,
        };
    }

    // ── Retención: DAU / WAU / MAU + serie diaria + nuevos vs recurrentes ──
    async getRetention() {
        const [dau, wau, mau, verified, series, newVsReturn] = await Promise.all([
            pool.query("SELECT COUNT(DISTINCT id)::int AS c FROM users WHERE last_access >= NOW() - INTERVAL '1 day'"),
            pool.query("SELECT COUNT(DISTINCT id)::int AS c FROM users WHERE last_access >= NOW() - INTERVAL '7 days'"),
            pool.query("SELECT COUNT(DISTINCT id)::int AS c FROM users WHERE last_access >= NOW() - INTERVAL '30 days'"),
            pool.query("SELECT COUNT(*)::int AS c FROM users WHERE is_verified = true"),
            pool.query(`SELECT DATE(last_access) AS day, COUNT(DISTINCT id)::int AS active
                        FROM users WHERE last_access >= NOW() - INTERVAL '30 days'
                        GROUP BY day ORDER BY day`),
            pool.query(`SELECT
                          COUNT(*) FILTER (WHERE created_at::date = CURRENT_DATE)::int AS new_today,
                          COUNT(*) FILTER (WHERE last_access::date = CURRENT_DATE AND created_at::date < CURRENT_DATE)::int AS returning_today
                        FROM users`),
        ]);
        const dauN = dau.rows[0].c, mauN = mau.rows[0].c;
        return {
            dau: dauN, wau: wau.rows[0].c, mau: mauN,
            stickiness: mauN > 0 ? +(dauN / mauN * 100).toFixed(1) : 0,
            verifiedUsers: verified.rows[0].c,
            dailyActive: series.rows,
            newToday: newVsReturn.rows[0].new_today,
            returningToday: newVsReturn.rows[0].returning_today,
        };
    }

    // ── Mapa de calor: viajes por día de la semana (0=domingo) × hora ──
    async getTripHeatmap(period = 'month') {
        const interval = resolveInterval(period);
        const res = await pool.query(`
            SELECT EXTRACT(DOW FROM timestamp)::int AS dow,
                   EXTRACT(HOUR FROM timestamp)::int AS hour,
                   COUNT(*)::int AS cnt
            FROM trips WHERE timestamp >= NOW() - INTERVAL '${interval}'
            GROUP BY dow, hour`);
        return { cells: res.rows };
    }

    // ── Método de pago de los viajes ──
    async getPaymentSplit(period = 'month') {
        const interval = resolveInterval(period);
        const res = await pool.query(`
            SELECT COALESCE(NULLIF(payment_method, ''), 'desconocido') AS method, COUNT(*)::int AS cnt
            FROM trips WHERE timestamp >= NOW() - INTERVAL '${interval}'
            GROUP BY method ORDER BY cnt DESC`);
        return { methods: res.rows };
    }

    // ── Rutas: destinos top + pares origen→destino ──
    async getRoutes(period = 'month') {
        const interval = resolveInterval(period);
        const [destinations, pairs] = await Promise.all([
            pool.query(`SELECT destination, COUNT(*)::int AS cnt FROM trips
                        WHERE timestamp >= NOW() - INTERVAL '${interval}' AND destination <> ''
                        GROUP BY destination ORDER BY cnt DESC LIMIT 10`),
            pool.query(`SELECT stop_name AS origin, destination, line, COUNT(*)::int AS cnt FROM trips
                        WHERE timestamp >= NOW() - INTERVAL '${interval}'
                        GROUP BY stop_name, destination, line ORDER BY cnt DESC LIMIT 15`),
        ]);
        return { topDestinations: destinations.rows, topRoutes: pairs.rows };
    }

    // ── Premium ──
    async getPremiumStats() {
        const [total, verified, premium] = await Promise.all([
            pool.query("SELECT COUNT(*)::int AS c FROM users"),
            pool.query("SELECT COUNT(*)::int AS c FROM users WHERE is_verified = true"),
            pool.query("SELECT COUNT(*)::int AS c FROM users WHERE is_premium = true"),
        ]);
        const v = verified.rows[0].c, p = premium.rows[0].c;
        return {
            totalUsers: total.rows[0].c,
            verifiedUsers: v,
            premiumUsers: p,
            premiumRate: v > 0 ? +(p / v * 100).toFixed(1) : 0,
        };
    }

    // ── Gamificación (Albus): monedas y skins ──
    async getGameStats() {
        const [buckets, withCoins, topSkins, avgCoins] = await Promise.all([
            pool.query(`SELECT CASE
                          WHEN game_coins = 0 THEN '0'
                          WHEN game_coins < 50 THEN '1-49'
                          WHEN game_coins < 200 THEN '50-199'
                          WHEN game_coins < 500 THEN '200-499'
                          ELSE '500+' END AS bucket,
                          COUNT(*)::int AS cnt
                        FROM users GROUP BY bucket`),
            pool.query("SELECT COUNT(*)::int AS c FROM users WHERE game_coins > 0"),
            pool.query(`SELECT skin, COUNT(*)::int AS cnt FROM (
                          SELECT TRIM(UNNEST(string_to_array(owned_skins, ','))) AS skin FROM users
                        ) s WHERE skin <> '' GROUP BY skin ORDER BY cnt DESC LIMIT 10`),
            pool.query("SELECT COALESCE(ROUND(AVG(game_coins)),0)::int AS avg FROM users WHERE game_coins > 0"),
        ]);
        return {
            coinBuckets: buckets.rows,
            usersWithCoins: withCoins.rows[0].c,
            topSkins: topSkins.rows,
            avgCoinsAmongPlayers: avgCoins.rows[0].avg,
        };
    }

    // ── Compartir viaje en vivo + precisión del ETA del planificador ──
    async getLiveShareStats(period = 'month') {
        const interval = resolveInterval(period);
        const [counts, adoption, duration, eta] = await Promise.all([
            pool.query(`SELECT COUNT(*)::int AS total,
                          COUNT(*) FILTER (WHERE status='active')::int AS active
                        FROM live_trips WHERE started_at >= NOW() - INTERVAL '${interval}'`),
            pool.query(`SELECT COUNT(DISTINCT user_id)::int AS sharers FROM live_trips
                        WHERE started_at >= NOW() - INTERVAL '${interval}'`),
            pool.query(`SELECT ROUND(AVG(EXTRACT(EPOCH FROM (ended_at - started_at))/60))::int AS avg_min
                        FROM live_trips WHERE status='ended' AND ended_at IS NOT NULL
                          AND started_at >= NOW() - INTERVAL '${interval}'`),
            pool.query(`SELECT ROUND(AVG(ABS(initial_eta_min - EXTRACT(EPOCH FROM (ended_at - started_at))/60)))::int AS avg_err_min,
                          COUNT(*)::int AS samples
                        FROM live_trips WHERE status='ended' AND ended_at IS NOT NULL AND initial_eta_min IS NOT NULL
                          AND started_at >= NOW() - INTERVAL '${interval}'`),
        ]);
        return {
            total: counts.rows[0].total,
            active: counts.rows[0].active,
            uniqueSharers: adoption.rows[0].sharers,
            avgDurationMin: duration.rows[0].avg_min,
            etaAvgErrorMin: eta.rows[0].avg_err_min,
            etaSamples: eta.rows[0].samples,
        };
    }

    // ── Soporte (feedback): volumen, tags y tiempo de primera respuesta ──
    async getSupportStats(period = 'month') {
        const interval = resolveInterval(period);
        const [counts, byTag, firstResp] = await Promise.all([
            pool.query(`SELECT COUNT(*)::int AS total,
                          COUNT(*) FILTER (WHERE status='open')::int AS open,
                          COUNT(*) FILTER (WHERE status<>'open')::int AS closed
                        FROM feedback_tickets WHERE created_at >= NOW() - INTERVAL '${interval}'`),
            pool.query(`SELECT tag, COUNT(*)::int AS cnt FROM feedback_tickets
                        WHERE created_at >= NOW() - INTERVAL '${interval}'
                        GROUP BY tag ORDER BY cnt DESC`),
            pool.query(`SELECT ROUND(AVG(EXTRACT(EPOCH FROM (fr.first_admin - t.created_at))/3600)::numeric, 1) AS avg_hours
                        FROM feedback_tickets t
                        JOIN LATERAL (SELECT MIN(created_at) AS first_admin FROM feedback_replies r
                                      WHERE r.ticket_id = t.id AND r.sender_type = 'admin') fr ON true
                        WHERE t.created_at >= NOW() - INTERVAL '${interval}' AND fr.first_admin IS NOT NULL`),
        ]);
        return {
            total: counts.rows[0].total,
            open: counts.rows[0].open,
            closed: counts.rows[0].closed,
            byTag: byTag.rows,
            avgFirstResponseHours: firstResp.rows[0] ? firstResp.rows[0].avg_hours : null,
        };
    }

    // ── Métricas de la APP WEB (alzitrans.es/app) y comparativa de plataformas ──
    async getWebAppStats(period = 'month') {
        const interval = resolveInterval(period);
        const [opensByDay, byPlatform, byBrowser, uniques] = await Promise.all([
            pool.query(`SELECT DATE(created_at) AS day, COUNT(*)::int AS opens
                        FROM web_metrics
                        WHERE event_type IN ('app_open','visit','login') AND source = 'web_app'
                          AND created_at >= NOW() - INTERVAL '${interval}'
                        GROUP BY day ORDER BY day`),
            pool.query(`SELECT COALESCE(platform,'unknown') AS platform, COUNT(*)::int AS cnt, COUNT(DISTINCT ip)::int AS uniques
                        FROM web_metrics
                        WHERE event_type IN ('app_open','visit','login')
                          AND created_at >= NOW() - INTERVAL '${interval}'
                        GROUP BY platform ORDER BY cnt DESC`),
            pool.query(`SELECT COALESCE(browser,'unknown') AS browser, COUNT(*)::int AS cnt
                        FROM web_metrics
                        WHERE source = 'web_app' AND created_at >= NOW() - INTERVAL '${interval}'
                        GROUP BY browser ORDER BY cnt DESC`),
            pool.query(`SELECT COUNT(DISTINCT ip)::int AS uniques, COUNT(*)::int AS total
                        FROM web_metrics WHERE source = 'web_app'
                          AND created_at >= NOW() - INTERVAL '${interval}'`),
        ]);
        return {
            opensByDay: opensByDay.rows,
            byPlatform: byPlatform.rows,
            byBrowser: byBrowser.rows,
            uniqueVisitors: uniques.rows[0].uniques,
            totalEvents: uniques.rows[0].total,
        };
    }
}

module.exports = new StatRepository();
