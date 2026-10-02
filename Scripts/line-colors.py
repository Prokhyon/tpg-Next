#!/usr/bin/env python3
"""Régénère tpgNextFunc/Stops Database/LineColors.json : la couleur de chaque ligne de Lines.json.

Aucun jeu de données national ne donne les couleurs des lignes. Trois sources, par ordre de priorité :

1. Scripts/line-colors-manual.csv : les couleurs relevées à la main (colonne « color », « E20A16 »).
   Le script réécrit ce fichier à chaque passage : il garde les couleurs saisies et y ajoute
   les lignes restées sans couleur, colonne vide, pour qu'on les complète.
2. search.ch : ses tableaux de départs donnent la couleur de chaque course (« e20a16~fff~ » :
   fond, texte). C'est la palette des transporteurs (ZVV, tpg…). Les arrêts à interroger sont
   tirés de l'horaire GTFS : pour chaque ligne, quelques courses et leurs arrêts, puis le plus
   petit jeu d'arrêts qui couvre toutes les lignes. Limite de l'API : 10 080 tableaux par jour ;
   les réponses sont gardées en cache, un second passage ne redemande rien.
3. OpenStreetMap : l'étiquette « colour » des lignes. Données sous licence ODbL :
   « © les contributeurs d'OpenStreetMap » doit figurer dans l'app.

Enfin, un transporteur dont toutes les lignes trouvées ont la même couleur (CarPostal) la
donne aux autres.

À relancer avec les autres scripts (Scripts/update-data.sh), après lines-from-atlas.py :

    python3 Scripts/line-colors.py [--gtfs fichier.zip] [--cache dossier]
"""
import argparse
import collections
import csv
import datetime
import io
import json
import pathlib
import re
import sys
import tempfile
import time
import urllib.parse
import urllib.request
import zipfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
LINES = ROOT / "tpgNextFunc" / "Stops Database" / "Lines.json"
OUTPUT = ROOT / "tpgNextFunc" / "Stops Database" / "LineColors.json"
MANUAL = ROOT / "Scripts" / "line-colors-manual.csv"

SITE = "https://data.opentransportdata.swiss"
SEARCH = "https://timetable.search.ch/api/stationboard.json"
OVERPASS = "https://overpass-api.de/api/interpreter"
USER_AGENT = "tpg-next-lines/2.0"
# Sous la limite quotidienne de search.ch (10 080), pour garder de la marge.
MAX_REQUESTS = 9000
# Courses retenues par ligne GTFS : assez pour les variantes de parcours.
TRIPS_PER_ROUTE = 4
NIGHT = {"BN", "SN"}


def fetch(url, data=None):
    # Sans User-Agent, opentransportdata répond 403.
    request = urllib.request.Request(url, data=data, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=300) as response:
        return response.read()


def norm(number):
    """« IC 3 » et « IC3 », « n1 » et « N1 » désignent la même ligne."""
    return re.sub(r"\s+", "", number or "").upper()


def hex_color(value):
    """« fc0 » → « FFCC00 » ; `None` si ce n'est pas une couleur."""
    value = (value or "").strip().lstrip("#")
    if re.fullmatch(r"[0-9a-fA-F]{3}", value):
        value = "".join(c * 2 for c in value)
    return value.upper() if re.fullmatch(r"[0-9a-fA-F]{6}", value) else None


# --- Horaire GTFS : les arrêts de chaque ligne -------------------------------------------------

def latest_gtfs(cache):
    page = fetch(f"{SITE}/de/dataset/timetable-{datetime.date.today().year}-gtfs2020").decode()
    links = sorted(set(re.findall(r'https://[^"]+/download/(gtfs_fp\d{4}_[\d-]+\.zip)', page)))
    if not links:
        raise SystemExit("Aucun GTFS trouvé sur opentransportdata.swiss")
    name = max(links, key=lambda link: link.replace("-", ""))
    path = cache / name
    if not path.exists():
        url = re.search(r'https://[^"]+/download/' + re.escape(name), page).group(0)
        print(f"Téléchargement de {name}…")
        path.write_bytes(fetch(url))
    return path


