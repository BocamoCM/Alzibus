#!/usr/bin/env node
// ==========================================================================
// generate-seo-pages.js — Genera páginas SEO estáticas de líneas y paradas
// ==========================================================================
// Lee assets/stops.json y produce:
//   website/lineas/l1/index.html, /l2/, /l3/                (1 por línea)
//   website/paradas/<id>-<slug>/index.html                  (1 por parada)
//   website/sitemap.xml                                     (regenerado)
//
// Cada página tiene:
//   - Meta tags optimizados (title, description, canonical, OG, Twitter)
//   - Schema.org rico (BusRoute / BusStop, BreadcrumbList)
//   - Mapa interactivo con Leaflet + OpenStreetMap (sin API key)
//   - Internal linking entre líneas, paradas y home
//   - CTA hacia la app móvil y la PWA web
//
// Uso:
//   node tools/generate-seo-pages.js
//
// Lo puedes ejecutar manualmente o en CI cuando cambies stops.json.
// ==========================================================================

const fs = require('fs');
const path = require('path');

const ROOT = path.join(__dirname, '..');
const STOPS_FILE = path.join(ROOT, 'assets', 'stops.json');
const WEBSITE_DIR = path.join(ROOT, 'website');
const BASE_URL = 'https://alzitrans.es';
const LAST_MOD = new Date().toISOString().split('T')[0];

// ── Paleta de colores por línea (consistente con la app) ────────────────────
const LINE_COLORS = {
    L1: '#1565C0',  // azul
    L2: '#2E7D32',  // verde
    L3: '#E65100',  // naranja
};

// ── Helpers ────────────────────────────────────────────────────────────────
function slugify(text) {
    return text
        .toString()
        .toLowerCase()
        .normalize('NFD').replace(/[̀-ͯ]/g, '') // quita tildes
        .replace(/[ç]/g, 'c')
        .replace(/[^a-z0-9]+/g, '-')                       // no alfanumérico → guion
        .replace(/^-+|-+$/g, '');                          // sin guiones extremos
}

function titleCase(text) {
    // ESTACIO RENFE → Estació Renfe (mantiene mayúscula inicial por palabra)
    return text.toLowerCase()
        .split(' ')
        .map(w => w.length > 2 ? w.charAt(0).toUpperCase() + w.slice(1) : w)
        .join(' ');
}

function escapeHtml(s) {
    return s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
}

function stopUrl(stop) {
    return `/paradas/${stop.id}-${slugify(stop.name)}/`;
}

function lineUrl(line) {
    return `/lineas/${line.toLowerCase()}/`;
}

function readableName(s) {
    return titleCase(s);
}

