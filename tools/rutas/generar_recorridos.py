"""Genera los recorridos por calles de las líneas (assets/routes/Lx_gps.json)
a partir del orden de paradas de assets/routes/Lx.json, usando OSRM sobre
datos de OpenStreetMap (© colaboradores de OpenStreetMap, ODbL).

Se ejecuta a mano, una vez, cuando cambian las paradas o el recorrido:
    python tools/rutas/generar_recorridos.py            # genera L1, L2 y L3
    python tools/rutas/generar_recorridos.py --check     # solo valida los actuales

Validación (falla si no se cumple):
  - cada parada a menos de MAX_DIST_M del recorrido;
  - las paradas aparecen en orden creciente a lo largo del recorrido;
  - el recorrido es cerrado (la línea es circular).
"""
import json
import math
import sys
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ROUTES = ROOT / "assets" / "routes"
LINES = ["L1", "L2", "L3"]
OSRM = "https://router.project-osrm.org/route/v1/driving/"
MAX_DIST_M = 40

# Paradas que la línea hace solo en algunas expediciones: la parada existe y
# tiene servicio, pero la mayoría de buses no entran, así que no se dibujan en
# el recorrido simulado (si no, el bus haría un desvío que no hace).
# L1 / 18 AV. DELS ESPORTS-CIPFP LLUIS SUÑER: el 3/11 a las 17:27 y a las 18:27
# el operador daba Av. Mediterrània -> Pare Pompili en 1-2 min (2,85 km con el
# desvío: imposible) y para CIPFP el bus de ~21:30. El mapa oficial dibuja el
# recorrido completo, pero no qué expediciones entran.
VARIANT_STOPS = {"L1": {18}}


def dist(a, b):
    r = 6371000
    la1, lo1, la2, lo2 = map(math.radians, (a[0], a[1], b[0], b[1]))
    x = (lo2 - lo1) * math.cos((la1 + la2) / 2)
    return r * math.hypot(x, la2 - la1)


def project(p, a, b):
    """Distancia de p al segmento ab y fracción t del punto proyectado."""
    k = math.cos(math.radians(a[0]))
    ax, ay, bx, by, px, py = a[1] * k, a[0], b[1] * k, b[0], p[1] * k, p[0]
    dx, dy = bx - ax, by - ay
    l2 = dx * dx + dy * dy
    t = 0.0 if l2 == 0 else max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy) / l2))
    q = (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)
    return dist(p, q), t


def validate(line, stops, track):
    cum = [0.0]
    for i in range(len(track) - 1):
        cum.append(cum[-1] + dist(track[i], track[i + 1]))
    total = cum[-1]
    errors, along, last = [], [], -1.0
    for s in stops:
        p = (s["lat"], s["lng"])
        # Se busca hacia delante desde la parada anterior y se toma el PRIMER
        # paso cerca de la parada (el recorrido puede pasar dos veces por la
        # misma calle); si no hay ninguno cerca, el más cercano para el aviso.
        best = nearest = None
        for i in range(len(track) - 1):
            d, t = project(p, track[i], track[i + 1])
            pos = cum[i] + t * (cum[i + 1] - cum[i])
            if pos + 1 < last:
                continue
            if nearest is None or d < nearest[0]:
                nearest = (d, pos)
            if d <= MAX_DIST_M:
                if best is None or d < best[0]:
                    best = (d, pos)
            elif best is not None:
                break  # se acabó el primer paso cerca de la parada
        best = best or nearest
        if best is None:
            errors.append(f"parada {s['id']} {s['name']}: no aparece después de la anterior")
            continue
        d, pos = best
        if d > MAX_DIST_M:
            errors.append(f"parada {s['id']} {s['name']}: a {d:.0f} m del recorrido")
        along.append(round(pos))
        last = pos
    gap = dist(track[0], track[-1])
    if gap > MAX_DIST_M:
        errors.append(f"el recorrido no es cerrado ({gap:.0f} m entre el final y el principio)")
    return total, along, errors


def osrm(pts, approaches, overview):
    coords = ";".join(f"{s['lng']},{s['lat']}" for s in pts)
    url = f"{OSRM}{coords}?overview={overview}&geometries=geojson&steps=false&approaches={';'.join(approaches)}"
    req = urllib.request.Request(url, headers={"User-Agent": "Alzitrans-generador-recorridos/1.0 (+https://alzitrans.es)"})
    with urllib.request.urlopen(req, timeout=60) as r:
        data = json.load(r)
    if data.get("code") != "Ok":
        raise RuntimeError(f"OSRM respondió {data.get('code')}: {data.get('message')}")
    return data["routes"][0]


def route_stops(line):
    stops = json.loads((ROUTES / f"{line}.json").read_text(encoding="utf-8"))
    return [s for s in stops if s["id"] not in VARIANT_STOPS.get(line, set())]


def generate(line):
    stops = route_stops(line)
    pts = stops + [stops[0]]  # vuelta completa
    # curb: llegar a cada parada por su lado de la calle (la derecha). Si en un
    # tramo eso obliga a dar una vuelta a la manzana de más de 250 m, en esa
    # parada se deja libre (OSRM a veces inventa rodeos para cambiar de acera).
    curb = [l["distance"] for l in osrm(pts, ["curb"] * len(pts), "false")["legs"]]
    free = [l["distance"] for l in osrm(pts, ["unrestricted"] * len(pts), "false")["legs"]]
    approaches = ["curb"] + ["unrestricted" if curb[i] - free[i] > 250 else "curb" for i in range(len(curb))]
    geom = osrm(pts, approaches, "full")["geometry"]["coordinates"]
    track = [{"lat": round(lat, 6), "lng": round(lng, 6)} for lng, lat in geom]
    # Quitar puntos repetidos consecutivos.
    clean = [track[0]]
    for p in track[1:]:
        if p != clean[-1]:
            clean.append(p)
    return stops, clean


def main():
    check_only = "--check" in sys.argv
    failed = False
    for line in LINES:
        if check_only:
            stops = route_stops(line)
            track = json.loads((ROUTES / f"{line}_gps.json").read_text(encoding="utf-8"))
        else:
            stops, track = generate(line)
        tr = [(p["lat"], p["lng"]) for p in track]
        total, along, errors = validate(line, stops, tr)
        print(f"{line}: {len(stops)} paradas, {len(track)} puntos, {total / 1000:.2f} km")
        for e in errors:
            print(f"   ERROR {e}")
        if errors:
            failed = True
        elif not check_only:
            (ROUTES / f"{line}_gps.json").write_text(json.dumps(track, ensure_ascii=False), encoding="utf-8")
            print("   guardado")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
