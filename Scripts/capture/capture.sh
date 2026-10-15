#!/bin/zsh
#
# Captures de l'App Store, avec les données figées du mode capture (voir tpgNextFunc/OJPCapture.swift).
#
#   Scripts/capture/capture.sh build
#       Compile l'app (Debug) pour le simulateur, dans build/capture.
#   Scripts/capture/capture.sh replay <udid> <iPhone|iPad> <dossier>
#       Relit les données à 9:41, sans réseau, dans les trois langues : <dossier>/{Fr,Eng,De}/<appareil>.
#       N'écrase jamais une capture existante.
#   Scripts/capture/capture.sh record <udid> <iPhone|iPad>
#       Enregistre les réponses d'OJP de tous les écrans (l'app se croit à 9:41), puis AJOUTE au projet
#       celles qui manquent. Une réponse déjà présente n'est jamais remplacée : pour en changer une,
#       supprimer d'abord son fichier à la main. Il faut recompiler ensuite (build).
#
# Simulateurs : jamais celui utilisé dans Xcode. Un iPhone 6,9" et un iPad 13" dédiés aux captures.

set -u
ROOT=${0:A:h:h:h}
DERIVED=$ROOT/build/capture
DATA="$ROOT/tpg Next/Preview Content/Capture"
B=com.loristhomas.tpgNext
TMP=$(mktemp -d)

app() { find "$DERIVED/Build/Products" -maxdepth 2 -name 'tpg Next.app' -path '*iphonesimulator*' | head -1; }

langargs() {
  case $1 in
    fr) echo "-AppleLanguages (fr) -AppleLocale fr_CH";;
    en) echo "-AppleLanguages (en) -AppleLocale en_CH";;
    de) echo "-AppleLanguages (de) -AppleLocale de_CH";;
  esac
}

# Simulateur démarré, barre d'état à 9:41, position à Rive, app réinstallée sans bienvenue ni iCloud.
prep() {
  local U=$1
  xcrun simctl boot $U 2>/dev/null; xcrun simctl bootstatus $U >/dev/null
  xcrun simctl status_bar $U override --time "9:41" --batteryState discharging --batteryLevel 100 \
    --wifiMode active --wifiBars 3 --cellularMode active --cellularBars 4 --operatorName ""
  xcrun simctl location $U set 46.2016,6.1535
  xcrun simctl uninstall $U $B 2>/dev/null
  xcrun simctl install $U "$(app)"
  xcrun simctl privacy $U grant location-always $B
  for setting in "ShowWelcome -bool false" "LastSeenWhatsNew -string 1.2" "NotificationAsked -bool true" "ICloudSync -bool false"; do
    xcrun simctl spawn $U defaults write $B ${=setting}
  done
}

# launch <udid> <langue> <mode> <attente> <liens…>
launch() {
  local U=$1 lang=$2 mode=$3 wait=$4; shift 4
  xcrun simctl terminate $U $B 2>/dev/null
  SIMCTL_CHILD_TPG_DEBUG_URLS="$*" xcrun simctl launch $U $B $mode ${=$(langargs $lang)} >/dev/null
  sleep $wait
}

# shot <udid> <langue> <mode> <fichier> <attente> <liens…> : simctl ne peut pas écrire sur le Bureau.
shot() {
  local U=$1 lang=$2 mode=$3 out=$4 wait=$5; shift 5
  if [[ -e $out ]]; then echo "existe déjà, gardée : $out"; return; fi
  launch $U $lang $mode $wait "$@"
  xcrun simctl io $U screenshot $TMP/shot.png >/dev/null 2>&1
  mkdir -p "${out:h}"; cp $TMP/shot.png "$out"
}