// ── Plantilla común <head> ─────────────────────────────────────────────────
function buildHead({ title, description, canonical, jsonLd, ogImage = '/assets/logo.png' }) {
    return `<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>${escapeHtml(title)}</title>
    <meta name="description" content="${escapeHtml(description)}">
    <meta name="robots" content="index, follow">
    <meta name="author" content="Alzitrans">
    <meta name="geo.region" content="ES-VC">
    <meta name="geo.placename" content="Alzira, Valencia, España">

    <link rel="canonical" href="${BASE_URL}${canonical}">

    <!-- Open Graph -->
    <meta property="og:type" content="website">
    <meta property="og:title" content="${escapeHtml(title)}">
    <meta property="og:description" content="${escapeHtml(description)}">
    <meta property="og:url" content="${BASE_URL}${canonical}">
    <meta property="og:image" content="${BASE_URL}${ogImage}">
    <meta property="og:locale" content="es_ES">
    <meta property="og:site_name" content="Alzitrans">

    <!-- Twitter -->
    <meta name="twitter:card" content="summary_large_image">
    <meta name="twitter:title" content="${escapeHtml(title)}">
    <meta name="twitter:description" content="${escapeHtml(description)}">
    <meta name="twitter:image" content="${BASE_URL}${ogImage}">

    <!-- Schema.org -->
    <script type="application/ld+json">
${JSON.stringify(jsonLd, null, 2)}
    </script>

    <!-- Google AdSense -->
    <script async src="https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js?client=ca-pub-8010840037570750"
         crossorigin="anonymous"></script>

    <!-- Leaflet (mapa interactivo OSS, sin API key) -->
    <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css"
        integrity="sha256-p4NxAoJBhIIN+hmNHrzRCf9tD/miZyoHS5obTRR9BMY=" crossorigin="">

    <link rel="icon" type="image/png" href="/assets/logo.png">
    <link rel="apple-touch-icon" href="/assets/logo.png">

    <style>
        /* Tema oscuro consistente con website/style.css de la landing. */
        :root {
            --burgundy: #6B1B3D;
            --coral: #E85A4F;
            --bg: #0a0a0f;
            --bg-soft: #14141c;
            --bg-card: #1c1c28;
            --text: #f0eff4;
            --text-muted: rgba(240, 239, 244, 0.55);
            --border: rgba(255, 255, 255, 0.08);
        }
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body { font-family: -apple-system, "Segoe UI", "Outfit", sans-serif; color: var(--text); line-height: 1.6; background: var(--bg); }
        a { color: var(--coral); text-decoration: none; }
        a:hover { text-decoration: underline; }
        .container { max-width: 980px; margin: 0 auto; padding: 24px; }
        header.topbar { background: rgba(20, 20, 28, 0.9); backdrop-filter: blur(8px); color: var(--text); padding: 14px 24px; border-bottom: 1px solid var(--border); position: sticky; top: 0; z-index: 10; }
        header.topbar a { color: var(--text); font-weight: 600; }
        header.topbar a.cta-btn { background: var(--burgundy); padding: 8px 18px; border-radius: 999px; color: white; }
        header.topbar .container { max-width: 980px; display: flex; align-items: center; justify-content: space-between; padding: 0; }
        .breadcrumb { font-size: 13px; color: var(--text-muted); margin: 12px 0 24px; }
        .breadcrumb a { color: var(--text-muted); }
        .line-badge { display: inline-block; padding: 4px 12px; border-radius: 16px; color: white; font-weight: 700; font-size: 13px; }
        h1 { font-size: 32px; margin-bottom: 12px; line-height: 1.2; color: var(--text); }
        h2 { font-size: 22px; margin: 32px 0 16px; color: var(--text); }
        h3 { font-size: 18px; margin: 24px 0 8px; color: var(--text); }
        p { margin-bottom: 12px; color: var(--text); }
        .lead { font-size: 17px; color: var(--text-muted); margin-bottom: 24px; }
        .card { background: var(--bg-card); border: 1px solid var(--border); border-radius: 12px; padding: 20px; margin-bottom: 16px; }
        .stops-list { list-style: none; }
        .stops-list li { padding: 12px 16px; border-bottom: 1px solid var(--border); display: flex; align-items: center; gap: 12px; }
        .stops-list li:last-child { border-bottom: none; }
        .stops-list li a { color: var(--text); }
        .stops-list .stop-num { background: var(--burgundy); color: white; font-weight: 700; min-width: 28px; height: 28px; border-radius: 50%; display: inline-flex; align-items: center; justify-content: center; font-size: 13px; }
        .map { width: 100%; height: 380px; border-radius: 12px; border: 1px solid var(--border); margin: 16px 0; }
        .cta { background: linear-gradient(135deg, var(--burgundy), var(--coral)); color: white; padding: 32px 24px; border-radius: 16px; text-align: center; margin: 32px 0; }
        .cta h2 { color: white; margin-top: 0; }
        .cta p { color: rgba(255,255,255,0.92); margin-bottom: 16px; }
        .cta a.btn { display: inline-block; background: white; color: var(--burgundy); padding: 12px 24px; border-radius: 999px; font-weight: 700; margin: 4px; }
        .cta a.btn:hover { text-decoration: none; transform: translateY(-1px); }
        .line-links { display: flex; gap: 8px; flex-wrap: wrap; margin: 16px 0; align-items: center; }
        .line-links a { padding: 6px 14px; border: 1px solid var(--border); border-radius: 999px; color: var(--text); font-weight: 600; font-size: 13px; background: var(--bg-card); }
        .line-links a:hover { text-decoration: none; border-color: var(--coral); }
        footer { background: var(--bg-soft); border-top: 1px solid var(--border); padding: 32px 24px; margin-top: 48px; text-align: center; color: var(--text-muted); font-size: 13px; }
        footer a { color: var(--text-muted); margin: 0 8px; }
        footer a:hover { color: var(--coral); }
        /* Leaflet: mantén el mapa con su fondo natural (es claro pero el contraste queda bien con el wrapper oscuro). */
        .leaflet-popup-content a { color: var(--burgundy); }
    </style>
</head>
<body>
    <header class="topbar">
        <div class="container">
            <a href="/" class="logo-link" style="display:flex; align-items:center; gap:10px; font-size:18px; font-weight:700;">
                <img src="/assets/logo.png" alt="Logo Alzitrans" style="width:32px; height:32px; border-radius:8px;">
                <span>Alzitrans</span>
            </a>
            <a href="/#descarga" class="cta-btn">Descargar app</a>
        </div>
    </header>
`;
}

