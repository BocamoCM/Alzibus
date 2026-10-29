"""Actualiza los horarios de Cercanías C2 en Alzira a partir del GTFS abierto
de Renfe.

Genera:
  - backend/data/renfe_c2_alzira.json  → trenes por fecha, para /api/trains/alzira
  - website/estacion-renfe/index.html   → página con el horario (vía pagina.py)

Cuándo ejecutarlo: Renfe publica el GTFS con ~1 mes de vigencia. El endpoint
devuelve {"ok": false, "reason": "schedule_expired"} cuando se acaba; conviene
ejecutarlo antes, una vez al mes, y luego desplegar backend + web.

Uso (desde la raíz del repo):
  python tools/renfe/actualizar_c2.py
Fuente: https://data.renfe.com/dataset/horarios-cercanias
"""
import csv
import datetime as dt
import io
import json
import subprocess
import sys
import tempfile
import urllib.request
import zipfile
from pathlib import Path

GTFS_URL = "https://ssl.renfe.com/ftransit/Fichero_CER_FOMENTO/fomento_transit.zip"
ALZIRA = "64104"
ROOT = Path(__file__).resolve().parents[2]
DATA_OUT = ROOT / "backend" / "data" / "renfe_c2_alzira.json"
PAGE_OUT = ROOT / "website" / "estacion-renfe" / "index.html"
WEEKDAYS = ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"]


def rows(z, name):
    with z.open(name) as f:
        for r in csv.DictReader(io.TextIOWrapper(f, encoding="utf-8-sig")):
            yield {k.strip(): (v or "").strip() for k, v in r.items()}


def parse_date(s):
    return dt.date(int(s[:4]), int(s[4:6]), int(s[6:]))


def main():
    with tempfile.TemporaryDirectory() as tmp:
        zpath = Path(tmp) / "fomento_transit.zip"
        print("Descargando", GTFS_URL)
        urllib.request.urlretrieve(GTFS_URL, zpath)
        z = zipfile.ZipFile(zpath)

        names = {s["stop_id"]: s["stop_name"] for s in rows(z, "stops.txt")}
        assert names.get(ALZIRA) == "Alzira", f"la parada {ALZIRA} ya no es Alzira: {names.get(ALZIRA)}"

        # Hora de paso por Alzira de cada viaje + primera/última parada
        at_alz, ends = {}, {}
        for st in rows(z, "stop_times.txt"):
            tid, seq = st["trip_id"], int(st["stop_sequence"])
            if st["stop_id"] == ALZIRA:
                at_alz[tid] = st["departure_time"][:5]
            lo, hi = ends.get(tid, (None, None))
            if lo is None or seq < lo[0]:
                lo = (seq, st["stop_id"])
            if hi is None or seq > hi[0]:
                hi = (seq, st["stop_id"])
            ends[tid] = (lo, hi)

        trips = []
        for t in rows(z, "trips.txt"):
            if t["trip_id"] not in at_alz:
                continue
            # 40T0006C2 = Moixent → València; 40T0005C2 = València → Moixent
            direction = "valencia" if t["route_id"].endswith("6C2") else "xativa"
            lo, hi = ends[t["trip_id"]]
            trips.append({"trip": t["trip_id"], "service": t["service_id"], "dep": at_alz[t["trip_id"]],
                          "dir": direction, "from": names.get(lo[1], lo[1]), "to": names.get(hi[1], hi[1])})
        services = {t["service"] for t in trips}
        cal = {c["service_id"]: c for c in rows(z, "calendar.txt") if c["service_id"] in services}
        z.close()  # en Windows, si sigue abierto no se puede borrar la carpeta temporal

    first = min(parse_date(c["start_date"]) for c in cal.values())
    last = max(parse_date(c["end_date"]) for c in cal.values())

    def on(day):
        out = []
        for t in trips:
            c = cal.get(t["service"])
            if c and parse_date(c["start_date"]) <= day <= parse_date(c["end_date"]) and c[WEEKDAYS[day.weekday()]] == "1":
                out.append(t)
        return sorted(out, key=lambda t: t["dep"])

    days, day = {}, first
    while day <= last:
        days[day.isoformat()] = [[t["trip"], t["dep"], t["dir"]] for t in on(day)]
        day += dt.timedelta(days=1)

    DATA_OUT.parent.mkdir(parents=True, exist_ok=True)
    DATA_OUT.write_text(json.dumps({
        "source": GTFS_URL,
        "generated": dt.date.today().isoformat(),
        "validFrom": first.isoformat(),
        "validUntil": last.isoformat(),
        "days": days,
    }, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    print(f"{DATA_OUT.relative_to(ROOT)}: {len(days)} días ({first} → {last})")

    # Días tipo para la página: el próximo martes y el próximo sábado/domingo
    def next_weekday(wd):
        d = max(first, dt.date.today())
        while d.weekday() != wd:
            d += dt.timedelta(days=1)
        return d

    def tipo(day):
        out = {"valencia": [], "moixent": []}
        for t in on(day):
            out["valencia" if t["dir"] == "valencia" else "moixent"].append([t["dep"], t["from"], t["to"]])
        return out

    tipo_json = {"laborable": tipo(next_weekday(1)), "sabado": tipo(next_weekday(5)), "domingo": tipo(next_weekday(6))}
    if tipo_json["sabado"] != tipo_json["domingo"]:
        print("AVISO: sábado y domingo ya no coinciden; la página los muestra juntos. Revisa pagina.py.")
    with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False, encoding="utf-8") as f:
        json.dump(tipo_json, f, ensure_ascii=False)
    subprocess.run([sys.executable, str(Path(__file__).with_name("pagina.py")), f.name, str(PAGE_OUT),
                    dt.date.today().isoformat(), last.isoformat()], check=True)
    Path(f.name).unlink()


if __name__ == "__main__":
    main()
