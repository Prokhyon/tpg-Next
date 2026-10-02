//
//  ServiceKeys.swift
//  tpgNextFunc
//
//  Les identifiants de services lus par l'app, tirés de `Secrets.swift` (généré, non versionné).
//

import Foundation

public enum ServiceKeys {
    /// L'adresse des rapports d'erreurs (Sentry, région UE). Vide : aucun rapport n'est envoyé.
    public static var sentryDSN: String { Secrets.sentryDSN }
}