function buildFooter() {
    return `
    <footer>
        <p>Alzitrans es una aplicación independiente para consultar información del bus urbano de Alzira. No es un servicio oficial de la empresa concesionaria.</p>
        <p style="margin-top:8px">
            <a href="/">Inicio</a> ·
            <a href="/lineas/l1/">L1</a> ·
            <a href="/lineas/l2/">L2</a> ·
            <a href="/lineas/l3/">L3</a> ·
            <a href="/legal/privacidad.html">Privacidad</a> ·
            <a href="/legal/terminos.html">Términos</a>
        </p>
    </footer>
</body>
</html>`;
}

// ── Plantilla de página de LÍNEA ───────────────────────────────────────────
function renderLinePage(line, stops, allStops) {
    const color = LINE_COLORS[line];
    const url = lineUrl(line);
    const title = `Línea ${line} bus Alzira - Paradas y recorrido | Alzitrans`;
    const description = `Recorrido completo y todas las paradas de la línea ${line} del bus urbano de Alzira. ${stops.length} paradas. Consulta tiempos en tiempo real en la app Alzitrans.`;

    const jsonLd = {
        '@context': 'https://schema.org',
        '@graph': [
            {
                '@type': 'BusTrip',
                name: `Línea ${line} - Bus urbano de Alzira`,
                description: `Recorrido de la línea ${line} del autobús urbano de Alzira con ${stops.length} paradas.`,
                provider: {
                    '@type': 'Organization',
                    name: 'Alzitrans',
                    url: BASE_URL,
                },
                arrivalBusStop: stops.length > 0 ? {
                    '@type': 'BusStop',
                    name: readableName(stops[stops.length - 1].name),
                    geo: {
                        '@type': 'GeoCoordinates',
                        latitude: stops[stops.length - 1].lat,
                        longitude: stops[stops.length - 1].lng,
                    }
                } : undefined,
                departureBusStop: stops.length > 0 ? {
                    '@type': 'BusStop',
                    name: readableName(stops[0].name),
                    geo: {
                        '@type': 'GeoCoordinates',
                        latitude: stops[0].lat,
                        longitude: stops[0].lng,
                    }
                } : undefined,
            },
            {
                '@type': 'BreadcrumbList',
                itemListElement: [
                    { '@type': 'ListItem', position: 1, name: 'Inicio', item: BASE_URL + '/' },
                    { '@type': 'ListItem', position: 2, name: 'Líneas', item: BASE_URL + '/lineas/' },
                    { '@type': 'ListItem', position: 3, name: `Línea ${line}`, item: BASE_URL + url },
                ],
            },
        ],
    };

    const otherLines = Object.keys(LINE_COLORS).filter(l => l !== line);
    const stopsJsForMap = JSON.stringify(stops.map(s => ({ id: s.id, n: readableName(s.name), lat: s.lat, lng: s.lng, u: stopUrl(s) })));

    return buildHead({ title, description, canonical: url, jsonLd }) + `
    <main class="container">
        <nav class="breadcrumb">
            <a href="/">Inicio</a> › <a href="/lineas/">Líneas</a> › Línea ${line}
        </nav>

        <span class="line-badge" style="background:${color}">${line}</span>
        <h1>Línea ${line}: bus urbano de Alzira</h1>
        <p class="lead">Recorrido de ${stops.length} paradas de la línea ${line} del autobús urbano de Alzira. Mira el mapa, identifica tu parada y consulta los tiempos en tiempo real desde la app.</p>

        <div class="line-links">
            <strong style="align-self:center">Otras líneas:</strong>
            ${otherLines.map(l => `<a href="${lineUrl(l)}">Línea ${l}</a>`).join('\n')}
        </div>

        <h2>Mapa con el recorrido de la línea ${line}</h2>
        <div id="map" class="map"></div>

        <h2>Todas las paradas de la línea ${line}</h2>
        <ol class="stops-list card">
            ${stops.map((s, i) => `
            <li>
                <span class="stop-num">${i + 1}</span>
                <a href="${stopUrl(s)}" style="flex:1">${readableName(s.name)}</a>
                <span style="color:var(--text-muted); font-size:13px">${(s.lines || []).join(' · ')}</span>
            </li>`).join('')}
        </ol>

        <div class="cta">
            <h2>¿Cuándo pasa el siguiente bus?</h2>
            <p>Los horarios del autobús urbano de Alzira no son fijos. Consulta los tiempos de paso en tiempo real desde la app Alzitrans o desde la versión web.</p>
            <a href="/#descarga" class="btn">Descargar app</a>
            <a href="/app/" class="btn">Abrir versión web</a>
        </div>

        <h2>Sobre la línea ${line}</h2>
        <p>La línea ${line} es una de las tres líneas que componen la red del autobús urbano de Alzira (Valencia), junto con la <a href="${lineUrl(otherLines[0])}">${otherLines[0]}</a> y la <a href="${lineUrl(otherLines[1])}">${otherLines[1]}</a>. Cubre ${stops.length} paradas en total.</p>
        <p>Para conocer el tiempo de llegada del siguiente autobús a una parada concreta, abre la app Alzitrans (gratis en Google Play) o accede a la versión web en <a href="/app/">alzitrans.es/app</a>. Los datos se actualizan en tiempo real.</p>
    </main>

    <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"
        integrity="sha256-20nQCchB9co0qIjJZRGuk2/Z9VM+kNiyxNV1lvTlZBo=" crossorigin=""></script>
    <script>
        (function() {
            const stops = ${stopsJsForMap};
            if (stops.length === 0) return;
            const bounds = L.latLngBounds(stops.map(s => [s.lat, s.lng]));
            const map = L.map('map').fitBounds(bounds, { padding: [24, 24] });
            L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
                maxZoom: 19,
                attribution: '© OpenStreetMap',
            }).addTo(map);
            const lineColor = '${color}';
            // Línea uniendo las paradas
            L.polyline(stops.map(s => [s.lat, s.lng]), { color: lineColor, weight: 4, opacity: 0.7 }).addTo(map);
            // Marcadores
            stops.forEach((s, i) => {
                const marker = L.circleMarker([s.lat, s.lng], { radius: 7, color: lineColor, fillColor: lineColor, fillOpacity: 0.9, weight: 2 }).addTo(map);
                marker.bindPopup('<strong>' + (i+1) + '. ' + s.n + '</strong><br><a href="' + s.u + '">Ver parada</a>');
            });
        })();
    </script>
` + buildFooter();
}

