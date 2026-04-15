const pool = require('../../db');

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
        let interval = "7 days";
        if (period === 'day') interval = "24 hours";
        else if (period === 'month') interval = "30 days";
        else if (period === 'year') interval = "365 days";

        const result = await pool.query(`
            SELECT DATE(created_at) as day, COUNT(*) as queries 
            FROM api_logs 
            WHERE created_at >= NOW() - INTERVAL '${interval}'
            GROUP BY day ORDER BY day
        `);
        return result.rows;
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
        return result.rows;
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
        let interval = "7 days";
        if (period === 'day') interval = "24 hours";
        else if (period === 'month') interval = "30 days";
        else if (period === 'year') interval = "365 days";

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

    async logWebMetric(ip, userAgent, type) {
        await pool.query("INSERT INTO web_metrics (event_type, ip, user_agent) VALUES ($1, $2, $3)", [type, ip, userAgent]);
    }
}

module.exports = new StatRepository();
