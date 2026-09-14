//
//  Clock.swift
//  tpgNextFunc
//
//  L'heure de référence de l'affichage, partagée par l'app et la montre.
//

import SwiftUI

private struct DisplayTimeKey: EnvironmentKey {
    static var defaultValue: Date { Date() }
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
            content.environment(\.displayTime, context.date)
        }
    }
}
