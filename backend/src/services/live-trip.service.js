// ==========================================
// src/services/live-trip.service.js
// ==========================================
// Lógica de la feature "Compartir mi viaje en vivo".
//
// Cómo funciona:
//   1) El usuario llama POST /api/live-trips/start con destino.
//   2) Recibe { id, shareToken, shareUrl }. Mientras se mueve, la app
//      hace POST /api/live-trips/:id/ping con su lat/lng cada ~30s.
//   3) El destinatario abre shareUrl = "https://alzitrans.es/v/<token>"
//      y ve la posición en un mapa público (sin login).
//   4) Al llegar o cancelar: POST /api/live-trips/:id/end.
//   5) Cron del servidor marca como `expired` los activos que pasaron
//      expires_at (default: started_at + 6h).

const crypto = require('crypto');
const liveTripRepository = require('../repositories/live-trip.repository');
const { BadRequestError, NotFoundError, ForbiddenError } = require('../utils/errors');

// ─── Constantes de negocio ──────────────────────────────────────────────────
const TRIP_TTL_HOURS = 6;
// Caracteres URL-safe sin ambigüedad visual (no 0/O ni l/I).
const TOKEN_ALPHABET = 'abcdefghijkmnpqrstuvwxyz23456789';
const TOKEN_LEN = 12;

// Velocidad media bus en m/s usada para estimar ETA cuando no tenemos
// last_speed_mps reciente. ~22 km/h en zona urbana.
const FALLBACK_BUS_SPEED_MPS = 6.0;

class LiveTripService {
    /**
     * Inicia un viaje en vivo. Si el usuario ya tenía uno activo, lo cierra.
     * Devuelve el trip creado con el shareUrl listo para compartir.
     */
    async start(userId, data, hostBaseUrl) {
        const {
            line,
            originStopId, originStopName,
            destinationStopId, destinationStopName,
            destinationLat, destinationLng,
        } = data || {};

        // Cerramos el anterior si existe (solo permitimos 1 activo a la vez).
        const previous = await liveTripRepository.getActiveByUser(userId);
        if (previous) {
            await liveTripRepository.end(previous.id, userId);
        }

        const shareToken = this._generateShareToken();
        const expiresAt = new Date(Date.now() + TRIP_TTL_HOURS * 3600 * 1000);

        const trip = await liveTripRepository.create({
            userId, shareToken, line,
            originStopId, originStopName,
            destinationStopId, destinationStopName,
            destinationLat, destinationLng,
            expiresAt,
        });

        return {
            ...this._publicShape(trip),
            shareUrl: this._buildShareUrl(hostBaseUrl, shareToken),
        };
    }

    /**
     * Recibe un ping de posición. Solo el dueño puede ping-ear (auth).
     * Recalcula la ETA usando la distancia restante al destino.
     */
    async ping(tripId, userId, data) {
        const { lat, lng, speedMps, accuracyM } = data || {};
        if (typeof lat !== 'number' || typeof lng !== 'number') {
            throw new BadRequestError('lat/lng numéricos requeridos');
        }

        const trip = await liveTripRepository.findById(tripId);
        if (!trip) throw new NotFoundError('Viaje no encontrado');
        if (trip.user_id !== userId) throw new ForbiddenError('No es tu viaje');
        if (trip.status !== 'active') {
            throw new BadRequestError(`Viaje ya está ${trip.status}`);
        }

        const etaMin = this._estimateEtaMin(trip, lat, lng, speedMps);
        const updated = await liveTripRepository.ping(tripId, {
            lat, lng, speedMps, accuracyM, etaMin,
        });
        // null aquí significa "el trip ya no está activo" (expiró entre la
        // comprobación y el update). Tratar como NotFound para el cliente.
        if (!updated) throw new NotFoundError('El viaje ya no está activo');
        return this._publicShape(updated);
    }

    /**
     * El dueño marca el viaje como terminado.
     */
    async end(tripId, userId) {
        const ended = await liveTripRepository.end(tripId, userId);
        if (!ended) throw new NotFoundError('Viaje no encontrado o ya cerrado');
        return this._publicShape(ended);
    }