// ── Plantilla de página de PARADA ──────────────────────────────────────────
function renderStopPage(stop, allStops) {
    const url = stopUrl(stop);
    const niceName = readableName(stop.name);
    const linesText = stop.lines.join(', ');
    const title = `Parada ${niceName} - Bus Alzira ${stop.lines.join('/')} | Alzitrans`;
    const description = `Información de la parada "${niceName}" del autobús urbano de Alzira. Líneas que paran: ${linesText}. Consulta los tiempos de paso en tiempo real en la app Alzitrans.`;

    // 5 paradas cercanas (excluyendo la actual)
    const nearby = allStops
        .filter(s => s.id !== stop.id)
        .map(s => ({ ...s, dist: Math.sqrt((s.lat - stop.lat) ** 2 + (s.lng - stop.lng) ** 2) }))
        .sort((a, b) => a.dist - b.dist)
        .slice(0, 5);

    const jsonLd = {
        '@context': 'https://schema.org',
        '@graph': [
            {
                '@type': 'BusStop',
                name: niceName,
                description: `Parada del autobús urbano de Alzira. Líneas: ${linesText}.`,
                geo: {
                    '@type': 'GeoCoordinates',
                    latitude: stop.lat,
                    longitude: stop.lng,
                },
                address: {
                    '@type': 'PostalAddress',
                    addressLocality: 'Alzira',
                    addressRegion: 'Valencia',
                    addressCountry: 'ES',
                },
                publicAccess: true,
            },
            {
                '@type': 'BreadcrumbList',
                itemListElement: [
                    { '@type': 'ListItem', position: 1, name: 'Inicio', item: BASE_URL + '/' },
                    { '@type': 'ListItem', position: 2, name: 'Paradas', item: BASE_URL + '/paradas/' },
                    { '@type': 'ListItem', position: 3, name: niceName, item: BASE_URL + url },
                ],
            },
        ],
    };

    return buildHead({ title, description, canonical: url, jsonLd }) + `
    <main class="container">
        <nav class="breadcrumb">
            <a href="/">Inicio</a> › <a href="/paradas/">Paradas</a> › ${niceName}
        </nav>

        <h1>Parada ${niceName}</h1>
        <p class="lead">Parada del autobús urbano de Alzira. Líneas que paran aquí: <strong>${linesText}</strong>.</p>

        <div class="line-links">
            ${stop.lines.map(l => `<a href="${lineUrl(l)}"><span class="line-badge" style="background:${LINE_COLORS[l]}">${l}</span> Ver línea</a>`).join('')}
        </div>

        <h2>Ubicación</h2>
        <div id="map" class="map"></div>
        <p style="font-size:13px; color:var(--text-muted)">Coordenadas: ${stop.lat.toFixed(6)}, ${stop.lng.toFixed(6)} · <a href="https://www.google.com/maps?q=${stop.lat},${stop.lng}" target="_blank" rel="noopener">Abrir en Google Maps</a></p>

        <div class="cta">
            <h2>¿Cuándo llega el siguiente bus a ${niceName}?</h2>
            <p>Los horarios del bus urbano de Alzira no son fijos. Consulta los tiempos de paso en tiempo real desde la app Alzitrans o desde la versión web.</p>
            <a href="/#descarga" class="btn">Descargar app</a>
            <a href="/app/" class="btn">Abrir versión web</a>
        </div>

        <h2>Paradas cercanas</h2>
        <ul class="stops-list card">
            ${nearby.map(s => `
            <li>
                <a href="${stopUrl(s)}" style="flex:1">${readableName(s.name)}</a>
                <span style="color:var(--text-muted); font-size:13px">${s.lines.join(' · ')}</span>
            </li>`).join('')}
        </ul>

        <h2>Sobre esta parada</h2>
        <p>${niceName} es una de las 52 paradas del autobús urbano de Alzira. Está cubierta por ${stop.lines.length === 1 ? 'la línea' : 'las líneas'} ${stop.lines.map(l => `<a href="${lineUrl(l)}">${l}</a>`).join(', ')}. Para conocer el tiempo de paso del siguiente bus, abre la app Alzitrans (gratis en Google Play) o accede a la versión web en <a href="/app/">alzitrans.es/app</a>.</p>
    </main>

    <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"
        integrity="sha256-20nQCchB9co0qIjJZRGuk2/Z9VM+kNiyxNV1lvTlZBo=" crossorigin=""></script>
    <script>
        (function() {
            const map = L.map('map').setView([${stop.lat}, ${stop.lng}], 17);
            L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
                maxZoom: 19,
                attribution: '© OpenStreetMap',
            }).addTo(map);
            L.marker([${stop.lat}, ${stop.lng}]).addTo(map).bindPopup('${niceName.replace(/'/g, "\\'")}').openPopup();
        })();
    </script>
` + buildFooter();
}

