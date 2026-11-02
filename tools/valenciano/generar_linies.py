"""Genera las páginas de línea en valenciano (website/va/linies/lX/) a partir
de las páginas en castellano (website/lineas/lX/), y enlaza ambas versiones
con hreflang.

Las páginas de línea siguen una plantilla fija: se traducen sus frases (no los
nombres de parada, que son los oficiales). Si se cambia una página de línea en
castellano, volver a ejecutar este script. Al final comprueba que no quede
ningún texto de la plantilla sin traducir y avisa si lo encuentra.

Uso (desde la raíz del repo):  python tools/valenciano/generar_linies.py
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
WEB = ROOT / "website"
TODAY_ISO, TODAY_VA = "2026-11-02", "2 de novembre de 2026"

LEADS = {
    "L1": "La L1 és la línia més freqüent de l'autobús d'Alzira: uneix l'Hospital de la Ribera i l'Estació de RENFE cada 30 minuts els dies feiners, amb 26 parades. També és la que enllaça amb els últims trens de la nit.",
    "L2": "La L2 uneix l'Hospital de la Ribera i l'Estació de RENFE cada hora, per un recorregut de 30 parades, el més llarg de les tres línies. Funciona tot l'any, també dissabtes, diumenges i festius.",
    "L3": "La L3 fa un recorregut de 18 parades entre l'Hospital de la Ribera i l'Estació de RENFE, amb una eixida cada hora. Només circula els dies feiners de setembre a juny: a l'estiu i el cap de setmana no hi ha servei.",
}
DESCS = {
    "L1": "La L1 de l'autobús d'Alzira uneix l'Hospital de la Ribera i l'Estació de RENFE cada 30 minuts els dies feiners. Horari, 26 parades i mapa.",
    "L2": "La L2 de l'autobús d'Alzira uneix l'Hospital de la Ribera i l'Estació de RENFE cada hora, també dissabtes i festius. Horari, 30 parades i mapa.",
    "L3": "La L3 de l'autobús d'Alzira passa cada hora els dies feiners de setembre a juny. Consulta'n l'horari, les 18 parades i el mapa.",
}
MIDS = {  # frase central de "La LX conecta el Hospital con la Estación RENFE. … Estas son sus franjas"
    "La L1 pasa aproximadamente cada 30 minutos en días laborables (cada hora en verano y festivos).":
        "La L1 passa aproximadament cada 30 minuts els dies feiners (cada hora a l'estiu i en festius).",
    "La L2 pasa cada hora.": "La L2 passa cada hora.",
    "La L3 circula cada hora, solo en días laborables de septiembre a junio.":
        "La L3 circula cada hora, només els dies feiners de setembre a juny.",
}

# Sustituciones literales del cuerpo, de la más larga a la más corta.
LITERAL = [
    ("Alzitrans es una aplicación independiente para consultar información del bus urbano de Alzira. No es un servicio oficial de la empresa concesionaria.",
     "Alzitrans és una aplicació independent per a consultar informació de l'autobús urbà d'Alzira. No és un servici oficial de l'empresa concessionària."),
    ("La parada 18 (Avenida dels Esports – CIPFP Lluís Suñer) solo se atiende en las salidas desde el Hospital a las 07:55, 08:25, 14:25 y 21:25, en días lectivos.",
     "La parada 18 (Avinguda dels Esports – CIPFP Lluís Suñer) només s'atén en les eixides des de l'Hospital de les 07:55, 08:25, 14:25 i 21:25, en dies lectius."),
    ("La L3 circula únicamente en días laborables de septiembre a junio; no hay servicio en julio, agosto ni fines de semana.",
     "La L3 només circula els dies feiners de setembre a juny; no hi ha servei al juliol, a l'agost ni el cap de setmana."),
    ("Para conocer el tiempo de llegada del siguiente autobús a una parada concreta, abre la app Alzitrans (gratis en Google Play) o accede a la versión web en",
     "Per a saber quan arriba el pròxim autobús a una parada concreta, obri l'app Alzitrans (gratis en Google Play) o entra en la versió web en"),
    ("o el tiempo de paso en tiempo real por parada en la app Alzitrans.",
     "o el temps de pas en temps real per parada en l'app Alzitrans."),
    ("Viernes Santo, Navidad y 1 de enero: por la tarde no hay servicio.",
     "Divendres Sant, Nadal i 1 de gener: per la vesprada no hi ha servei."),
    ("tarifas y los horarios de todas las líneas", "tarifes i els horaris de totes les línies"),
    ("¿Cuándo pasa el siguiente bus?", "Quan passa el pròxim autobús?"),
    (". Los datos se actualizan en tiempo real.", ". Les dades s'actualitzen en temps real."),
    ("Salidas desde la Estación RENFE", "Eixides des de l'Estació de RENFE"),
    ("Salidas desde el Hospital", "Eixides des de l'Hospital"),
    ("Laborables (septiembre a junio)", "Feiners (de setembre a juny)"),
    ("Enlaza con los últimos trenes hasta las", "Enllaça amb els últims trens fins a les"),
    ("Enlaza con el tren de las", "Enllaça amb el tren de les"),
    ("cada hora hasta las", "cada hora fins a les"),
    ("Desde las", "Des de les"),
    ("Cada 30 minutos", "Cada 30 minuts"),
    ("Consulta también las", "Consulta també les"),
    ("Domingos y festivos", "Diumenges i festius"),
    ("Abrir versión web", "Obrir la versió web"),
    ("Descargar app", "Descarregar l'app"),
    ("Otras líneas:", "Altres línies:"),
    (">Sobre el proyecto<", ">Sobre el projecte<"),
    (">Configurar cookies<", ">Configurar les galetes<"),
    (">Privacidad<", ">Privacitat<"),
    (">Cookies<", ">Galetes<"),
    (">Términos<", ">Termes<"),
    (">Inicio<", ">Inici<"),
    (">Líneas<", ">Línies<"),
    (">Sábados<", ">Dissabtes<"),
    (">Julio<", ">Juliol<"),
    (">Agosto<", ">Agost<"),
    ("'Ver parada'", "'Veure la parada'"),
    (">Ver parada<", ">Veure la parada<"),
]
REGEX = [
    (r"El tren de las (\d\d:\d\d) se reparte desde Pza\. Reino por la línea 1\.",
     r"El tren de les \1 el reparteix la línia 1 des de la pl. del Regne."),
    (r"El de las (\d\d:\d\d) se reparte desde Pl\. Reino por la línea 3\.",
     r"El de les \1 el reparteix la línia 3 des de la pl. del Regne."),
    (r"Cada hora de (\d\d:\d\d) a (\d\d:\d\d), y de", r"Cada hora de \1 a \2, i de"),
    (r"(\d\d:\d\d) y (\d\d:\d\d)", r"\1 i \2"),
    (r"Mira el horario completo de la (L\d) más arriba, o consulta el tiempo de paso del próximo bus en tiempo real desde la app Alzitrans o la versión web\.",
     r"Mira l'horari complet de la \1 més amunt, o consulta el temps de pas del pròxim autobús en temps real des de l'app Alzitrans o la versió web."),
    (r"La línea (L\d) es una de las tres líneas que componen la red del autobús urbano de Alzira \(Valencia\), junto con la",
     r"La línia \1 és una de les tres línies que formen la xarxa de l'autobús urbà d'Alzira (València), juntament amb la"),
    (r"</a> y la <a", r"</a> i la <a"),
    (r"\. Cubre (\d+) paradas en total\.", r". Cobreix \1 parades en total."),
    (r"Mapa con el recorrido de la línea (L\d)", r"Mapa amb el recorregut de la línia \1"),
    (r"Todas las paradas de la línea (L\d)", r"Totes les parades de la línia \1"),
    (r"Horario de la línea (L\d)", r"Horari de la línia \1"),
    (r"Sobre la línea (L\d)", r"Sobre la línia \1"),
    (r"Línea (L\d): bus urbano de Alzira", r"Línia \1: autobús urbà d'Alzira"),
    (r"Línea (L\d)", r"Línia \1"),
    (r'Horarios basados en los publicados por el servicio urbano de autobús de Alzira\. Página actualizada el <time datetime="[^"]+">[^<]+</time>\. Alzitrans es un proyecto independiente\. ¿Ves un error\? <a href="/sobre/#contacto">Avísanos</a>\.',
     f"Horaris basats en els publicats pel servici urbà d'autobús d'Alzira. Pàgina actualitzada el <time datetime=\"{TODAY_ISO}\">{TODAY_VA}</time>. Alzitrans és un projecte independent. Hi veus un error? <a href=\"/sobre/#contacto\">Avisa'ns</a>."),
]
# Restos que delatan castellano sin traducir en el texto visible.
SPANISH_MARKERS = re.compile(r"\b(Horario|minutos|paradas|Salidas|desde|también|Laborables|Línea|línea|siguiente|tiempo de paso|Inicio|Descargar|Abrir|proyecto|aplicación)\b")


def hreflang(es_url, va_url):
    return (f'    <link rel="alternate" hreflang="es" href="{es_url}">\n'
            f'    <link rel="alternate" hreflang="ca" href="{va_url}">\n'
            f'    <link rel="alternate" hreflang="x-default" href="{es_url}">\n')


def read(p):
    raw = p.read_bytes().decode("utf-8")
    return raw.replace("\r\n", "\n"), "\r\n" in raw


def write(p, text, crlf):
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_bytes((text.replace("\n", "\r\n") if crlf else text).encode("utf-8"))


problems = []
for code in ("l1", "l2", "l3"):
    L = code.upper()
    es_path = WEB / "lineas" / code / "index.html"
    es_url, va_url = f"https://alzitrans.es/lineas/{code}/", f"https://alzitrans.es/va/linies/{code}/"
    t, crlf = read(es_path)
    n = int(re.search(r"Cubre (\d+) paradas", t).group(1))

    # ── Versión en castellano: hreflang + enlace al valenciano ──
    es = t
    if 'hreflang="ca"' not in es:
        es = es.replace(f'<link rel="canonical" href="{es_url}">', f'<link rel="canonical" href="{es_url}">\n' + hreflang(es_url, va_url).rstrip("\n"), 1)
    if "Llegir en valencià" not in es:
        es = re.sub(r"(<nav class=\"breadcrumb\">.*?</nav>)",
                    lambda m: m.group(1) + f'\n        <p style="margin:-14px 0 18px; font-size:13px"><a href="/va/linies/{code}/" hreflang="ca" lang="ca">Llegir en valencià</a></p>',
                    es, count=1, flags=re.S)
    if es != t:
        write(es_path, es, crlf)

    # ── Versión en valenciano ──
    va = t
    head, body = va.split("</head>", 1)
    head = head.replace('<html lang="es">', '<html lang="ca-ES-valencia">')
    head = re.sub(r"<title>.*?</title>", f"<title>Línia {L} autobús Alzira: horari, parades i mapa | Alzitrans</title>", head, count=1, flags=re.S)
    head = re.sub(r'(<meta name="description" content=")[^"]*', lambda m: m.group(1) + DESCS[L], head, count=1)
    for attr in ('property="og:title"', 'name="twitter:title"'):
        head = re.sub(r'(<meta ' + attr + r' content=")[^"]*', lambda m: m.group(1) + f"Línia {L} autobús Alzira: horari, parades i mapa | Alzitrans", head, count=1)
    og_desc = f"Recorregut complet i totes les parades de la línia {L} de l'autobús urbà d'Alzira. {n} parades. Consulta els temps en temps real en l'app Alzitrans."
    for attr in ('property="og:description"', 'name="twitter:description"'):
        head = re.sub(r'(<meta ' + attr + r' content=")[^"]*', lambda m: m.group(1) + og_desc, head, count=1)
    head = head.replace(f'<link rel="canonical" href="{es_url}">', f'<link rel="canonical" href="{va_url}">', 1)
    head = re.sub(r'\n\s*<link rel="alternate" hreflang="[^"]+" href="[^"]+">', "", head)
    head = head.replace(f'<link rel="canonical" href="{va_url}">', f'<link rel="canonical" href="{va_url}">\n' + hreflang(es_url, va_url).rstrip("\n"), 1)
    head = head.replace(f'content="{es_url}"', f'content="{va_url}"')
    head = head.replace('<meta property="og:locale" content="es_ES">', '<meta property="og:locale" content="ca_ES">\n    <meta property="og:locale:alternate" content="es_ES">')
    head = head.replace(f'"Línea {L} - Bus urbano de Alzira"', f'"Línia {L} - Autobús urbà d\'Alzira"')
    head = head.replace(f'"Recorrido de la línea {L} del autobús urbano de Alzira con {n} paradas."', f'"Recorregut de la línia {L} de l\'autobús urbà d\'Alzira amb {n} parades."')
    head = head.replace('"name": "Inicio"', '"name": "Inici"').replace('"name": "Líneas"', '"name": "Línies"').replace(f'"name": "Línea {L}"', f'"name": "Línia {L}"')
    head = head.replace(f'"item": "{es_url}"', f'"item": "{va_url}"')

    body = re.sub(r'<p class="lead">.*?</p>', f'<p class="lead">{LEADS[L]}</p>', body, count=1, flags=re.S)
    m = re.search(r"La (L\d) conecta el <strong>Hospital de la Ribera</strong> con la <strong>Estación RENFE</strong>\. (.*?) Estas son sus franjas de servicio:", body)
    if m:
        body = body.replace(m.group(0), f"La {L} connecta l'<strong>Hospital de la Ribera</strong> amb l'<strong>Estació de RENFE</strong>. {MIDS[m.group(2)]} Estes són les seues franges de servei:")
    body = re.sub(r'<p style="margin:-14px 0 18px; font-size:13px"><a href="/va/linies/l\d/"[^>]*>Llegir en valencià</a></p>',
                  f'<p style="margin:-14px 0 18px; font-size:13px"><a href="/lineas/{code}/" hreflang="es" lang="es">Leer en castellano</a></p>', body)
    for a, b in LITERAL:
        body = body.replace(a, b)
    for a, b in REGEX:
        body = re.sub(a, b, body)
    body = re.sub(r'href="/lineas/(l\d)/"', r'href="/va/linies/\1/"', body)
    body = body.replace('href="/horarios/"', 'href="/va/horaris/"')
    # El enlace "Leer en castellano" debe seguir apuntando a la versión en castellano
    body = body.replace(f'<a href="/va/linies/{code}/" hreflang="es" lang="es">Leer en castellano</a>', f'<a href="/lineas/{code}/" hreflang="es" lang="es">Leer en castellano</a>')
    va = head + "</head>" + body
    write(WEB / "va" / "linies" / code / "index.html", va, crlf)

    visible = re.sub(r"(?s)<(script|style).*?</\1>", "", body)
    visible = re.sub(r"<[^>]+>", "\n", visible)
    for line in visible.splitlines():
        if SPANISH_MARKERS.search(line):
            problems.append(f"{code}: {line.strip()[:120]}")
    print(f"ok {code}: /va/linies/{code}/ ({n} parades)")

if problems:
    print("\nAVISO, texto posiblemente sin traducir:")
    print("\n".join(problems))
    sys.exit(1)