# screens <udid> <appareil> <langue> <mode> <dossier>
screens() {
  local U=$1 DEV=$2 lang=$3 mode=$4 O=$5
  local names R TRIP DIST PITCH
  case $lang in fr) names="Travail,Sport";; en) names="Work,Sport";; de) names="Arbeit,Sport";; esac
  R="sloid=ch:1:sloid:87061&name=Gen%C3%A8ve%2C%20Rive"
  TRIP="sloid=ch:1:sloid:92775&from=ch:1:sloid:87437"
  if [[ $DEV == iPad ]]; then PITCH=30; DIST=1150; else PITCH=40; DIST=950; fi
  launch $U $lang $mode 35 "tpgnext://seed?names=$names"
  xcrun simctl spawn $U defaults write $B HomeSectionsOrder -string "nextTrip,favorites,departures,places,map"
  shot $U $lang $mode "$O/01-accueil.png" 25 "tpgnext://tab?name=home"
  shot $U $lang $mode "$O/03-arret.png" 25 "tpgnext://stop?$R"
  shot $U $lang $mode "$O/04-ligne.png" 25 "tpgnext://firstline?sloid=ch:1:sloid:87061&line=12"
  shot $U $lang $mode "$O/05-trajets.png" 25 "tpgnext://tab?name=trips"
  shot $U $lang $mode "$O/06-suivi.png" 25 "tpgnext://sheet?name=live"
  if [[ $DEV == iPad ]]; then
    shot $U $lang $mode "$O/07-itineraire.png" 35 "tpgnext://quicktrip?$TRIP&select=1"
  else
    shot $U $lang $mode "$O/07-itineraire.png" 30 "tpgnext://quicktrip?$TRIP"
    shot $U $lang $mode "$O/08-itineraire-detail.png" 35 "tpgnext://quicktrip?$TRIP&open=1"
  fi
  shot $U $lang $mode "$O/09-carte.png" 25 "tpgnext://quaymap?sloid=ch:1:sloid:87387&quay=A&pitch=$PITCH&distance=$DIST"
  shot $U $lang $mode "$O/10-filtre.png" 25 \
    "tpgnext://stop?sloid=ch:1:sloid:87057&name=Gen%C3%A8ve%2C%20gare%20Cornavin&grouped=1&count=120&filter=1:Trois,5:Vallard,8:douane,9:Belle&open=5"
  xcrun simctl terminate $U $B 2>/dev/null
}

case ${1:-} in
  build)
    cd "$ROOT" && xcodebuild -project "tpg Next.xcodeproj" -scheme "tpg Next" -configuration Debug \
      -destination "generic/platform=iOS Simulator" -derivedDataPath "$DERIVED" build | grep -E "error:|BUILD"
    ;;
  replay)
    U=$2 DEV=$3 OUT=$4
    for lang in fr en de; do
      case $lang in fr) D=Fr;; en) D=Eng;; de) D=De;; esac
      prep $U
      screens $U $DEV $lang -CaptureMode "$OUT/$D/$DEV"
      echo "$DEV $lang : fini"
    done
    xcrun simctl spawn $U log show --last 30m --style compact --predicate 'eventMessage BEGINSWITH "Capture : "' 2>/dev/null \
      | grep "Capture : " || echo "aucune requête manquante"
    ;;
  record)
    U=$2 DEV=$3
    prep $U
    screens $U $DEV fr -CaptureRecord $TMP/$DEV
    SRC=$(xcrun simctl get_app_container $U $B data)/Documents/Capture
    mkdir -p "$DATA"
    cp -n "$SRC"/capture-*.xml "$DATA/"
    python3 - "$SRC/capture-index.json" "$DATA/capture-index.json" <<'PY'
import json, os, sys
src, dst = sys.argv[1], sys.argv[2]
index = json.load(open(dst)) if os.path.exists(dst) else {}
added = [key for key in json.load(open(src)) if key not in index]
for key, day in json.load(open(src)).items():
    index.setdefault(key, day)
json.dump(index, open(dst, "w"), indent=2, sort_keys=True)
print(f"{len(added)} réponse(s) ajoutée(s), {len(index)} au total")
PY
    ;;
  *)
    sed -n '3,16p' $0
    ;;
esac
rm -rf $TMP
