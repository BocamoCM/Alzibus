// ──────────────────────────────────────────────────────────────
//  revenue.service.js — Ingresos reales de Google AdMob (app) y
//  AdSense (web) vía sus APIs oficiales.
//
//  Config (en backend/.env), obtenida con tools/google-oauth.js:
//     GOOGLE_CLIENT_ID=...
//     GOOGLE_CLIENT_SECRET=...
//     GOOGLE_REFRESH_TOKEN=...
//     ADMOB_ACCOUNT=accounts/pub-XXXXXXXXXXXXXXXX     (opcional, autodetecta)
//     ADSENSE_ACCOUNT=accounts/pub-XXXXXXXXXXXXXXXX   (opcional, autodetecta)
//
//  Si falta config o googleapis no está instalado, devuelve
//  { configured:false } SIN romper el backend.
// ──────────────────────────────────────────────────────────────

const CACHE_TTL_MS = 3 * 60 * 60 * 1000; // 3h: los informes se actualizan lento
let _cache = { at: 0, data: null };

function envOk() {
    return process.env.GOOGLE_CLIENT_ID &&
           process.env.GOOGLE_CLIENT_SECRET &&
           process.env.GOOGLE_REFRESH_TOKEN;
}

function getOAuthClient(google) {
    const oauth2 = new google.auth.OAuth2(
        process.env.GOOGLE_CLIENT_ID,
        process.env.GOOGLE_CLIENT_SECRET
    );
    oauth2.setCredentials({ refresh_token: process.env.GOOGLE_REFRESH_TOKEN });
    return oauth2;
}

function daysAgo(n) {
    const d = new Date();
    d.setDate(d.getDate() - n);
    return d;
}
function ymd(date) {
    return { year: date.getFullYear(), month: date.getMonth() + 1, day: date.getDate() };
}
function isoDay(date) {
    return date.toISOString().slice(0, 10);
}

// ── AdMob (ingresos de la app móvil) ──
async function fetchAdmob(google, auth) {
    const admob = google.admob({ version: 'v1', auth });

    let account = process.env.ADMOB_ACCOUNT;
    if (!account) {
        const list = await admob.accounts.list();
        account = list.data.account && list.data.account[0] && list.data.account[0].name;
    }
    if (!account) throw new Error('No se encontró cuenta de AdMob');

    const end = new Date();
    const start = daysAgo(29);
    const res = await admob.accounts.networkReport.generate({
        parent: account,
        requestBody: {
            reportSpec: {
                dateRange: { startDate: ymd(start), endDate: ymd(end) },
                dimensions: ['DATE'],
                metrics: ['ESTIMATED_EARNINGS', 'IMPRESSIONS', 'CLICKS'],
                localizationSettings: { currencyCode: 'EUR' },
            },
        },
    });

    // La respuesta es un array: [header, row, row, ..., footer]
    const rows = (res.data || []).filter(r => r && r.row).map(r => r.row);
    const series = rows.map(r => {
        const dv = r.dimensionValues || {};
        const mv = r.metricValues || {};
        const dateStr = dv.DATE && dv.DATE.value ? dv.DATE.value : ''; // YYYYMMDD
        const day = dateStr.length === 8
            ? `${dateStr.slice(0, 4)}-${dateStr.slice(4, 6)}-${dateStr.slice(6, 8)}`
            : dateStr;
        const micros = mv.ESTIMATED_EARNINGS ? Number(mv.ESTIMATED_EARNINGS.microsValue || 0) : 0;
        return {
            day,
            earnings: +(micros / 1e6).toFixed(2),
            impressions: mv.IMPRESSIONS ? Number(mv.IMPRESSIONS.integerValue || 0) : 0,
            clicks: mv.CLICKS ? Number(mv.CLICKS.integerValue || 0) : 0,
        };
    });
    return summarize(series);
}

// ── AdSense (ingresos de la web) ──
async function fetchAdsense(google, auth) {
    const adsense = google.adsense({ version: 'v2', auth });

    let account = process.env.ADSENSE_ACCOUNT;
    if (!account) {
        const list = await adsense.accounts.list();
        account = list.data.accounts && list.data.accounts[0] && list.data.accounts[0].name;
    }
    if (!account) throw new Error('No se encontró cuenta de AdSense');

    const end = new Date();
    const start = daysAgo(29);
    const res = await adsense.accounts.reports.generate({
        account,
        'dateRange': 'CUSTOM',
        'startDate.year': start.getFullYear(),
        'startDate.month': start.getMonth() + 1,
        'startDate.day': start.getDate(),
        'endDate.year': end.getFullYear(),
        'endDate.month': end.getMonth() + 1,
        'endDate.day': end.getDate(),
        dimensions: ['DATE'],
        metrics: ['ESTIMATED_EARNINGS', 'IMPRESSIONS', 'CLICKS'],
        currencyCode: 'EUR',
    });

    const headers = (res.data.headers || []).map(h => h.name);
    const idx = (name) => headers.indexOf(name);
    const rows = res.data.rows || [];
    const series = rows.map(r => {
        const cells = r.cells || [];
        const get = (name) => {
            const i = idx(name);
            return i >= 0 && cells[i] ? cells[i].value : null;
        };
        return {
            day: get('DATE'),
            earnings: +(Number(get('ESTIMATED_EARNINGS') || 0)).toFixed(2),
            impressions: Number(get('IMPRESSIONS') || 0),
            clicks: Number(get('CLICKS') || 0),
        };
    });
    return summarize(series);
}

function summarize(series) {
    const sum = (arr, k) => arr.reduce((a, b) => a + (b[k] || 0), 0);
    const last = (n) => series.slice(-n);
    const todayStr = isoDay(new Date());
    const yStr = isoDay(daysAgo(1));
    const today = series.find(s => s.day === todayStr);
    const yesterday = series.find(s => s.day === yStr);
    return {
        today: today ? today.earnings : 0,
        yesterday: yesterday ? yesterday.earnings : 0,
        last7: +sum(last(7), 'earnings').toFixed(2),
        last30: +sum(series, 'earnings').toFixed(2),
        impressions30: sum(series, 'impressions'),
        clicks30: sum(series, 'clicks'),
        series, // [{day, earnings, impressions, clicks}]
    };
}

async function getRevenue() {
    if (!envOk()) {
        return { configured: false, reason: 'Faltan credenciales OAuth de Google en .env' };
    }
    if (_cache.data && Date.now() - _cache.at < CACHE_TTL_MS) {
        return _cache.data;
    }

    let google;
    try {
        ({ google } = require('googleapis'));
    } catch (e) {
        return { configured: false, reason: "Falta la dependencia 'googleapis' (npm install)" };
    }

    const auth = getOAuthClient(google);
    const out = { configured: true, currency: 'EUR', admob: null, adsense: null, errors: {} };

    const [admobRes, adsenseRes] = await Promise.allSettled([
        fetchAdmob(google, auth),
        fetchAdsense(google, auth),
    ]);
    if (admobRes.status === 'fulfilled') out.admob = admobRes.value;
    else out.errors.admob = String(admobRes.reason && admobRes.reason.message || admobRes.reason);
    if (adsenseRes.status === 'fulfilled') out.adsense = adsenseRes.value;
    else out.errors.adsense = String(adsenseRes.reason && adsenseRes.reason.message || adsenseRes.reason);

    _cache = { at: Date.now(), data: out };
    return out;
}

module.exports = { getRevenue };
