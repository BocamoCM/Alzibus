// ==========================================
// src/controllers/live-trip.controller.js
// ==========================================
const liveTripService = require('../services/live-trip.service');

/**
 * Devuelve la URL base externa a partir de la request. Tras Caddy/reverse
 * proxy, host viene en el header. Si no, fallback al .env.
 */
function buildHostBaseUrl(req) {
    const proto = req.headers['x-forwarded-proto'] || req.protocol || 'https';
    const host = req.headers['x-forwarded-host'] || req.headers.host;
    if (host) return `${proto}://${host}`;
    return process.env.PUBLIC_BASE_URL || 'https://alzitrans.es';
}

class LiveTripController {
    async start(req, res, next) {
        try {
            const trip = await liveTripService.start(req.user.id, req.body, buildHostBaseUrl(req));
            res.status(201).json(trip);
        } catch (err) { next(err); }
    }

    async ping(req, res, next) {
        try {
            // Pasamos hostBaseUrl para que la respuesta incluya shareUrl —
            // así la UI puede preservar el link entre pings sin tener que
            // construirlo a mano ni cachearlo aparte.
            const trip = await liveTripService.ping(
                req.params.id,
                req.user.id,
                req.body,
                buildHostBaseUrl(req),
            );
            res.json(trip);
        } catch (err) { next(err); }
    }

    async end(req, res, next) {
        try {
            const trip = await liveTripService.end(req.params.id, req.user.id);
            res.json(trip);
        } catch (err) { next(err); }
    }

    async getMyActive(req, res, next) {
        try {
            const trip = await liveTripService.getMyActive(req.user.id, buildHostBaseUrl(req));
            res.json({ trip }); // {trip: null} si no hay activo
        } catch (err) { next(err); }
    }

    async getHistory(req, res, next) {
        try {
            const limit = parseInt(req.query.limit, 10) || 50;
            const offset = parseInt(req.query.offset, 10) || 0;
            const trips = await liveTripService.getHistory(req.user.id, { limit, offset });
            res.json({ trips, limit, offset });
        } catch (err) { next(err); }
    }

    async getPublic(req, res, next) {
        try {
            const trip = await liveTripService.getPublic(req.params.shareToken);
            // Cache muy corta — los clientes hacen polling, no queremos CDN
            // caching, pero está bien dejar 5s para no martillar la BD si
            // un viewer popular abre el link en varias pestañas.
            res.set('Cache-Control', 'public, max-age=5');
            res.json(trip);
        } catch (err) { next(err); }
    }
}

module.exports = new LiveTripController();
