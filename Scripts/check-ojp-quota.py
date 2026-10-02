#!/usr/bin/env python3
"""Vérifie le quota des clés OJP et échoue si l'une approche de sa limite.

Le gestionnaire de l'API (Tyk) compte par clé, tous appareils confondus, et renvoie l'état du
compteur avec chaque réponse (X-Quota-Limit / X-Quota-Remaining / X-Quota-Reset). Une requête
minuscule par clé suffit donc à savoir où en sont tous les utilisateurs de l'app. Chaque
vérification coûte une requête par clé.

Le quota repart 24 h après la première requête de sa période, pas à minuit : le temps écoulé
dans la période permet d'estimer l'usage à la fin de celle-ci, et de prévenir avant le dépassement.

Clés : la variable OJP_API_KEYS (séparées par des virgules, comme pour ci_scripts/ci_post_clone.sh),
sinon tpgNextFunc/Secrets.swift. Les clés ne sont jamais affichées.

    python3 Scripts/check-ojp-quota.py              # seuils par défaut
    python3 Scripts/check-ojp-quota.py --warn 0.3   # alerte sous 30 % restants

Code de sortie 1 si une clé est refusée, épuisée, sous le seuil, ou en voie de l'être : lancé par
GitHub Actions (.github/workflows/ojp-quota.yml), l'échec envoie un e-mail.
"""
import argparse
import datetime as dt
import os
import pathlib
import re
import sys
import urllib.error
import urllib.request

URL = "https://api.opentransportdata.swiss/ojp20"
ROOT = pathlib.Path(__file__).resolve().parent.parent
PERIOD = dt.timedelta(hours=24)


def load_keys():
    raw = os.environ.get("OJP_API_KEYS", "").strip()
    if raw:
        return [key.strip() for key in raw.split(",") if key.strip()]
    secrets = ROOT / "tpgNextFunc" / "Secrets.swift"
    if not secrets.exists():
        sys.exit("Ni OJP_API_KEYS ni tpgNextFunc/Secrets.swift : aucune clé à vérifier.")
    block = re.search(r"ojpAPIKeys[^=]*=\s*\[(.*?)\n\s*\]", secrets.read_text(), re.S)
    return re.findall(r'"([^"]+)"', block.group(1)) if block else []


def probe_body():
    """Les départs d'un arrêt qui n'existe pas : la plus petite réponse que l'API sache donner."""
    now = dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    return f"""<?xml version="1.0" encoding="utf-8"?>
<OJP xmlns="http://www.vdv.de/ojp" xmlns:siri="http://www.siri.org.uk/siri" version="2.0">
<OJPRequest><siri:ServiceRequest>
<siri:RequestTimestamp>{now}</siri:RequestTimestamp><siri:RequestorRef>tpgNext-quota</siri:RequestorRef>
<OJPStopEventRequest><siri:RequestTimestamp>{now}</siri:RequestTimestamp>
<Location><PlaceRef><siri:StopPointRef>ch:1:sloid:0</siri:StopPointRef><Name><Text>Quota</Text></Name></PlaceRef>
<DepArrTime>{now}</DepArrTime></Location><Params><NumberOfResults>1</NumberOfResults></Params>
</OJPStopEventRequest></siri:ServiceRequest></OJPRequest></OJP>""".encode()


def check(key):
    """(statut HTTP, en-têtes, début du corps) pour une clé."""
    request = urllib.request.Request(URL, data=probe_body(), method="POST", headers={
        "Content-Type": "text/XML", "Accept": "application/xml", "Authorization": key})
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            return response.status, response.headers, response.read(300).decode(errors="replace")
    except urllib.error.HTTPError as error:
        return error.code, error.headers, error.read(300).decode(errors="replace")
    except urllib.error.URLError as error:
        return 0, {}, str(error.reason)


