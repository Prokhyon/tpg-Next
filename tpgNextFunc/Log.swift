//
//  Log.swift
//  tpgNextFunc
//

import os

/// Les journaux de l'app, de la montre et du widget, filtrables par catégorie
/// dans la console Xcode et dans Console.app.
///
/// Contrairement à `print`, rien n'est écrit en release tant que personne ne
/// lit les journaux, et les chaînes interpolées y sont masquées par défaut.
public enum Log {
    private static let subsystem = "com.loristhomas.tpgNext"

    public static let network = Logger(subsystem: subsystem, category: "network")
    public static let data = Logger(subsystem: subsystem, category: "data")
    public static let location = Logger(subsystem: subsystem, category: "location")
    public static let notifications = Logger(subsystem: subsystem, category: "notifications")
    public static let sync = Logger(subsystem: subsystem, category: "sync")
    public static let ui = Logger(subsystem: subsystem, category: "ui")
}
