//
//  Clock.swift
//  tpgNextFunc
//
//  L'heure de référence de l'affichage, partagée par l'app et la montre.
//

import SwiftUI

/// L'heure de l'app : celle de l'appareil, ou, en mode capture (Debug, arguments de lancement
/// `-CaptureMode` ou `-CaptureRecord`), 9:41 heure suisse au lancement, qui avance ensuite
/// normalement.
///
/// À utiliser pour tout ce qui s'affiche ou se compare aux horaires (décomptes, heure des
/// requêtes, Aujourd'hui / Demain). Les notifications, l'activité en direct côté système, les
/// quotas de l'API et la synchro iCloud restent sur `Date()` : ils suivent la vraie horloge.
public enum AppClock {
    /// L'heure courante de l'app.
    public static func now() -> Date { Date().addingTimeInterval(offset) }

    /// Une date de la vraie horloge (celle d'un `TimelineView`), ramenée à l'heure de l'app.
    public static func shifted(_ date: Date) -> Date { date.addingTimeInterval(offset) }

    /// Vrai en mode capture : relecture (`-CaptureMode`) ou enregistrement (`-CaptureRecord`).
    public static let isCapturing: Bool = {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        return arguments.contains("-CaptureMode") || arguments.contains("-CaptureRecord")
        #else
        return false
        #endif
    }()

    /// 9:41 heure suisse, le jour du lancement : l'heure de l'app au lancement en mode capture.
    public static let captureReference: Date = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Zurich") ?? .current
        return calendar.date(bySettingHour: 9, minute: 41, second: 0, of: launch) ?? launch
    }()

    private static let launch = Date()

    /// L'écart avec l'appareil : nul hors du mode capture.
    public static let offset: TimeInterval = isCapturing ? captureReference.timeIntervalSince(launch) : 0
}

private struct DisplayTimeKey: EnvironmentKey {
    static var defaultValue: Date { AppClock.now() }
}

public extension EnvironmentValues {
    /// L'heure de référence des décomptes (« 6' ») et des passages grisés.
    ///
    /// Les vues la lisent au lieu d'appeler `Date()` : elles se redessinent quand elle avance,
    /// même si les départs, eux, n'ont pas changé. Sans ça, un départ affiché « dans 6' »
    /// le restait tant que l'API renvoyait la même liste. Posée par `tickingClock()` ;
    /// sans lui (aperçus), c'est l'heure courante.
    var displayTime: Date {
        get { self[DisplayTimeKey.self] }
        set { self[DisplayTimeKey.self] = newValue }
    }
}

public extension View {
    /// Fait avancer `\.displayTime` toutes les `interval` secondes pour toute la hiérarchie.
    /// Seules les vues qui la lisent se redessinent. Le `TimelineView` s'arrête quand l'app
    /// n'est plus affichée.
    func tickingClock(every interval: TimeInterval = 15) -> some View {
        modifier(TickingClock(interval: interval))
    }
}

private struct TickingClock: ViewModifier {
    let interval: TimeInterval

    func body(content: Content) -> some View {
        TimelineView(.periodic(from: .now, by: interval)) { context in
            content.environment(\.displayTime, AppClock.shifted(context.date))
        }
    }
}
