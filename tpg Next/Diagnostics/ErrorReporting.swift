//
//  ErrorReporting.swift
//  tpg Next
//
//  Les rapports d'erreurs envoyés au développeur (Sentry, hébergé en UE, à Francfort).
//
//  Partent : les alertes de l'API OJP (`OJPUsage.alertHandler` : quota bas ou épuisé, limite par
//  minute, clé refusée, requête refusée, panne, réponse illisible), les plantages et les blocages
//  de l'app. Ne partent pas : ni identifiant de l'utilisateur, ni position, ni arrêt consulté,
//  ni capture d'écran (`sendDefaultPii` faux, pas de traces de performance).
//

import Foundation
import Sentry
import tpgNextFunc

enum ErrorReporting {
    /// À appeler au lancement de l'app. Sans adresse (`SENTRY_DSN` absent de Xcode Cloud ou de
    /// `Secrets.swift`), rien ne démarre.
    static func start() {
        let dsn = ServiceKeys.sentryDSN
        guard !dsn.isEmpty else {
            Log.network.info("Rapports d'erreurs désactivés : pas d'adresse Sentry")
            return
        }
        SentrySDK.start { options in
            options.dsn = dsn
            #if DEBUG
            options.environment = "debug"
            #else
            options.environment = "production"
            #endif
            options.sendDefaultPii = false
            options.tracesSampleRate = 0
            options.attachScreenshot = false
            options.attachViewHierarchy = false
        }
        OJPUsage.alertHandler = { alert in
            report(alert)
        }
    }

    /// Une alerte OJP devient un « issue » Sentry, un par type d'alerte et par clé : la règle
    /// d'alerte du projet (e-mail) se déclenche à son apparition et quand il revient.
    private static func report(_ alert: OJPAlert) {
        SentrySDK.capture(message: "OJP : \(alert.kind.rawValue)") { scope in
            scope.setLevel(level(for: alert.kind))
            scope.setTag(value: alert.kind.rawValue, key: "ojp.alert")
            if let key = alert.key {
                scope.setTag(value: String(key), key: "ojp.key")
            }
            scope.setExtra(value: alert.detail, key: "detail")
            scope.setFingerprint(["ojp", alert.kind.rawValue, String(alert.key ?? 0)])
        }
    }

    private static func level(for kind: OJPAlert.Kind) -> SentryLevel {
        switch kind {
        case .quotaExceeded, .keyRejected, .badRequest, .unreadable: .error
        case .quotaLow, .rateLimited, .server: .warning
        }
    }
}