    /**
     * Endpoint público (sin auth) que devuelve la posición actual a partir
     * del shareToken. Solo expone datos NO sensibles: posición, línea,
     * destino, ETA, estado. NUNCA user_id, email ni nada que identifique
     * al usuario.
     */
    async getPublic(shareToken) {
        const trip = await liveTripRepository.findByShareToken(shareToken);
        if (!trip) throw new NotFoundError('Viaje no encontrado');

        // Si está expired pero la BD no lo ha marcado todavía, lo corregimos
        // al vuelo en la respuesta. No hace falta UPDATE — el cron lo hará.
        let status = trip.status;
        if (status === 'active' && new Date(trip.expires_at) <= new Date()) {
            status = 'expired';
        }

        return {
            shareToken: trip.share_token,
            line: trip.line,
            destinationStopName: trip.destination_stop_name,
            destinationLat: trip.destination_lat ? Number(trip.destination_lat) : null,
            destinationLng: trip.destination_lng ? Number(trip.destination_lng) : null,
            lastLat: trip.last_lat ? Number(trip.last_lat) : null,
            lastLng: trip.last_lng ? Number(trip.last_lng) : null,
            etaMin: trip.eta_min,
            lastPingAt: trip.last_ping_at,
            startedAt: trip.started_at,
            status,
        };
    }

    /**
     * Si el usuario tiene un viaje activo, devolverlo. Sirve para que la app
     * recupere su estado al reabrirse.
     */
    async getMyActive(userId, hostBaseUrl) {
        const trip = await liveTripRepository.getActiveByUser(userId);
        if (!trip) return null;
        return {
            ...this._publicShape(trip),
            shareUrl: this._buildShareUrl(hostBaseUrl, trip.share_token),
        };
    }

    // ─── Helpers ─────────────────────────────────────────────────────────────

    _generateShareToken() {
        const bytes = crypto.randomBytes(TOKEN_LEN);
        let token = '';
        for (let i = 0; i < TOKEN_LEN; i++) {
            token += TOKEN_ALPHABET[bytes[i] % TOKEN_ALPHABET.length];
        }
        return token;
    }

    _buildShareUrl(hostBaseUrl, shareToken) {
        // hostBaseUrl viene del controller como "https://alzitrans.es".
        // Patrón /v/<token> es la ruta corta — Caddy la enruta al backend.
        const base = hostBaseUrl?.replace(/\/$/, '') || 'https://alzitrans.es';
        return `${base}/v/${shareToken}`;
    }

    /**
     * Devuelve el "shape" del trip que se envía al dueño (auth). Incluye id
     * y user_id (este último porque el dueño ya lo sabe). Excluye nada
     * sensible que no se pueda exponer al dueño.
     */
    _publicShape(trip) {
        return {
            id: trip.id,
            shareToken: trip.share_token,
            line: trip.line,
            originStopId: trip.origin_stop_id,
            originStopName: trip.origin_stop_name,
            destinationStopId: trip.destination_stop_id,
            destinationStopName: trip.destination_stop_name,
            destinationLat: trip.destination_lat ? Number(trip.destination_lat) : null,
            destinationLng: trip.destination_lng ? Number(trip.destination_lng) : null,
            lastLat: trip.last_lat ? Number(trip.last_lat) : null,
            lastLng: trip.last_lng ? Number(trip.last_lng) : null,
            lastPingAt: trip.last_ping_at,
            etaMin: trip.eta_min,
            startedAt: trip.started_at,
            endedAt: trip.ended_at,
            expiresAt: trip.expires_at,
            status: trip.status,
        };
    }

    /**
     * Estima minutos hasta destino con haversine + velocidad. Si no tenemos
     * destino con coords, devolvemos null (UI lo oculta).
     */
    _estimateEtaMin(trip, lat, lng, speedMps) {
        if (!trip.destination_lat || !trip.destination_lng) return null;
        const distM = this._haversineM(
            lat, lng,
            Number(trip.destination_lat), Number(trip.destination_lng)
        );
        // Si el usuario apenas se mueve (speed < 1 m/s, parado/andando),
        // mejor usamos fallback de bus para no decir "ETA 3 horas".
        const effectiveSpeed = (speedMps && speedMps > 1.5) ? speedMps : FALLBACK_BUS_SPEED_MPS;
        const minutes = Math.ceil(distM / effectiveSpeed / 60);
        return Math.max(1, Math.min(minutes, 240)); // cap a 4h por sanidad
    }

    _haversineM(lat1, lng1, lat2, lng2) {
        const r = 6371000;
        const toRad = (d) => d * Math.PI / 180;
        const dLat = toRad(lat2 - lat1);
        const dLng = toRad(lng2 - lng1);
        const a = Math.sin(dLat / 2) ** 2 +
            Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) *
            Math.sin(dLng / 2) ** 2;
        const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
        return r * c;
    }
}

module.exports = new LiveTripService();
