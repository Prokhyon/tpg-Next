#!/bin/sh
#
# Génère tpgNextFunc/Secrets.swift à partir de la variable OJP_API_KEYS
# (clés séparées par des virgules).
#
# Xcode Cloud exécute ce script après chaque clone : la variable doit être
# déclarée comme secrète dans le workflow (App Store Connect > Xcode Cloud >
# Environment > Environment Variables).
#
# En local :
#   OJP_API_KEYS="clé1,clé2" ci_scripts/ci_post_clone.sh

set -e
cd "$(dirname "$0")/.."

OUTPUT="tpgNextFunc/Secrets.swift"

if [ -z "$OJP_API_KEYS" ]; then
    if [ -f "$OUTPUT" ]; then
        echo "OJP_API_KEYS non défini : $OUTPUT existant conservé."
        exit 0
    fi
    echo "error: OJP_API_KEYS n'est pas défini, impossible de générer $OUTPUT." >&2
    exit 1
fi

{
    echo "// Généré par ci_scripts/ci_post_clone.sh. Ne pas versionner."
    echo "enum Secrets {"
    echo "    static let ojpAPIKeys: [String] = ["
    echo "$OJP_API_KEYS" | tr ',' '\n' \
        | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e '/^$/d' -e 's/.*/        "&",/'
    echo "    ]"
    echo "}"
} > "$OUTPUT"

echo "$OUTPUT généré."