// ── Índice de líneas ───────────────────────────────────────────────────────
function renderLinesIndex(stops) {
    const title = 'Líneas del bus urbano de Alzira (L1, L2, L3) | Alzitrans';
    const description = 'Información completa de las 3 líneas del bus urbano de Alzira: L1, L2 y L3. Recorrido, paradas y mapa de cada línea.';
    const jsonLd = {
        '@context': 'https://schema.org',
        '@type': 'BreadcrumbList',
        itemListElement: [
            { '@type': 'ListItem', position: 1, name: 'Inicio', item: BASE_URL + '/' },
            { '@type': 'ListItem', position: 2, name: 'Líneas', item: BASE_URL + '/lineas/' },
        ],
    };
    const linesData = Object.keys(LINE_COLORS).map(l => ({
        line: l,
        count: stops.filter(s => (s.lines || []).includes(l)).length,
        color: LINE_COLORS[l],
    }));

    return buildHead({ title, description, canonical: '/lineas/', jsonLd }) + `
    <main class="container">
        <nav class="breadcrumb"><a href="/">Inicio</a> › Líneas</nav>
        <h1>Líneas del bus urbano de Alzira</h1>
        <p class="lead">El autobús urbano de Alzira tiene 3 líneas: L1, L2 y L3. Elige una para ver el recorrido, las paradas y el mapa.</p>
        <div class="card" style="padding:0">
            <ul class="stops-list">
                ${linesData.map(d => `
                <li>
                    <span class="line-badge" style="background:${d.color}">${d.line}</span>
                    <a href="${lineUrl(d.line)}" style="flex:1">Línea ${d.line}</a>
                    <span style="color:var(--text-muted); font-size:13px">${d.count} paradas</span>
                </li>`).join('')}
            </ul>
        </div>
        <div class="cta">
            <h2>Tiempos de paso en tiempo real</h2>
            <p>Los horarios no son fijos. Descarga la app Alzitrans o usa la versión web para saber cuándo pasa el siguiente bus.</p>
            <a href="/#descarga" class="btn">Descargar app</a>
            <a href="/app/" class="btn">Abrir versión web</a>
        </div>
    </main>
` + buildFooter();
}

