//
//  StopControls.swift
//  tpg Next
//
//  Commandes de la page d'un arrêt, sorties de StopView pour être réutilisées ou replacées
//  (barre d'outils, panneau latéral) sans toucher à la liste des départs.
//

import SwiftUI
import tpgNextFunc

/// Menu « … » d'un arrêt : favori, carte des quais, actions d'itinéraire.
struct StopActionsMenu: View {
    @Environment(StopStore.self) private var stopStore
    @Environment(FavoritesViewModel.self) private var favoritesViewModel
    @Environment(\.openRoute) private var openRoute
    let stopName: String
    let stopSloid: String
    let quays: [Quay]

    var body: some View {
        Menu {
            Button(action: toggleFavorite) {
                favoritesViewModel.isFavoriteID(stopSloid) ? Label("Retirer des favoris", systemImage: "star.fill") : Label("Ajouter aux favoris", systemImage: "star")
            }
            Divider()
            if !quays.isEmpty {
                Button {
                    openRoute(.stopMap(quays: quays, sloid: stopSloid, name: stopName))
                } label: {
                    Label("Carte des quais", systemImage: "map")
                }
            }
            TripActionsMenu(stop: createStop(nomarret: stopName, sloid: sloidHarmonizer(code: stopSloid)), includesQuickTrip: false)
        } label: {
            Label("", systemImage: "ellipsis")
                .padding(.horizontal, 5)
        }
    }

    private func toggleFavorite() {
        if let stop = stopStore.findStop(id: stopSloid) {
            if favoritesViewModel.isFavorite(stop) {
                favoritesViewModel.removeFavoriteStop(stop)
            } else {
                favoritesViewModel.addFavorite(stop)
            }
        }
    }
}

/// Boutons flottants au bas de la liste : tri par ligne, filtres, décalage de l'heure.
struct StopFloatingControls: View {
    let isGroupedByLine: Bool
    let toggleGrouping: () -> Void
    @Binding var showsFilters: Bool
    @Binding var isFiltered: Bool
    let moveTime: (_ earlier: Bool) -> Void

    var body: some View {
        HStack {
            HStack(spacing: TPGSurface.isGlass ? 0 : nil) {
                Button(action: toggleGrouping) {
                    Image(systemName: isGroupedByLine ? "text.justify" : "rectangle.grid.1x2.fill")
                        .contentTransition(.symbolEffect(.replace.upUp.byLayer))
                        .padding()
                        .foregroundStyle(.foreground)
                }

                Filterbutton(filterLines: $showsFilters, viewLineFiltered: $isFiltered)
                    .padding(.trailing, 7)
            }
            .tpgSurface(interactive: true, legacy: .thinMaterial)
            Spacer()
            AdjustTimeButton(moveTime: moveTime)
                .tpgSurface(interactive: true, legacy: .thinMaterial)
        }
        .padding()
        .foregroundStyle(.primary)
        // Plafonnés, comme les barres d'outils du système : en taille d'accessibilité,
        // ces boutons flottants masquaient le bas de la liste.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }
}

/// Feuille de choix de l'heure des départs.
struct DepartureTimeSheet: View {
    @Binding var time: Date
    let confirm: () -> Void
    @State private var resetAnimation = false

    var body: some View {
        let content = VStack(spacing: 0) {
            Spacer()
            Text("Sélectionnez l'heure de départ")
                .font(.title2)
                .bold()
            HStack {
                DatePicker(selection: $time) {

                }
                .datePickerStyle(.wheel)
                Button(action: {
                    time = Date()
                    resetAnimation.toggle()
                }) {
                    Image(systemName: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                        .font(.title2)
                        .symbolEffect(.rotate, value: resetAnimation)
                }
            }
            if #available(iOS 26, *) {
                Button(action: confirm) {
                    HStack {
                        Spacer()
                        Text("Selectionner")
                        Spacer()
                    }
                    .frame(height: 40)
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button(action: confirm) {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.accent)
                        .frame(height: 50)
                        .shadow(color: Color.customShadows, radius: 1.5, y: 1)
                        .overlay(Text("Selectionner").foregroundStyle(.white))
                }
                .padding(.bottom)
            }
        }
        .padding()
        .presentationDetents([.fraction(0.4)])
        if #available(iOS 26, *) {
            content
        } else {
            content
                .presentationBackground(.thinMaterial)
        }
    }
}

/// Feuille de filtre des départs par ligne et destination.
struct LineFilterSheet: View {
    /// Départs groupés par clé « ligne;destination ».
    let groups: [String: [StopEvent]]
    @Binding var selection: Set<String>
    @Binding var isFiltered: Bool
    let done: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Filtrer par lignes")
                .font(.title2)
                .bold()
                .padding()

            ScrollView {
                VStack {
                    ForEach(groups.keys.sorted(by: lineGroupPrecedes), id: \.self) { key in
                        let splitLine = splitString(key, separator: ";")
                        Button(action: {
                            isFiltered = true
                            if selection.contains(key) {
                                selection.remove(key)
                            } else {
                                selection.insert(key)
                            }
                        }) {
                            HStack {
                                Image(systemName: selection.contains(key) ? "checkmark.circle.fill" : "circle")
                                BusLineIcon(lineName: splitLine.0, operatorName: groups[key]?.first?.operatorName ?? "")
                                Image(systemName: "arrow.right")
                                Text(splitLine.1)
                                Spacer()
                            }
                            .padding()
                        }
                        .foregroundStyle(.primary)
                    }
                }
            }
            .mask {
                Rectangle()
                    .overlay(alignment: .top) {
                        ScrollMask(leading: false, vertical: true, gradientLength: 30)
                    }
            }
            .mask {
                Rectangle()
                    .overlay(alignment: .bottom) {
                        ScrollMask(leading: true, vertical: true, gradientLength: 30)
                    }
            }

            if !selection.isEmpty {
                Button(role: .destructive, action: {
                    isFiltered = false
                    selection = []
                }) {
                    HStack {
                        Label("Supprimer les filtres", systemImage: "xmark.circle")
                        Spacer()
                    }
                    .frame(height: 40)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)
            }

            Button(action: done) {
                HStack {
                    Label("Filtrer", systemImage: "line.3.horizontal.decrease")
                    Spacer()
                }
                .padding()
                .frame(height: 40)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal)
        }
        .padding(.top)
        .presentationDetents([.fraction(0.7)])
    }
}

/// Message quand un arrêt n'a pas de départ à afficher.
struct DeparturesUnavailableText: View {
    /// Code d'erreur OJP renvoyé par `StopManager`.
    let errorMessage: String

    var body: some View {
        if errorMessage == "STOPEVENT_LOCATIONUNSERVED" {
            Text("Malheureusement, cet arrêt n'est pas disponible depuis l'application, ou n'est pas desservi")
        } else {
            Text("Pas de départs trouvés")
        }
    }
}
