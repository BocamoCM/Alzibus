"""Plantilla de website/estacion-renfe/index.html.

No se ejecuta a mano: la llama tools/renfe/actualizar_c2.py con
  python pagina.py <horario_tipo.json> <salida.html> <fecha_iso> <valido_hasta_iso>

horario_tipo.json = {"laborable": {...}, "sabado": {...}, "domingo": {...}},
cada uno con "valencia" y "moixent" → lista de [hora, origen, destino].
"""
import datetime as dt
import json
import sys
from pathlib import Path

d = json.load(open(sys.argv[1], encoding="utf-8"))
OUT = Path(sys.argv[2])
MESES = ["enero", "febrero", "marzo", "abril", "mayo", "junio", "julio", "agosto",
         "septiembre", "octubre", "noviembre", "diciembre"]
_upd = dt.date.fromisoformat(sys.argv[3])
_until = dt.date.fromisoformat(sys.argv[4])
UPDATED_ISO, UPDATED_TXT = _upd.isoformat(), f"{_upd.day} de {MESES[_upd.month - 1]} de {_upd.year}"
VALID_TXT = f"hasta el {_until.day} de {MESES[_until.month - 1]} de {_until.year}"


PARTS = (("Mañana", 0, 14), ("Tarde", 14, 21), ("Noche", 21, 24))


def times(day, direction):
    return [t for t, _, _ in d[day][direction]]


def chips(day, direction):
    """Horas completas agrupadas en mañana / tarde / noche."""
    out = []
    for label, lo, hi in PARTS:
        ts = [t for t in times(day, direction) if lo <= int(t[:2]) < hi]
        if ts:
            items = "".join(f"<li>{t}</li>" for t in ts)
            out.append(f'<div class="part"><h4>{label}</h4><ul class="times">{items}</ul></div>')
    return "\n                ".join(out)


def direction_block(direction, title, dest_note=""):
    return f"""        <section class="dir" id="{direction}">
            <h2><span class="badge">C2</span> {title}</h2>
            <div class="day day-laborable">
                <p class="day-label">Lunes a viernes · {len(times('laborable', direction))} trenes</p>
                {chips('laborable', direction)}
            </div>
            <div class="day day-finde" hidden>
                <p class="day-label">Sábados y domingos · {len(times('sabado', direction))} trenes</p>
                {chips('sabado', direction)}
            </div>
            {dest_note}
        </section>"""


def last(day, direction):
    return d[day][direction][-1][0]


def first(day, direction):
    return d[day][direction][0][0]


n_lab_v, n_fds_v = len(d["laborable"]["valencia"]), len(d["sabado"]["valencia"])
n_lab_x, n_fds_x = len(d["laborable"]["moixent"]), len(d["sabado"]["moixent"])
# La página agrupa sábado y domingo (hoy coinciden); actualizar_c2.py avisa si dejan de hacerlo.
dest_x = sorted({x[2] for k in ("laborable", "sabado") for x in d[k]["moixent"]})
short_x = [x for x in d["laborable"]["moixent"] if "Alcúdia" in x[2]]

faq = [
    ("¿A qué hora sale el último tren de Alzira a València?",
     f"El último Cercanías C2 de Alzira hacia València Nord sale a las {last('laborable', 'valencia')}, tanto en laborables como en fin de semana."),
    ("¿Cada cuánto pasa el tren de Alzira a València?",
     f"En días laborables hay {n_lab_v} trenes de Cercanías C2 hacia València, entre las {first('laborable', 'valencia')} y las {last('laborable', 'valencia')}: dos o tres por hora en hora punta. Los sábados y domingos hay {n_fds_v}."),
    ("¿Qué autobús urbano va a la estación RENFE de Alzira?",
     "Las tres líneas del bus urbano de Alzira (L1, L2 y L3) paran en la estación RENFE y la conectan con el centro y el Hospital de la Ribera. La L1 es la más frecuente: cada 30 minutos en laborables."),
]
faq_ld = ",\n".join(
    f'    {{ "@type": "Question", "name": {json.dumps(q, ensure_ascii=False)}, "acceptedAnswer": {{ "@type": "Answer", "text": {json.dumps(a, ensure_ascii=False)} }} }}'
    for q, a in faq)
