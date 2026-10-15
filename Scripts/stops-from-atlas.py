#!/usr/bin/env python3
"""Régénère la base des arrêts (tpgNextFunc/Stops Database/FullStopsCH.json et TrainStopsFR.json)
depuis le registre national (ATLAS).

Jeu de données public, sans clé, sur https://data.opentransportdata.swiss : « service-point-v2 »,
les points de service en vigueur aujourd'hui (« actual-date-swiss-service-point.csv »). Il contient
aussi les arrêts des pays voisins desservis depuis la Suisse.

Gardés : les points d'arrêt (`stopPoint`), sauf les points-frontière, quel que soit leur statut
(un arrêt « DRAFT » ou « REVOKED » peut encore être servi par les horaires). En France, seulement
ceux dont le moyen de transport est connu : les « UNKNOWN » sont des points SNCF sans départs.

À relancer avec les autres scripts : Scripts/update-data.sh.

    python3 Scripts/stops-from-atlas.py
"""
import csv
import io
import json
import pathlib
import re
import urllib.request

SITE = "https://data.opentransportdata.swiss"
FOLDER = pathlib.Path(__file__).resolve().parent.parent / "tpgNextFunc" / "Stops Database"
# Le nom du fichier français est historique : il contient surtout des arrêts de bus.
FILES = {"CH": "FullStopsCH.json", "FR": "TrainStopsFR.json"}
# Une base qui fond d'un coup trahit un jeu de données incomplet : on ne l'écrit pas.
MINIMUM_SHARE = 0.95


def fetch(url):
    # Sans User-Agent, le serveur répond 403.
    request = urllib.request.Request(url, headers={"User-Agent": "tpg-next-lines/2.0"})
    with urllib.request.urlopen(request) as response:
        return response.read().decode("utf-8-sig")


def csv_rows(dataset, filename):
    page = fetch(f"{SITE}/de/dataset/{dataset}")
    match = re.search(r'https://[^"]+/download/' + re.escape(filename), page)
    if not match:
        raise SystemExit(f"{filename} introuvable sur la page de {dataset}")
    return list(csv.DictReader(io.StringIO(fetch(match.group(0))), delimiter=";"))


def keep(row, country):
    if row["isoCountryCode"] != country or row["stopPoint"] != "true" or row["borderPoint"] != "false":
        return False
    if not row["wgs84East"] or not row["wgs84North"]:
        return False
    return country != "FR" or row["meansOfTransport"] not in ("", "UNKNOWN")


def main():
    rows = csv_rows("service-point-v2", "actual-date-swiss-service-point.csv")
    for country, name in FILES.items():
        stops = [{
            "sloid": row["sloid"],
            "number": row["number"],
            "designationOfficial": row["designationOfficial"],
            "isoCountryCode": row["isoCountryCode"],
            "cantonName": row["cantonName"],
            "meansOfTransport": row["meansOfTransport"],
            "wgs84East": float(row["wgs84East"]),
            "wgs84North": float(row["wgs84North"]),
        } for row in rows if keep(row, country)]
        # Dans l'ordre des numéros, pour que le diff ne montre que les changements.
        stops.sort(key=lambda stop: int(stop["number"]))
        path = FOLDER / name
        before = json.loads(path.read_text(encoding="utf-8")) if path.exists() else []
        if len(stops) < MINIMUM_SHARE * len(before):
            raise SystemExit(f"{name} : {len(stops)} arrêts contre {len(before)} avant, fichier conservé")
        # Un arrêt par ligne : le diff d'une mise à jour se relit.
        path.write_text("[\n" + ",\n".join(json.dumps(stop, ensure_ascii=False, separators=(",", ":"))
                                             for stop in stops) + "\n]\n", encoding="utf-8")
        old = {stop["sloid"]: stop for stop in before}
        new = {stop["sloid"]: stop for stop in stops}
        renamed = sum(1 for sloid, stop in new.items()
                      if sloid in old and old[sloid]["designationOfficial"] != stop["designationOfficial"])
        print(f"{name} : {len(stops)} arrêts (+{len(new.keys() - old.keys())} "
              f"-{len(old.keys() - new.keys())}, {renamed} renommés)")


if __name__ == "__main__":
    main()
