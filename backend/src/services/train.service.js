// ==========================================
// src/services/train.service.js
// ==========================================
// Próximos trenes de Cercanías C2 en la estación de Alzira, con retrasos y
// cancelaciones en tiempo real.
//
// Cruza dos fuentes abiertas de Renfe:
//   - Horario programado: backend/data/renfe_c2_alzira.json, generado por
//     tools/renfe/actualizar_c2.py a partir del GTFS de Cercanías. Lista,
//     para cada fecha, los trenes que pasan por Alzira (tripId, hora, sentido).
//   - Tiempo real (GTFS-RT en JSON, sin clave):
//       https://gtfsrt.renfe.com/trip_updates.json → retraso / cancelación
//       https://gtfsrt.renfe.com/alerts.json       → avisos de la línea
//     Los tripId del feed son los mismos que los del horario, así que el cruce
//     es directo.
//
// El feed de Renfe cubre toda España; se cachea en memoria 30 s para que el
// número de visitas a la web no se traduzca en peticiones a Renfe.
const fs = require('fs');
const path = require('path');
const https = require('https');

const DATA_FILE = path.join(__dirname, '..', '..', 'data', 'renfe_c2_alzira.json');
const TRIP_UPDATES_URL = 'https://gtfsrt.renfe.com/trip_updates.json';
const ALERTS_URL = 'https://gtfsrt.renfe.com/alerts.json';
const FEED_TTL_MS = 30 * 1000;
const ALERTS_TTL_MS = 2 * 60 * 1000;
// Renfe deja avisos sin fecha de fin colgados durante semanas: sin "end",
// solo se muestran si empezaron hace menos de esto.
const ALERT_MAX_AGE_S = 12 * 60 * 60;
const MAX_PER_DIRECTION = 4;

// Rutas de la C2 del núcleo de Valencia ("40T…C2"). Otras ciudades también
// tienen una "C2" (Madrid 10T, Málaga 32T…), por eso se filtra por prefijo.
const isValenciaC2 = (routeId) => typeof routeId === 'string' && routeId.startsWith('40T') && routeId.endsWith('C2');

let _schedule = null;
let _feed = { at: 0, data: null };
let _alerts = { at: 0, data: null };

function loadSchedule() {
    if (!_schedule) _schedule = JSON.parse(fs.readFileSync(DATA_FILE, 'utf8'));
    return _schedule;
}

function getJson(url, timeoutMs = 8000) {
    return new Promise((resolve, reject) => {
        const req = https.get(url, { headers: { 'User-Agent': 'Alzitrans/1.0 (+https://alzitrans.es)' } }, (res) => {
            if (res.statusCode !== 200) {
                res.resume();
                return reject(new Error(`HTTP ${res.statusCode} en ${url}`));
            }
            let body = '';
            res.setEncoding('utf8');
            res.on('data', (c) => { body += c; });
            res.on('end', () => {
                try { resolve(JSON.parse(body)); } catch (e) { reject(e); }
            });
        });
        req.setTimeout(timeoutMs, () => req.destroy(new Error(`Timeout en ${url}`)));
        req.on('error', reject);
    });
}

async function cached(slot, url, ttl) {
    const now = Date.now();
    if (slot.data && now - slot.at < ttl) return slot.data;
    try {
        slot.data = await getJson(url);
        slot.at = now;
    } catch (err) {
        console.warn(`[Trenes] No se pudo leer ${url}: ${err.message}`);
        // Si Renfe falla, se sigue sirviendo el último dato bueno (si lo hay).
    }
    return slot.data;
}

// Fecha y minutos del día en hora de Madrid, sin depender de la zona horaria
// del contenedor.
function madridNow() {
    const parts = new Intl.DateTimeFormat('en-CA', {
        timeZone: 'Europe/Madrid', year: 'numeric', month: '2-digit', day: '2-digit',
        hour: '2-digit', minute: '2-digit', hour12: false,
    }).formatToParts(new Date());
    const o = Object.fromEntries(parts.map((p) => [p.type, p.value]));
    return { date: `${o.year}-${o.month}-${o.day}`, minutes: (parseInt(o.hour, 10) % 24) * 60 + parseInt(o.minute, 10) };
}

const toMinutes = (hhmm) => parseInt(hhmm.slice(0, 2), 10) * 60 + parseInt(hhmm.slice(3, 5), 10);

function alertText(alert) {
    const tr = (alert.descriptionText || alert.headerText || {}).translation || [];
    const es = tr.find((t) => t.language === 'es') || tr[0];
    return es ? es.text.replace(/\s+/g, ' ').trim() : null;
}

class TrainService {
    async getAlziraDepartures() {
        const schedule = loadSchedule();
        const now = madridNow();
        const today = schedule.days[now.date];
        if (!today) {
            // El horario del GTFS ya no cubre hoy: toca ejecutar actualizar_c2.py.
            return { ok: false, reason: 'schedule_expired', validUntil: schedule.validUntil };
        }

        const [feed, alertsFeed] = await Promise.all([
            cached(_feed, TRIP_UPDATES_URL, FEED_TTL_MS),
            cached(_alerts, ALERTS_URL, ALERTS_TTL_MS),
        ]);

        const updates = new Map();
        for (const e of (feed && feed.entity) || []) {
            const tu = e.tripUpdate;
            if (!tu || !tu.trip) continue;
            const stu = (tu.stopTimeUpdate || [])[0];
            const delayS = Number(tu.delay ?? stu?.arrival?.delay ?? stu?.departure?.delay ?? 0) || 0;
            updates.set(tu.trip.tripId, {
                canceled: tu.trip.scheduleRelationship === 'CANCELED',
                delayMin: Math.round(delayS / 60),
            });
        }

        const directions = { valencia: [], xativa: [] };
        for (const [tripId, hhmm, dir] of today) {
            const u = updates.get(tripId);
            const delayMin = u && !u.canceled ? u.delayMin : 0;
            const estimated = toMinutes(hhmm) + Math.max(delayMin, 0);
            // Se muestran los que aún no han salido (estimado) y los cancelados
            // de los próximos minutos, para que el usuario sepa que no vendrán.
            if (estimated < now.minutes) continue;
            const list = directions[dir];
            if (!list || list.length >= MAX_PER_DIRECTION) continue;
            list.push({
                scheduled: hhmm,
                delayMin,
                canceled: Boolean(u && u.canceled),
                live: Boolean(u),
            });
        }

        const nowS = Math.floor(Date.now() / 1000);
        const alerts = [];
        for (const e of (alertsFeed && alertsFeed.entity) || []) {
            const a = e.alert;
            if (!a) continue;
            const relevant = (a.informedEntity || []).some((ie) => isValenciaC2(ie.routeId) || ie.stopId === '64104');
            if (!relevant) continue;
            const periods = a.activePeriod || [];
            const active = periods.length === 0 || periods.some((p) => {
                const start = Number(p.start || 0);
                const end = Number(p.end || 0);
                if (end) return start <= nowS && nowS <= end;
                return start <= nowS && nowS - start <= ALERT_MAX_AGE_S;
            });
            const text = active && alertText(a);
            if (text && !alerts.includes(text)) alerts.push(text);
        }

        return {
            ok: true,
            date: now.date,
            realtime: Boolean(feed),
            feedTimestamp: feed?.header?.timestamp ? Number(feed.header.timestamp) : null,
            directions,
            alerts: alerts.slice(0, 3),
            validUntil: schedule.validUntil,
        };
    }
}

module.exports = new TrainService();
