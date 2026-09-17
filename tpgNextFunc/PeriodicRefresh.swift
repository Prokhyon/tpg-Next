//
//  PeriodicRefresh.swift
//  tpgNextFunc
//
//  Rafraîchissement des écrans de départs, partagé par l'app et la montre.
//

import SwiftUI

/// Pourquoi `periodicRefresh` appelle son action.
public enum RefreshTrigger: Equatable {
    /// Apparition de la vue, retour au premier plan ou changement d'`id`.
    case start
    /// Rafraîchissement périodique.
    case tick
}

public extension View {
    /// Appelle `action` à l'apparition de la vue, puis toutes les `interval` si `repeats`.
    ///
    /// S'arrête quand la vue disparaît ou que l'app quitte le premier plan, et repart (avec
    /// un appel `.start`) au retour au premier plan ou quand `id` ou `repeats` change.
    /// Remplace les couples `Timer` + notifications de premier plan / arrière-plan que
    /// chaque écran recopiait.
    func periodicRefresh<ID: Equatable>(id: ID, every interval: Duration = .seconds(30), repeats: Bool = true,
                                        perform action: @escaping @MainActor (RefreshTrigger) -> Void) -> some View {
        modifier(PeriodicRefresh(id: id, interval: interval, repeats: repeats, action: action))
    }

    func periodicRefresh(every interval: Duration = .seconds(30), repeats: Bool = true,
                         perform action: @escaping @MainActor (RefreshTrigger) -> Void) -> some View {
        periodicRefresh(id: true, every: interval, repeats: repeats, perform: action)
    }
}

private struct PeriodicRefresh<ID: Equatable>: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase
    let id: ID
    let interval: Duration
    let repeats: Bool
    let action: @MainActor (RefreshTrigger) -> Void

    private struct Key: Equatable {
        let id: ID
        let isActive: Bool
        let repeats: Bool
    }

    func body(content: Content) -> some View {
        content.task(id: Key(id: id, isActive: scenePhase == .active, repeats: repeats)) {
            guard scenePhase == .active else { return }
            action(.start)
            guard repeats else { return }
            while true {
                do { try await Task.sleep(for: interval) } catch { return }
                action(.tick)
            }
        }
    }
}