def gtfs_rows(archive, name):
    with archive.open(name) as raw:
        yield from csv.DictReader(io.TextIOWrapper(raw, encoding="utf-8-sig"))


def stops_by_route(gtfs_path, wanted_routes, cache):
    """{route_id: {numéro d'arrêt (didok)}} pour les lignes GTFS demandées."""
    cached = cache / f"{gtfs_path.stem}-stops.json"
    if cached.exists():
        saved = json.loads(cached.read_text())
        if wanted_routes <= set(saved["routes"]):
            return {route: set(stops) for route, stops in saved["stops"].items()}
    with zipfile.ZipFile(gtfs_path) as archive:
        didok = {}
        for row in gtfs_rows(archive, "stops.txt"):
            if row["didok"]:
                didok[row["stop_id"]] = row["didok"]
        # Quelques courses par ligne, de destinations différentes.
        trips = {}
        headsigns = collections.defaultdict(set)
        for row in gtfs_rows(archive, "trips.txt"):
            route = row["route_id"]
            if route not in wanted_routes or len(headsigns[route]) >= TRIPS_PER_ROUTE:
                continue
            if row["trip_headsign"] not in headsigns[route]:
                headsigns[route].add(row["trip_headsign"])
                trips[row["trip_id"]] = route
        print(f"{len(trips)} courses retenues, lecture de stop_times.txt…")
        stops = collections.defaultdict(set)
        # 3,7 Go : lecture brute, sans csv, pour aller vite.
        with archive.open("stop_times.txt") as raw:
            header = raw.readline().decode("utf-8-sig").strip().split(",")
            trip_index, stop_index = header.index("trip_id"), header.index("stop_id")
            for line in io.TextIOWrapper(raw, encoding="utf-8"):
                fields = line.split(",")
                route = trips.get(fields[trip_index].strip('"'))
                if route:
                    stop = didok.get(fields[stop_index].strip('"'))
                    if stop:
                        stops[route].add(stop)
    cached.write_text(json.dumps({"routes": sorted(wanted_routes),
                                  "stops": {route: sorted(s) for route, s in stops.items()}}))
    return stops


# --- search.ch ---------------------------------------------------------------------------------

class SearchCH:
    def __init__(self, cache):
        self.cache = cache / "search.ch"
        self.cache.mkdir(exist_ok=True)
        self.requests = 0

    def departures(self, stop, date):
        """[(ligne, transporteur, couleur)] des 24 heures qui suivent `date` à 4 h 30."""
        path = self.cache / f"{stop}-{date.isoformat()}.json"
        if path.exists():
            return json.loads(path.read_text())
        if self.requests >= MAX_REQUESTS:
            return None
        query = urllib.parse.urlencode({"stop": stop, "date": date.strftime("%m/%d/%Y"),
                                        "time": "04:30", "limit": 0})
        for attempt in range(4):
            try:
                self.requests += 1
                answer = json.loads(fetch(f"{SEARCH}?{query}"))
                break
            except Exception as error:
                # 429 : trop de requêtes d'affilée, il faut laisser passer un moment.
                print(f"  search.ch {stop} {date} : {error}", file=sys.stderr)
                time.sleep(30 * (attempt + 1))
        else:
            return None
        seen = {(c.get("line"), c.get("operator"), c.get("color")) for c in answer.get("connections") or []}
        departures = sorted([line, operator or "", color or ""] for line, operator, color in seen if line)
        path.write_text(json.dumps(departures))
        time.sleep(0.2)
        return departures