// ── Índice de paradas ──────────────────────────────────────────────────────
function renderStopsIndex(stops) {
    const title = 'Todas las paradas del bus urbano de Alzira | Alzitrans';
    const description = `Listado completo de las ${stops.length} paradas del autobús urbano de Alzira con sus líneas y ubicación.`;
    const jsonLd = {
        '@context': 'https://schema.org',
        '@type': 'BreadcrumbList',
        itemListElement: [
            { '@type': 'ListItem', position: 1, name: 'Inicio', item: BASE_URL + '/' },
            { '@type': 'ListItem', position: 2, name: 'Paradas', item: BASE_URL + '/paradas/' },
        ],
    };
    const sorted = [...stops].sort((a, b) => a.name.localeCompare(b.name, 'es'));

    return buildHead({ title, description, canonical: '/paradas/', jsonLd }) + `
    <main class="container">
        <nav class="breadcrumb"><a href="/">Inicio</a> › Paradas</nav>
        <h1>Todas las paradas del bus urbano de Alzira</h1>
        <p class="lead">${stops.length} paradas en total. Pulsa una para ver su ubicación, las líneas que paran y los tiempos de paso.</p>
        <ul class="stops-list card">
            ${sorted.map(s => `
            <li>
                <a href="${stopUrl(s)}" style="flex:1">${readableName(s.name)}</a>
                <span style="color:var(--text-muted); font-size:13px">${s.lines.join(' · ')}</span>
            </li>`).join('')}
        </ul>
    </main>
` + buildFooter();
}