def header_int(headers, name):
    try:
        return int(headers.get(name, ""))
    except (TypeError, ValueError):
        return None


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--warn", type=float, default=0.25,
                        help="part restante du quota sous laquelle alerter (défaut 0.25)")
    parser.add_argument("--projected", type=float, default=0.9,
                        help="alerter si l'usage estimé en fin de période dépasse cette part (défaut 0.9)")
    args = parser.parse_args()

    keys = load_keys()
    if not keys:
        sys.exit("Aucune clé trouvée.")
    now = dt.datetime.now(dt.timezone.utc)
    lines, problems = [], []
    total_used = total_limit = 0

    for number, key in enumerate(keys, start=1):
        status, headers, body = check(key)
        limit = header_int(headers, "X-Quota-Limit")
        remaining = header_int(headers, "X-Quota-Remaining")
        reset = header_int(headers, "X-Quota-Reset")
        rate_left = header_int(headers, "X-Ratelimit-Remaining")
        name = f"Clé {number}"

        if status == 429:
            lines.append(f"| {name} | limite par minute atteinte | | | |")
            problems.append(f"{name} : plus de 50 requêtes dans la minute (429), au moment de la vérification")
            continue
        if status in (401, 403):
            reason = "quota du jour épuisé" if "quota" in body.lower() else f"clé refusée ({status})"
            lines.append(f"| {name} | {reason} | | | |")
            problems.append(f"{name} : {reason}")
            continue
        if status == 0 or status >= 500:
            lines.append(f"| {name} | service injoignable ({status or body}) | | | |")
            problems.append(f"{name} : service injoignable ({status or body})")
            continue
        if limit is None or remaining is None:
            lines.append(f"| {name} | pas d'en-tête de quota (HTTP {status}) | | | |")
            continue

        used = limit - remaining
        total_used += used
        total_limit += limit
        share_left = remaining / limit if limit else 0
        reset_at = dt.datetime.fromtimestamp(reset, dt.timezone.utc) if reset else None
        elapsed = PERIOD - (reset_at - now) if reset_at else None
        # Sur moins d'une heure de période, l'estimation ne vaut rien.
        projected = used / (elapsed / PERIOD) if elapsed and elapsed > dt.timedelta(hours=1) else None
        reset_text = reset_at.astimezone().strftime("%d.%m %H:%M") if reset_at else "?"
        projected_text = f"{projected:,.0f}".replace(",", "'") if projected else "–"
        lines.append(f"| {name} | {remaining:,}/{limit:,} restantes ({share_left:.0%}) | {projected_text} | {reset_text} | "
                     f"{rate_left if rate_left is not None else '?'}/50 |".replace(",", "'"))

        if share_left < args.warn:
            problems.append(f"{name} : {share_left:.0%} du quota restant ({remaining}/{limit}), repart le {reset_text}")
        elif projected and projected > limit * args.projected:
            problems.append(f"{name} : au rythme actuel, ~{projected:,.0f} requêtes d'ici le {reset_text} "
                            f"(limite {limit:,})".replace(",", "'"))

    report = ["## Quota des clés OJP", "",
              f"Vérifié le {now.astimezone().strftime('%d.%m.%Y à %H:%M')}"
              + (f" — {total_used:,}/{total_limit:,} requêtes utilisées".replace(",", "'") if total_limit else ""),
              "", "| Clé | Quota | Estimé en fin de période | Repart | Cette minute |",
              "|---|---|---|---|---|", *lines]
    if problems:
        report += ["", "### À surveiller", *[f"- {problem}" for problem in problems]]
    text = "\n".join(report)
    print(text)

    summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary:
        with open(summary, "a") as file:
            file.write(text + "\n")
    # Une limite par minute atteinte au moment exact de la vérification est passagère :
    # elle est signalée, sans faire échouer la vérification.
    serious = [problem for problem in problems if "(429)" not in problem]
    return 1 if serious else 0


if __name__ == "__main__":
    sys.exit(main())