def query_dates():
    """Un vendredi (avec sa nuit, pour les lignes N), un dimanche, un mercredi, puis un samedi
    d'hiver pour les lignes saisonnières."""
    today = datetime.date.today()

    def next_weekday(weekday):
        return today + datetime.timedelta(days=(weekday - today.weekday()) % 7 or 7)

    winter = datetime.date(today.year + (today.month > 1), 1, 16)
    winter += datetime.timedelta(days=(5 - winter.weekday()) % 7)
    return [next_weekday(4), next_weekday(6), next_weekday(2), winter]


def greedy_cover(stops_of_line):
    """Le plus petit jeu d'arrêts (à peu près) qui dessert toutes les lignes."""
    lines_at = collections.defaultdict(set)
    for line, stops in stops_of_line.items():
        for stop in stops:
            lines_at[stop].add(line)
    left = set(stops_of_line)
    chosen = []
    # Les égalités se départagent par numéro d'arrêt : d'un passage à l'autre, les mêmes arrêts
    # sont choisis et le cache sert (l'ordre d'un ensemble change à chaque lancement de Python).
    candidates = sorted(lines_at)
    while left:
        stop = max(candidates, key=lambda s: len(lines_at[s] & left))
        covered = lines_at[stop] & left
        if not covered:
            break
        chosen.append((stop, covered))
        left -= covered
    return chosen


def operator_matches(search_operator, transit_operator):
    """« VBZ    F », « SOB-sob » face à l'abréviation ATLAS (« VBZ », « SOB »)."""
    token = (search_operator or "").split()[0].split("-")[0].upper() if search_operator else ""
    return bool(token) and token in {transit_operator["shortName"].upper(),
                                     transit_operator["shortName"].split("-")[0].upper()}


# --- OpenStreetMap -----------------------------------------------------------------------------

def osm_routes(cache):
    path = cache / "osm-routes.json"
    if not path.exists() or time.time() - path.stat().st_mtime > 7 * 86400:
        query = """[out:json][timeout:300];
area["ISO3166-1"="CH"][admin_level=2]->.ch;
rel(area.ch)["type"="route"]["colour"]
  ["route"~"^(bus|trolleybus|tram|light_rail|subway|train|funicular|ferry|aerialway|share_taxi|monorail)$"];
out tags;"""
        path.write_bytes(fetch(OVERPASS, urllib.parse.urlencode({"data": query}).encode()))
    return [e["tags"] for e in json.loads(path.read_text())["elements"]]


def route_stem(route_id):
    """« 92-37-D-j26-1 » → « 92-37-D » : l'identifiant GTFS sans l'année d'horaire."""
    return re.sub(r"-j\d\d-\d+$", "", route_id or "")


