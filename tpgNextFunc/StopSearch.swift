//
//  StopSearch.swift
//  tpgNextFunc
//
//  Recherche d'arrêts propre à chaque écran.
//

import SwiftUI

public extension View {
    /// Tient `results` à jour avec les arrêts correspondant à `query`, après une courte
    /// pause de frappe, et relance la recherche une fois la base chargée.
    ///
    /// Chaque écran garde son propre texte : l'onglet Recherche et le champ d'itinéraire
    /// partageaient `StopStore.searchText` et voyaient les résultats l'un de l'autre.
    func searchingStops(_ query: String, results: Binding<[Stop]>) -> some View {
        modifier(StopSearchModifier(query: query, results: results))
    }
}

private struct StopSearchModifier: ViewModifier {
    @EnvironmentObject private var stopStore: StopStore
    let query: String
    @Binding var results: [Stop]

    private struct Key: Equatable {
        let query: String
        let isLoaded: Bool
    }

    func body(content: Content) -> some View {
        content.task(id: Key(query: query, isLoaded: stopStore.isLoaded)) {
            guard !query.isEmpty else {
                results = []
                return
            }
            do { try await Task.sleep(for: .milliseconds(300)) } catch { return }
            results = stopStore.search(query)
        }
    }
}
