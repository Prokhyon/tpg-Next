#!/bin/sh
#
# Met à jour les données embarquées dans tpgNextFunc/Stops Database/, dans l'ordre :
# 1. les arrêts (FullStopsCH.json, TrainStopsFR.json), depuis ATLAS ;
# 2. les lignes et transporteurs (Lines.json), depuis ATLAS ;
# 3. les couleurs des lignes (LineColors.json), depuis search.ch et OpenStreetMap, qui partent
#    des lignes de l'étape 2. Les lignes sans couleur vont dans Scripts/line-colors-manual.csv.
#
# Chaque script refuse d'écrire un fichier qui aurait fondu d'un coup (source incomplète ou en
# panne) et garde alors l'ancien. Le workflow GitHub « Données » le lance chaque mois et
# ouvre une pull request ; en local :
#
#   Scripts/update-data.sh            # tout
#   Scripts/update-data.sh --no-colors   # sans les couleurs (environ une heure de requêtes)

set -e
cd "$(dirname "$0")/.."

python3 Scripts/stops-from-atlas.py
python3 Scripts/lines-from-atlas.py
if [ "$1" != "--no-colors" ]; then
    python3 -u Scripts/line-colors.py
fi
