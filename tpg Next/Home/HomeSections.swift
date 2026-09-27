//
//  HomeSections.swift
//  tpg Next
//
//  Les sections de l'accueil, dans l'ordre choisi par l'utilisateur, et sans celles qu'il a
//  masquées (Paramètres → Organiser l'accueil). Réglage propre à chaque appareil.
//

import SwiftUI
import tpgNextFunc

enum HomeSection: String, CaseIterable, Identifiable {
    case nextTrip, favorites, departures, map

    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .nextTrip: "Prochain trajet"
        case .favorites: "Favoris"
        case .departures: "Départs"
        case .map: "Autour de vous"
        }
    }

    var systemImage: String {
        switch self {
        case .nextTrip: "clock"
        case .favorites: "star"
        case .departures: "list.bullet"
        case .map: "map"
        }
    }

    static let defaultOrder: [HomeSection] = [.nextTrip, .favorites, .departures, .map]

    /// L'ordre enregistré (`SettingKey.homeSectionsOrder`). Une section inconnue est ignorée,
    /// une section absente (ajoutée par une version plus récente) rejoint la fin.
    static func order(from stored: String) -> [HomeSection] {
        var order: [HomeSection] = []
        for section in stored.split(separator: ",").compactMap({ HomeSection(rawValue: String($0)) })
        where !order.contains(section) {
            order.append(section)
        }
        return order + defaultOrder.filter { !order.contains($0) }
    }

    static func stored(_ sections: [HomeSection]) -> String {
        sections.map(\.rawValue).joined(separator: ",")
    }

    /// Les sections masquées (`SettingKey.homeHiddenSections`).
    static func hidden(from stored: String) -> Set<HomeSection> {
        Set(stored.split(separator: ",").compactMap { HomeSection(rawValue: String($0)) })
    }
}

/// Réordonner les sections de l'accueil en les faisant glisser, et masquer celles dont on ne
/// veut pas.
struct HomeLayoutView: View {
    @AppStorage(SettingKey.homeSectionsOrder) private var stored = ""
    @AppStorage(SettingKey.homeHiddenSections) private var storedHidden = ""
    @Environment(\.layout) private var layout

    private var order: [HomeSection] { HomeSection.order(from: stored) }
    private var hidden: Set<HomeSection> { HomeSection.hidden(from: storedHidden) }

    var body: some View {
        List {
            Section {
                ForEach(order) { section in
                    row(section)
                }
                .onMove { source, destination in
                    var order = self.order
                    order.move(fromOffsets: source, toOffset: destination)
                    stored = HomeSection.stored(order)
                }
            } footer: {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Touchez l'œil pour masquer une section ou l'afficher à nouveau.")
                    if layout.showsSecondaryPane {
                        Text("Sur grand écran, les départs restent dans la colonne de droite ; l'ordre s'applique aux autres sections.")
                    }
                }
            }
            Section {
                Button("Rétablir l'accueil par défaut") {
                    withAnimation {
                        stored = ""
                        storedHidden = ""
                    }
                }
                .disabled(order == HomeSection.defaultOrder && hidden.isEmpty)
            }
        }
        .environment(\.editMode, .constant(.active))
        .navigationTitle("Organiser l'accueil")
        .navigationBarTitleDisplayMode(.inline)
    }
}

extension HomeLayoutView {
    private func row(_ section: HomeSection) -> some View {
        let isHidden = hidden.contains(section)
        // La dernière section visible reste : un accueil vide n'aurait plus rien à dire.
        let isLastVisible = !isHidden && order.filter { !hidden.contains($0) }.count == 1
        return HStack {
            Label(section.title, systemImage: section.systemImage)
                .foregroundStyle(isHidden ? .secondary : .primary)
            Spacer()
            Button {
                var hidden = self.hidden
                if isHidden { hidden.remove(section) } else { hidden.insert(section) }
                withAnimation(.snappy) {
                    storedHidden = HomeSection.stored(HomeSection.defaultOrder.filter(hidden.contains))
                }
            } label: {
                Image(systemName: isHidden ? "eye.slash" : "eye")
                    .contentTransition(.symbolEffect(.replace))
                    .foregroundStyle(isHidden ? Color.secondary : Color.accentColor)
                    .frame(width: 44, height: 32)
            }
            .buttonStyle(.borderless)
            .disabled(isLastVisible)
            .accessibilityLabel(Text(isHidden ? "Afficher" : "Masquer") + Text(verbatim: " ") + Text(section.title))
        }
        .sensoryFeedback(.selection, trigger: isHidden)
    }
}

#Preview("Organiser l'accueil") {
    NavigationStack {
        HomeLayoutView()
    }
}

/// Le titre d'une section de l'accueil : une seule taille pour toutes.
struct HomeSectionTitle: View {
    let title: LocalizedStringKey

    init(_ title: LocalizedStringKey) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.title2.bold())
            .padding(.horizontal, 15)
    }
}
