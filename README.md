# tpg Next

Les prochains départs des transports publics genevois — et de toute la Suisse — sur iPhone,
iPad et Apple Watch.

- Départs en temps réel, lignes, itinéraires
- Favoris, trajets réguliers et suivi en direct (écran verrouillé, Dynamic Island)
- Widgets et complications
- Perturbations : courses supprimées, arrêts non desservis, parcours modifiés

Données : API [OJP 2.0](https://opentransportdata.swiss) d'opentransportdata.swiss.

## Prérequis

- Xcode 26 ou plus récent
- iOS 17.5+, watchOS 26+
- Une ou plusieurs clés d'API OJP ([opentransportdata.swiss](https://opentransportdata.swiss))

## Démarrer

```bash
git clone https://github.com/LewisThas/tpg-Next.git
cd tpg-Next
OJP_API_KEYS="clé1,clé2" ci_scripts/ci_post_clone.sh
open "tpg Next.xcodeproj"
```

Le script génère `tpgNextFunc/Secrets.swift`, qui n'est jamais versionné.

## Organisation

| Dossier | Rôle |
|---|---|
| `tpg Next/` | App iPhone et iPad |
| `tpgNextFunc/` | Framework partagé : API OJP, modèles, base des arrêts |
| `tpg Next Widget/` | Widgets |
| `tpg Next Watch App/` | App Apple Watch |
| `tpg Next Watch Widget/` | Complications de la montre |
| `tpgNextFuncTests/` | Tests du framework |
| `Scripts/` | Mise à jour des arrêts, lignes et couleurs |

Plus de détails dans [ARCHITECTURE.md](ARCHITECTURE.md). Historique des versions dans
[Updates.md](Updates.md).