# --- Assemblage --------------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--gtfs", type=pathlib.Path, help="archive GTFS déjà téléchargée")
    parser.add_argument("--cache", type=pathlib.Path,
                        default=pathlib.Path(tempfile.gettempdir()) / "tpg-next-line-colors")
    args = parser.parse_args()
    args.cache.mkdir(parents=True, exist_ok=True)

    directory = json.loads(LINES.read_text())
    operators = {o["id"]: o for o in directory["operators"]}
    lines = directory["lines"]
    # Plusieurs lignes ATLAS peuvent porter le même numéro chez un transporteur (S3 de Zurich, de
    # Berne, de Bâle) : la couleur est par transporteur et numéro, comme dans l'app.
    keys = sorted({(line["operator"], line["number"]) for line in lines})
    org_number = {o["id"]: o["ojpRef"].removeprefix("ojp:") for o in directory["operators"]}

    gtfs_path = args.gtfs or latest_gtfs(args.cache)
    with zipfile.ZipFile(gtfs_path) as archive:
        routes = list(gtfs_rows(archive, "routes.txt"))
        agencies = {row["agency_id"]: row["agency_name"] for row in gtfs_rows(archive, "agency.txt")}
    routes_of_key = collections.defaultdict(set)
    key_of_gtfs = {(org_number[op], norm(number)): (op, number) for op, number in keys}
    route_key = {}
    for route in routes:
        key = key_of_gtfs.get((route["agency_id"], norm(route["route_short_name"])))
        if key:
            routes_of_key[key].add(route["route_id"])
            route_key[route["route_id"]] = key
    # Le GTFS range parfois des lignes sous une autre entité du transporteur : les trams des VBZ
    # sont chez « Verkehrsbetriebe Zürich INFO+ » (3849), pas chez les VBZ (849).
    for route in routes:
        if route["route_id"] in route_key:
            continue
        agency = agencies.get(route["agency_id"], "")
        for op, number in keys:
            if ((op, number) not in routes_of_key and norm(number) == norm(route["route_short_name"])
                    and agency.startswith(operators[op]["colorName"])):
                routes_of_key[(op, number)].add(route["route_id"])
                route_key[route["route_id"]] = (op, number)
    print(f"{len(routes_of_key)} lignes sur {len(keys)} retrouvées dans le GTFS")

    stops = stops_by_route(gtfs_path, set(route_key), args.cache)
    stops_of_key = collections.defaultdict(set)
    for route, key in route_key.items():
        stops_of_key[key] |= stops.get(route, set())
    keys_at_stop = collections.defaultdict(set)
    for key, key_stops in stops_of_key.items():
        for stop in key_stops:
            keys_at_stop[stop].add(key)

    colors, sources = {}, {}

    # search.ch, date après date pour les lignes encore sans couleur.
    # Un arrêt essayé pour une ligne ne lui est plus proposé : search.ch ignore certains arrêts
    # (aucun départ), et le plan suivant les reprendrait. Un second tour passe par d'autres arrêts.
    search = SearchCH(args.cache)
    tried = collections.defaultdict(set)
    dates = query_dates()
    for date in dates + dates[:2]:
        wanted = {key: s - tried[key] for key, s in stops_of_key.items() if key not in colors and s - tried[key]}
        if not wanted:
            break
        plan = greedy_cover(wanted)
        print(f"search.ch, {date} : {len(wanted)} lignes, {len(plan)} arrêts")
        for stop, covered in plan:
            departures = search.departures(stop, date)
            if departures is None:
                continue
            for key in covered:
                tried[key].add(stop)
                if key in colors:
                    continue
                operator, number = key
                candidates = [d for d in departures if norm(d[0]) == norm(number)]
                mine = [d for d in candidates if operator_matches(d[1], operators[operator])]
                # Sans transporteur reconnu, seulement si aucun autre ne fait passer ce numéro ici.
                others = {k for k in keys_at_stop[stop] if norm(k[1]) == norm(number)} - {key}
                pool = mine or ([] if others else candidates)
                found = collections.Counter(c for c in (hex_color(d[2].split("~")[0]) for d in pool) if c)
                if found:
                    colors[key] = found.most_common(1)[0][0]
                    sources[key] = "search.ch"
        print(f"  {sum(1 for s in sources.values() if s == 'search.ch')} couleurs, "
              f"{search.requests} requêtes")

    # OpenStreetMap, par l'identifiant GTFS de la ligne, sinon par transporteur et numéro.
    key_of_stem = {}
    for route_id, key in route_key.items():
        key_of_stem.setdefault(route_stem(route_id), key)
    known = set(keys)
    names = collections.defaultdict(set)
    for operator in directory["operators"]:
        for name in (operator["shortName"], operator["name"], operator["colorName"]):
            names[name.strip().lower()].add(operator["id"])
    osm = collections.defaultdict(collections.Counter)
    for tags in osm_routes(args.cache):
        color = hex_color(tags.get("colour"))
        if not color:
            continue
        key = key_of_stem.get(route_stem(tags.get("gtfs:route_id")))
        if key and norm(key[1]) != norm(tags.get("ref")):
            key = None
        if not key:
            for field in ("operator", "network"):
                for operator in names.get((tags.get(field) or "").strip().lower(), ()):
                    if (operator, tags.get("ref")) in known:
                        key = (operator, tags.get("ref"))
        if key:
            osm[key][color] += 1
    for key, found in osm.items():
        if key not in colors:
            colors[key] = found.most_common(1)[0][0]
            sources[key] = "OpenStreetMap"

    # La couleur de presque toutes les lignes d'un transporteur (le jaune de CarPostal) vaut pour
    # les autres : d'abord dans la même catégorie (les R des CFF), sinon toutes catégories, mais
    # pas pour une ligne de nuit, souvent d'une autre couleur.
    category = {}
    for line in lines:
        category.setdefault((line["operator"], line["number"]), line["category"])

    def dominant(found):
        counts = collections.Counter(found)
        if not counts:
            return None
        color, n = counts.most_common(1)[0]
        return color if n >= 3 and n >= 0.9 * sum(counts.values()) else None

    by_category = collections.defaultdict(list)
    by_operator = collections.defaultdict(list)
    for key, color in colors.items():
        by_category[(key[0], category[key])].append(color)
        by_operator[key[0]].append(color)
    for key in keys:
        if key in colors:
            continue
        color = dominant(by_category[(key[0], category[key])])
        if not color and category[key] not in NIGHT:
            color = dominant(by_operator[key[0]])
        if color:
            colors[key] = color
            sources[key] = "transporteur"

    # Les relevés à la main passent devant.
    manual = {}
    if MANUAL.exists():
        with MANUAL.open(encoding="utf-8") as file:
            for row in csv.DictReader(file):
                color = hex_color(row.get("color"))
                if color:
                    manual[(row["operator_id"], row["number"])] = (color, row)
    for key, (color, _) in manual.items():
        colors[key] = color
        sources[key] = "manuel"

    result = collections.defaultdict(dict)
    for (operator, number), color in sorted(colors.items()):
        result[operator][number] = color
    before = json.loads(OUTPUT.read_text(encoding="utf-8")) if OUTPUT.exists() else {}
    # search.ch en panne ou qui bride : moins de couleurs qu'avant, on garde l'ancien relevé.
    if len(colors) < 0.9 * sum(len(lines) for lines in before.values()):
        raise SystemExit(f"{len(colors)} couleurs contre {sum(len(l) for l in before.values())} avant, "
                         f"{OUTPUT.name} conservé")
    # Un transporteur par ligne de texte : le diff d'une mise à jour se relit.
    OUTPUT.write_text("{\n" + ",\n".join(f"{json.dumps(operator)}:{json.dumps(result[operator], separators=(',', ':'))}"
                                           for operator in sorted(result)) + "\n}\n", encoding="utf-8")

    # La liste à compléter : les relevés à la main, puis les lignes sans couleur.
    by_key = {}
    for line in lines:
        by_key.setdefault((line["operator"], line["number"]), line)
    rows = []
    for key in keys:
        if key in manual or key not in colors:
            line = by_key[key]
            rows.append({"operator_id": key[0], "operator": operators[key[0]]["name"], "number": key[1],
                         "category": line["category"], "description": line["description"],
                         "color": manual[key][0] if key in manual else ""})
    rows.sort(key=lambda row: (row["operator"].lower(), row["category"], row["number"]))
    with MANUAL.open("w", encoding="utf-8", newline="") as file:
        writer = csv.DictWriter(file, fieldnames=["operator_id", "operator", "number", "category",
                                                  "description", "color"])
        writer.writeheader()
        writer.writerows(rows)

    total = collections.Counter(sources.values())
    print(f"{len(colors)} lignes colorées sur {len(keys)} → {OUTPUT}")
    for source, n in total.most_common():
        print(f"  {source} : {n}")
    print(f"{len(keys) - len(colors)} sans couleur → {MANUAL}")


if __name__ == "__main__":
    main()
