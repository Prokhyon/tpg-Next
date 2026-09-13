//
//  OJPDate.swift
//  tpgNextFunc
//

import Foundation

/// Les heures échangées avec OJP : UTC, au format ISO 8601 (`2026-09-13T15:56:00Z`).
///
/// Les formateurs coûtent cher à créer. Ils l'étaient à chaque appel, soit plusieurs fois
/// par ligne affichée et par rafraîchissement ; ils sont maintenant partagés.
public enum OJPDate {
    private static let formatter = ISO8601DateFormatter()

    private static let fractionalFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let clockFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .autoupdatingCurrent
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    /// `nil` si la chaîne n'est pas une heure OJP.
    public static func date(from string: String) -> Date? {
        guard !string.isEmpty else { return nil }
        return formatter.date(from: string) ?? fractionalFormatter.date(from: string)
    }

    /// Le format attendu dans les requêtes.
    public static func string(from date: Date) -> String {
        formatter.string(from: date)
    }

    /// L'heure locale, « 14:05 ».
    public static func clockTime(from date: Date) -> String {
        clockFormatter.string(from: date)
    }
}