// ── Sitemap ────────────────────────────────────────────────────────────────
function renderSitemap(stops) {
    const urls = [
        { loc: '/', changefreq: 'weekly', priority: 1.0 },
        { loc: '/app/', changefreq: 'weekly', priority: 0.9 },
        { loc: '/descargar/', changefreq: 'monthly', priority: 0.7 },
        { loc: '/lineas/', changefreq: 'monthly', priority: 0.8 },
        { loc: '/paradas/', changefreq: 'monthly', priority: 0.8 },
        ...Object.keys(LINE_COLORS).map(l => ({ loc: lineUrl(l), changefreq: 'monthly', priority: 0.7 })),
        ...stops.map(s => ({ loc: stopUrl(s), changefreq: 'monthly', priority: 0.6 })),
        { loc: '/legal/privacidad.html', changefreq: 'yearly', priority: 0.3 },
        { loc: '/legal/terminos.html', changefreq: 'yearly', priority: 0.3 },
    ];

    return `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
${urls.map(u => `  <url>
    <loc>${BASE_URL}${u.loc}</loc>
    <lastmod>${LAST_MOD}</lastmod>
    <changefreq>${u.changefreq}</changefreq>
    <priority>${u.priority}</priority>
  </url>`).join('\n')}
</urlset>
`;
}

// ── Main ───────────────────────────────────────────────────────────────────
function main() {
    const raw = fs.readFileSync(STOPS_FILE, 'utf-8');
    const stops = JSON.parse(raw);
    console.log(`📍 Cargadas ${stops.length} paradas de assets/stops.json`);

    // Limpia directorios antiguos para empezar de cero
    const lineasDir = path.join(WEBSITE_DIR, 'lineas');
    const paradasDir = path.join(WEBSITE_DIR, 'paradas');
    for (const dir of [lineasDir, paradasDir]) {
        if (fs.existsSync(dir)) fs.rmSync(dir, { recursive: true, force: true });
        fs.mkdirSync(dir, { recursive: true });
    }

    // Índice de líneas
    fs.writeFileSync(path.join(lineasDir, 'index.html'), renderLinesIndex(stops));
    console.log(`✓ /lineas/`);

    // Páginas por línea
    for (const line of Object.keys(LINE_COLORS)) {
        const lineStops = stops.filter(s => (s.lines || []).includes(line));
        const dir = path.join(lineasDir, line.toLowerCase());
        fs.mkdirSync(dir, { recursive: true });
        fs.writeFileSync(path.join(dir, 'index.html'), renderLinePage(line, lineStops, stops));
        console.log(`✓ /lineas/${line.toLowerCase()}/ (${lineStops.length} paradas)`);
    }

    // Índice de paradas
    fs.writeFileSync(path.join(paradasDir, 'index.html'), renderStopsIndex(stops));
    console.log(`✓ /paradas/`);

    // Páginas por parada
    for (const stop of stops) {
        const slug = `${stop.id}-${slugify(stop.name)}`;
        const dir = path.join(paradasDir, slug);
        fs.mkdirSync(dir, { recursive: true });
        fs.writeFileSync(path.join(dir, 'index.html'), renderStopPage(stop, stops));
    }
    console.log(`✓ /paradas/<id>-<slug>/ × ${stops.length}`);

    // Sitemap
    fs.writeFileSync(path.join(WEBSITE_DIR, 'sitemap.xml'), renderSitemap(stops));
    console.log(`✓ sitemap.xml (${5 + Object.keys(LINE_COLORS).length + stops.length + 2} URLs)`);

    console.log(`\n🎉 Done. Total páginas generadas: ${2 + Object.keys(LINE_COLORS).length + stops.length}`);
    console.log(`Para desplegar:`);
    console.log(`  cd ~/Alzi/Alzibus && git pull`);
    console.log(`  sudo docker compose restart website`);
}

main();
