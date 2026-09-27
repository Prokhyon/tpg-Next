#!/usr/bin/env python3
"""Régénère tpgNextFunc/Stops Database/Lines.json depuis le registre national (ATLAS).

Deux jeux de données publics, sans clé, sur https://data.opentransportdata.swiss :
- « line-v2 » : les lignes en vigueur aujourd'hui (« actual-date-line.csv ») ;
- « business-organisation-v2 » : les transporteurs (« actual-date-business-organisation.csv »).

Les adresses des fichiers changent : elles sont relevées sur la page de chaque jeu de données.
À relancer à chaque horaire annuel, ou quand une ligne change :

    python3 Scripts/lines-from-atlas.py
"""
import csv
import io
import json
import pathlib
import re
import urllib.request

SITE = "https://data.opentransportdata.swiss"
OUTPUT = pathlib.Path(__file__).resolve().parent.parent / "tpgNextFunc" / "Stops Database" / "Lines.json"

# Les catégories d'offre gardées. Sans catégorie : des remontées mécaniques (téléskis) ;
# EV : bus de remplacement ; ATZ : ferroutage.
CATEGORIES = {
    "B", "BN", "RUB", "T", "M",
    "S", "SN", "R", "RE", "IR", "IRE", "IC", "ICE", "EC", "TGV", "EN", "RJ", "TER", "PE", "RB", "EXT", "ES",
    "BAT", "FAE", "FUN", "PB", "GB", "SL", "ASC",
}


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


def main():
    organisations = {row["sboid"]: row for row in csv_rows("business-organisation-v2",
                                                           "actual-date-business-organisation.csv")}
    lines = []
    used = set()
    for row in csv_rows("line-v2", "actual-date-line.csv"):
        organisation = organisations.get(row["businessOrganisation"])
        number = (row["number"] or "").strip()
        # « 91-92 » : une concession de zone, pas une ligne (91 et 92 figurent à part).
        if (not organisation or not number or "-" in number or row["status"] != "VALIDATED"
                or row["lineType"] != "ORDERLY" or row["offerCategory"] not in CATEGORIES):
            continue
        used.add(organisation["sboid"])
        lines.append({
            "slnid": row["slnid"],
            "number": number,
            "category": row["offerCategory"],
            "description": " ".join(row["description"].split()),
            "operator": organisation["said"],
        })
    operators = []
    for sboid in used:
        organisation = organisations[sboid]
        operators.append({
            "id": organisation["said"],
            # Le nom affiché, en français.
            "name": organisation["descriptionFr"] or organisation["descriptionDe"],
            "shortName": organisation["abbreviationFr"] or organisation["abbreviationDe"],
            # Le nom allemand est celui qu'OJP 1.0 donnait, et qui indexe `LineColors`.
            "colorName": organisation["descriptionDe"],
            # OJP 2.0 désigne l'exploitant par son numéro d'organisation.
            "ojpRef": f"ojp:{organisation['organisationNumber']}",
        })
    lines.sort(key=lambda line: (line["operator"], line["number"]))
    operators.sort(key=lambda operator: operator["name"].lower())
    directory = {"operators": operators, "lines": lines}
    OUTPUT.write_text(json.dumps(directory, ensure_ascii=False, separators=(",", ":")) + "\n", encoding="utf-8")
    print(f"{len(lines)} lignes, {len(operators)} transporteurs → {OUTPUT}")


if __name__ == "__main__":
    main()