js_data = json.dumps({
    "laborable": {k: times("laborable", k) for k in ("valencia", "moixent")},
    "finde": {k: times("sabado", k) for k in ("valencia", "moixent")},
}, separators=(",", ":"))
faq_html = "\n".join(f'        <p class="faq-q">{q}</p>\n        <p>{a}</p>' for q, a in faq)

html = f"""<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Bus y tren en la estación RENFE de Alzira (C2) | Alzitrans</title>
    <meta name="description" content="Horarios del Cercanías C2 en Alzira hacia València y Xàtiva, y los autobuses urbanos L1, L2 y L3 que enlazan con la estación RENFE.">
    <meta name="robots" content="index, follow">
    <meta name="author" content="Alzitrans">
    <meta name="geo.region" content="ES-VC">
    <meta name="geo.placename" content="Alzira, Valencia, España">

    <link rel="canonical" href="https://alzitrans.es/estacion-renfe/">

    <!-- Open Graph -->
    <meta property="og:type" content="article">
    <meta property="og:title" content="Bus y tren en la estación RENFE de Alzira (C2) | Alzitrans">
    <meta property="og:description" content="Horarios del Cercanías C2 en Alzira hacia València y Xàtiva, y los autobuses urbanos que enlazan con la estación.">
    <meta property="og:url" content="https://alzitrans.es/estacion-renfe/">
    <meta property="og:image" content="https://alzitrans.es/assets/logo.png">
    <meta property="og:locale" content="es_ES">
    <meta property="og:site_name" content="Alzitrans">

    <!-- Twitter -->
    <meta name="twitter:card" content="summary_large_image">
    <meta name="twitter:title" content="Bus y tren en la estación RENFE de Alzira (C2) | Alzitrans">
    <meta name="twitter:description" content="Horarios del Cercanías C2 en Alzira y los autobuses urbanos que enlazan con la estación.">
    <meta name="twitter:image" content="https://alzitrans.es/assets/logo.png">

    <!-- Schema.org: WebPage -->
    <script type="application/ld+json">
{{
  "@context": "https://schema.org",
  "@type": "WebPage",
  "name": "Bus y tren en la estación RENFE de Alzira",
  "url": "https://alzitrans.es/estacion-renfe/",
  "inLanguage": "es",
  "dateModified": "{UPDATED_ISO}",
  "publisher": {{ "@id": "https://alzitrans.es/#org" }},
  "about": {{ "@type": "TrainStation", "name": "Alzira", "address": "Alzira, Valencia, España" }},
  "citation": "https://data.renfe.com/dataset/horarios-cercanias"
}}
    </script>
    <!-- Schema.org: FAQPage -->
    <script type="application/ld+json">
{{
  "@context": "https://schema.org",
  "@type": "FAQPage",
  "mainEntity": [
{faq_ld}
  ]
}}
    </script>
    <!-- Schema.org: Breadcrumb -->
    <script type="application/ld+json">
{{
  "@context": "https://schema.org",
  "@type": "BreadcrumbList",
  "itemListElement": [
    {{ "@type": "ListItem", "position": 1, "name": "Inicio", "item": "https://alzitrans.es/" }},
    {{ "@type": "ListItem", "position": 2, "name": "Estación RENFE", "item": "https://alzitrans.es/estacion-renfe/" }}
  ]
}}
    </script>

    <script defer src="/cookie-banner.js"></script>

    <link rel="icon" type="image/png" href="/assets/logo.png">
    <link rel="apple-touch-icon" href="/assets/logo.png">

    <style>
        :root {{
            --burgundy: #6B1B3D; --coral: #E85A4F; --bg: #0a0a0f; --bg-soft: #14141c;
            --bg-card: #1c1c28; --text: #f0eff4; --text-muted: rgba(240, 239, 244, 0.55);
            --border: rgba(255, 255, 255, 0.08); --c2: #F5A623;
        }}
        * {{ box-sizing: border-box; margin: 0; padding: 0; }}
        body {{ font-family: -apple-system, "Segoe UI", "Outfit", sans-serif; color: var(--text); line-height: 1.7; background: var(--bg); }}
        a {{ color: var(--coral); text-decoration: none; }}
        a:hover {{ text-decoration: underline; }}
        .container {{ max-width: 860px; margin: 0 auto; padding: 24px; }}
        header.topbar {{ background: rgba(20, 20, 28, 0.9); backdrop-filter: blur(8px); padding: 14px 24px; border-bottom: 1px solid var(--border); position: sticky; top: 0; z-index: 10; }}
        header.topbar a {{ color: var(--text); font-weight: 600; }}
        header.topbar a.cta-btn {{ background: var(--burgundy); padding: 8px 18px; border-radius: 999px; color: white; }}
        header.topbar .container {{ max-width: 860px; display: flex; align-items: center; justify-content: space-between; padding: 0; }}
        .breadcrumb {{ font-size: 13px; color: var(--text-muted); margin: 12px 0 24px; }}
        .breadcrumb a {{ color: var(--text-muted); }}
        h1 {{ font-size: 32px; margin-bottom: 12px; line-height: 1.2; }}
        h2 {{ font-size: 23px; margin: 36px 0 14px; display: flex; align-items: center; gap: 10px; flex-wrap: wrap; }}
        p {{ margin-bottom: 14px; }}
        .lead {{ font-size: 18px; color: var(--text-muted); margin-bottom: 24px; }}
        .badge {{ display: inline-block; padding: 2px 10px; border-radius: 6px; font-weight: 800; font-size: 14px; color: #1a1205; background: var(--c2); }}
        .line-badge {{ display: inline-block; padding: 2px 10px; border-radius: 16px; color: white; font-weight: 700; font-size: 13px; }}
        .facts {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(170px, 1fr)); gap: 10px; margin: 8px 0 8px; }}
        .fact {{ background: var(--bg-card); border: 1px solid var(--border); border-radius: 12px; padding: 12px 14px; }}
        .fact b {{ display: block; font-size: 22px; font-variant-numeric: tabular-nums; }}
        .fact span {{ font-size: 13px; color: var(--text-muted); }}
        /* Próximos trenes */
        .next {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(240px, 1fr)); gap: 12px; margin: 8px 0 4px; }}
        .next-card {{ background: var(--bg-card); border: 1px solid var(--border); border-left: 4px solid var(--c2); border-radius: 12px; padding: 14px 16px; }}
        .next-card .to {{ font-size: 14px; color: var(--text-muted); }}
        .next-card .when {{ font-size: 30px; font-weight: 800; font-variant-numeric: tabular-nums; line-height: 1.2; }}
        .next-card .in {{ font-size: 15px; color: var(--c2); font-weight: 700; }}
        .next-card .after {{ font-size: 14px; color: var(--text-muted); margin-top: 4px; }}
        .next-hint {{ font-size: 13px; color: var(--text-muted); }}
        .renfe-notice {{ font-size: 14px; background: rgba(245,166,35,0.10); border: 1px solid rgba(245,166,35,0.35); border-radius: 12px; padding: 12px 16px; margin: 0 0 8px; }}
        .next-card .when s {{ color: var(--text-muted); font-size: 20px; font-weight: 600; }}
        .st {{ display: inline-block; vertical-align: middle; font-size: 12px; font-weight: 700; padding: 2px 8px; border-radius: 999px; background: rgba(255,255,255,0.08); color: var(--text-muted); }}
        .st-ok {{ background: rgba(92,194,138,0.15); color: #6fd39b; }}
        .st-late {{ background: rgba(245,166,35,0.18); color: #f5b84a; }}
        .st-bad {{ background: rgba(232,90,79,0.18); color: #ff8a7d; }}
        .next-card .after.bad {{ color: #ff8a7d; }}
        .alert {{ font-size: 14px; background: rgba(232,90,79,0.10); border: 1px solid rgba(232,90,79,0.35); border-radius: 10px; padding: 10px 14px; margin: 10px 0 0; }}
        /* Selector de día */
        .daypick {{ display: inline-flex; gap: 4px; background: var(--bg-card); border: 1px solid var(--border); border-radius: 999px; padding: 4px; margin: 6px 0 0; }}
        .daypick button {{ font: inherit; font-size: 14px; font-weight: 600; color: var(--text-muted); background: transparent; border: 0; border-radius: 999px; padding: 7px 14px; cursor: pointer; }}
        .daypick button[aria-pressed="true"] {{ background: var(--c2); color: #1a1205; }}
        .daypick button:focus-visible {{ outline: 2px solid var(--coral); outline-offset: 2px; }}
        /* Lista de horas */
        .dir {{ background: var(--bg-card); border: 1px solid var(--border); border-radius: 14px; padding: 4px 18px 16px; margin: 18px 0; }}
        .dir h2 {{ margin: 16px 0 6px; font-size: 21px; }}
        .day-label {{ font-size: 14px; color: var(--text-muted); margin: 0 0 8px; }}
        .part {{ display: grid; grid-template-columns: 74px 1fr; gap: 10px; align-items: start; padding: 8px 0; border-top: 1px solid var(--border); }}
        .part h4 {{ font-size: 14px; color: var(--text-muted); font-weight: 600; padding-top: 5px; }}
        ul.times {{ list-style: none; display: flex; flex-wrap: wrap; gap: 6px; }}
        ul.times li {{ font-variant-numeric: tabular-nums; font-weight: 600; font-size: 15px; background: rgba(245,166,35,0.10); border: 1px solid rgba(245,166,35,0.25); border-radius: 8px; padding: 3px 9px; }}
        ul.times li.gone {{ opacity: 0.35; }}
        @media (max-width: 480px) {{ .part {{ grid-template-columns: 1fr; gap: 4px; }} .part h4 {{ padding-top: 0; }} }}
        .note {{ font-size: 13px; color: var(--text-muted); border-left: 3px solid var(--coral); padding: 4px 0 4px 12px; margin: 10px 0; }}
        .card {{ background: var(--bg-card); border: 1px solid var(--border); border-radius: 12px; padding: 16px 20px; margin: 12px 0; }}
        .card p:last-child {{ margin-bottom: 0; }}
        .faq-q {{ font-weight: 700; margin-top: 18px; }}
        .cta {{ background: linear-gradient(135deg, var(--burgundy), var(--coral)); color: white; padding: 30px 24px; border-radius: 16px; text-align: center; margin: 36px 0; }}
        .cta h2 {{ color: white; margin-top: 0; justify-content: center; }}
        .cta p {{ color: rgba(255,255,255,0.92); margin-bottom: 16px; }}
        .cta a.btn {{ display: inline-block; background: white; color: var(--burgundy); padding: 12px 24px; border-radius: 999px; font-weight: 700; margin: 4px; }}
        .cta a.btn:hover {{ text-decoration: none; }}
        footer {{ background: var(--bg-soft); border-top: 1px solid var(--border); padding: 32px 24px; margin-top: 48px; text-align: center; color: var(--text-muted); font-size: 13px; }}
        footer a {{ color: var(--text-muted); margin: 0 8px; }}
        footer a:hover {{ color: var(--coral); }}
    </style>
    <link rel="stylesheet" href="/cookie-banner.css">
</head>
<body>
    <header class="topbar">
        <div class="container">
            <a href="/" class="logo-link" style="display:flex; align-items:center; gap:10px; font-size:18px; font-weight:700;">
                <img src="/assets/logo.png" alt="Logo Alzitrans" width="32" height="32" style="width:32px; height:32px; border-radius:8px;">
                <span>Alzitrans</span>
            </a>
            <a href="/#descarga" class="cta-btn">Descargar app</a>
        </div>
    </header>

    <main class="container">
        <nav class="breadcrumb"><a href="/">Inicio</a> › Estación RENFE</nav>
        <h1>Estación RENFE de Alzira: trenes C2 y bus urbano</h1>
        <p class="lead">La estación de Alzira está en la línea C2 de Cercanías (València Nord – Xàtiva – Moixent). Aquí tienes los horarios de los trenes y los autobuses urbanos que la conectan con el centro y el Hospital de la Ribera.</p>

        <p class="renfe-notice"><strong>Horarios de Renfe.</strong> Los horarios de tren salen de los datos abiertos de Renfe y los retrasos, de su información en tiempo real. Pueden variar por obras, incidencias o cambios de última hora: antes de viajar, confírmalo en <a href="https://www.renfe.com/es/es/cercanias/cercanias-valencia" rel="noopener" target="_blank">renfe.com</a> o en la estación.</p>

        <h2>Próximos trenes desde Alzira</h2>
        <div class="next" id="next">
            <div class="next-card"><p class="to">Hacia València Nord</p><p class="when">{first('laborable', 'valencia')}</p><p class="after">Primer tren de lunes a viernes. Último: {last('laborable', 'valencia')}.</p></div>
            <div class="next-card"><p class="to">Hacia Xàtiva</p><p class="when">{first('laborable', 'moixent')}</p><p class="after">Primer tren de lunes a viernes. Último: {last('laborable', 'moixent')}.</p></div>
        </div>
        <p class="next-hint" id="next-hint">Horas de salida desde la estación de Alzira.</p>
        <div id="alerts" aria-live="polite"></div>

        <h2>Horario completo</h2>
        <div class="daypick" role="group" aria-label="Día de la semana">
            <button type="button" id="pick-laborable" aria-pressed="true">Lunes a viernes</button>
            <button type="button" id="pick-finde" aria-pressed="false">Sábados y domingos</button>
        </div>

{direction_block('valencia', 'Hacia València Nord')}

{direction_block('moixent', 'Hacia Xàtiva', '<p class="note">Todos pasan por Xàtiva; algunos siguen hasta L&#39;Alcúdia de Crespins.</p>')}

        <h2>Bus urbano desde la estación</h2>
        <p>Las tres líneas del bus urbano paran en la <a href="/paradas/1-estacio-renfe/">parada Estació RENFE</a>, delante de la estación:</p>
        <div class="card">
            <p><span class="line-badge" style="background:#1565C0">L1</span> Cada 30 minutos en laborables, de 06:30 a 21:30, y enlaza con los últimos trenes hasta las 23:10. Sábados, cada hora. <a href="/lineas/l1/">Ver la L1</a></p>
            <p><span class="line-badge" style="background:#2E7D32">L2</span> Cada hora en laborables, de 06:45 a 20:45. También sábados, domingos y festivos. <a href="/lineas/l2/">Ver la L2</a></p>
            <p><span class="line-badge" style="background:#E65100">L3</span> Cada hora en laborables de septiembre a junio, de 07:15 a 20:15. <a href="/lineas/l3/">Ver la L3</a></p>
        </div>
        <p>Si llegas en tren y quieres ir al centro o al Hospital de la Ribera, la L1 es la más frecuente. Tienes las salidas exactas de cada línea en <a href="/horarios/">horarios</a>, y el tiempo de paso real del siguiente autobús en la app.</p>

        <h2>Preguntas frecuentes</h2>
{faq_html}

        <div class="cta">
            <h2>¿Llega tu bus a tiempo para el tren?</h2>
            <p>Mira cuántos minutos faltan para el próximo autobús en tu parada y activa un aviso cuando esté llegando.</p>
            <a href="/#descarga" class="btn">Descargar app</a>
            <a href="/app/" class="btn">Abrir versión web</a>
        </div>
        <p class="fiabilidad" style="font-size:13px; color:var(--text-muted); border-top:1px solid var(--border); padding-top:14px; margin-top:28px;">Horarios de tren: <a href="https://data.renfe.com/dataset/horarios-cercanias" rel="noopener" target="_blank">datos abiertos de Renfe</a> (horario programado vigente {VALID_TXT}; los retrasos y cancelaciones se consultan en directo a Renfe). Horarios de bus: los publicados por el servicio urbano de autobús de Alzira. Página actualizada el <time datetime="{UPDATED_ISO}">{UPDATED_TXT}</time>. Alzitrans es un proyecto independiente, sin relación con Renfe. ¿Ves un error? <a href="/sobre/#contacto">Avísanos</a>.</p>
    </main>

    <footer>
        <p>Alzitrans es una aplicación independiente para consultar información del bus urbano de Alzira. No es un servicio oficial de la empresa concesionaria.</p>
        <p style="margin-top:8px">
            <a href="/">Inicio</a> ·
            <a href="/horarios/">Horarios</a> ·
            <a href="/lineas/">Líneas</a> ·
            <a href="/paradas/">Paradas</a> ·
            <a href="/sobre/">Sobre el proyecto</a> ·
            <a href="/legal/privacidad.html">Privacidad</a> ·
            <a href="/legal/cookies.html">Cookies</a> ·
            <a href="#" onclick="return window.alzitransCookies &amp;&amp; window.alzitransCookies.open(), false;">Configurar cookies</a>
        </p>
    </footer>

    <script>
    // Próximos trenes y horario del día de hoy (hora de Madrid). Sin esto la
    // página sigue mostrando el horario completo de lunes a viernes.
    (function () {{
        var DATA = {js_data};
        var DEST = {{ valencia: 'Hacia València Nord', moixent: 'Hacia Xàtiva' }};

        function madridNow() {{
            var parts = new Intl.DateTimeFormat('es-ES', {{ timeZone: 'Europe/Madrid', weekday: 'short', hour: '2-digit', minute: '2-digit', hour12: false }}).formatToParts(new Date());
            var o = {{}};
            parts.forEach(function (p) {{ o[p.type] = p.value; }});
            var wd = o.weekday.toLowerCase();
            return {{ min: parseInt(o.hour, 10) % 24 * 60 + parseInt(o.minute, 10), weekend: wd.indexOf('sáb') === 0 || wd.indexOf('dom') === 0, sat: wd.indexOf('sáb') === 0, sun: wd.indexOf('dom') === 0 }};
        }}
        function toMin(t) {{ return parseInt(t.slice(0, 2), 10) * 60 + parseInt(t.slice(3, 5), 10); }}
        function esc(s) {{ return String(s).replace(/[&<>]/g, function (c) {{ return {{ '&': '&amp;', '<': '&lt;', '>': '&gt;' }}[c]; }}); }}

        var now = madridNow();
        var today = now.weekend ? 'finde' : 'laborable';
        // Mañana: el viernes pasa a fin de semana; el domingo, a laborable.
        var tomorrow = now.sun ? 'laborable' : (now.sat ? 'finde' : (new Intl.DateTimeFormat('es-ES', {{ timeZone: 'Europe/Madrid', weekday: 'short' }}).format(new Date()).toLowerCase().indexOf('vie') === 0 ? 'finde' : 'laborable'));

        function waitText(min) {{
            if (min <= 0) return 'Sale ahora';
            if (min < 60) return 'Sale en ' + min + ' min';
            return 'Sale en ' + Math.floor(min / 60) + ' h ' + (min % 60) + ' min';
        }}
        function hhmm(m) {{ m = ((m % 1440) + 1440) % 1440; return ('0' + Math.floor(m / 60)).slice(-2) + ':' + ('0' + (m % 60)).slice(-2); }}

        // 1) Horario programado (sin conexión al backend también funciona)
        function renderStatic() {{
            var now = madridNow(), html = '';
            ['valencia', 'moixent'].forEach(function (dir) {{
                var next = DATA[today][dir].filter(function (t) {{ return toMin(t) >= now.min; }});
                if (next.length) {{
                    var after = next.slice(1, 3);
                    html += '<div class="next-card"><p class="to">' + DEST[dir] + '</p><p class="when">' + next[0] + '</p><p class="in">' + waitText(toMin(next[0]) - now.min) + '</p>' +
                        (after.length ? '<p class="after">Después: ' + after.join(' y ') + '</p>' : '<p class="after">Es el último tren de hoy.</p>') + '</div>';
                }} else {{
                    html += '<div class="next-card"><p class="to">' + DEST[dir] + '</p><p class="when">' + DATA[tomorrow][dir][0] + '</p><p class="in">Mañana</p><p class="after">Hoy ya no quedan trenes en este sentido.</p></div>';
                }}
            }});
            document.getElementById('next').innerHTML = html;
            document.getElementById('next-hint').textContent = 'Horario programado de ' + (today === 'finde' ? 'fin de semana' : 'lunes a viernes') + '. En festivos puede cambiar.';
        }}

        // 2) En directo: retrasos y cancelaciones de Renfe vía /api/trains/alzira
        function badge(t) {{
            if (t.canceled) return '<span class="st st-bad">Cancelado</span>';
            // Sin dato en directo (el tren aún no ha salido de origen): sin etiqueta.
            if (!t.live) return '';
            if (t.delayMin > 0) return '<span class="st st-late">+' + t.delayMin + ' min</span>';
            return '<span class="st st-ok">En hora</span>';
        }}
        function renderLive(api) {{
            var now = madridNow(), html = '';
            [['valencia', 'valencia'], ['moixent', 'xativa']].forEach(function (k) {{
                var list = api.directions[k[1]] || [];
                var main = list.filter(function (t) {{ return !t.canceled; }})[0];
                var canceledBefore = main ? list.filter(function (t) {{ return t.canceled && toMin(t.scheduled) < toMin(main.scheduled); }}) : list;
                html += '<div class="next-card"><p class="to">' + DEST[k[0]] + '</p>';
                if (main) {{
                    var est = toMin(main.scheduled) + Math.max(main.delayMin, 0);
                    html += '<p class="when">' + (main.delayMin > 0 ? '<s>' + main.scheduled + '</s> ' + hhmm(est) : main.scheduled) + ' ' + badge(main) + '</p>' +
                        '<p class="in">' + waitText(est - now.min) + '</p>';
                    var after = list.filter(function (t) {{ return toMin(t.scheduled) > toMin(main.scheduled); }}).slice(0, 2);
                    if (after.length) html += '<p class="after">Después: ' + after.map(function (t) {{ return t.scheduled + ' ' + badge(t); }}).join(' · ') + '</p>';
                }} else {{
                    html += '<p class="when">' + DATA[tomorrow][k[0]][0] + '</p><p class="in">Mañana</p><p class="after">Hoy ya no quedan trenes en este sentido.</p>';
                }}
                canceledBefore.forEach(function (t) {{ html += '<p class="after bad">El tren de las ' + t.scheduled + ' está cancelado.</p>'; }});
                html += '</div>';
            }});
            document.getElementById('next').innerHTML = html;
            var at = api.feedTimestamp ? new Date(api.feedTimestamp * 1000).toLocaleTimeString('es-ES', {{ timeZone: 'Europe/Madrid', hour: '2-digit', minute: '2-digit' }}) : '';
            document.getElementById('next-hint').textContent = api.realtime
                ? 'En directo con datos de Renfe' + (at ? ' (actualizado a las ' + at + ')' : '') + '. Se refresca cada minuto.'
                : 'Horario programado: ahora mismo no llegan los datos en directo de Renfe.';
            var box = document.getElementById('alerts');
            box.innerHTML = (api.alerts || []).map(function (a) {{ return '<p class="alert">⚠ ' + esc(a) + '</p>'; }}).join('');
        }}

        function refresh() {{
            fetch('/api/trains/alzira', {{ cache: 'no-store' }})
                .then(function (r) {{ return r.ok ? r.json() : null; }})
                .then(function (api) {{ if (api && api.ok) renderLive(api); else renderStatic(); }})
                .catch(renderStatic);
        }}
        renderStatic();
        refresh();
        setInterval(refresh, 60 * 1000);

        function show(which) {{
            document.querySelectorAll('.day-laborable').forEach(function (el) {{ el.hidden = which !== 'laborable'; }});
            document.querySelectorAll('.day-finde').forEach(function (el) {{ el.hidden = which !== 'finde'; }});
            document.getElementById('pick-laborable').setAttribute('aria-pressed', which === 'laborable');
            document.getElementById('pick-finde').setAttribute('aria-pressed', which === 'finde');
        }}
        document.getElementById('pick-laborable').addEventListener('click', function () {{ show('laborable'); }});
        document.getElementById('pick-finde').addEventListener('click', function () {{ show('finde'); }});
        show(today);

        // Atenúa los trenes que ya han salido hoy
        document.querySelectorAll('.day-' + today + ' ul.times li').forEach(function (li) {{
            if (toMin(li.textContent) < now.min) li.classList.add('gone');
        }});
    }})();
    </script>
</body>
</html>
"""
OUT.parent.mkdir(parents=True, exist_ok=True)
OUT.write_text(html, encoding="utf-8")
print("ok", OUT, "| Xàtiva destinos:", dest_x, "| cortos a L'Alcúdia:", len(short_x))
