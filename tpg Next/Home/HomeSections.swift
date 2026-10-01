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
    case nextTrip, favorites, places, departures, map

    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .nextTrip: "Prochain trajet"
        case .favorites: "Favoris"
        case .places: "Lieux favoris"
        case .departures: "Départs"
        case .map: "Autour de vous"
        }
    }

    var color: Color {
        switch self {
        case .nextTrip: .teal
        case .favorites: .yellow
        case .places: .red
        case .departures: .blue
        case .map: .green
        }
    }

    var systemImage: String {
        switch self {
        case .nextTrip: "clock"
        case .favorites: "star"
        case .places: "mappin.and.ellipse"
        case .departures: "list.bullet"
        case .map: "map"
        }
    }

    static let defaultOrder: [HomeSection] = [.nextTrip, .favorites, .places, .departures, .map]

    /// L'ordre enregistré (`SettingKey.homeSectionsOrder`). Une section inconnue est ignorée.
    /// Une section absente (ajoutée par une version plus récente) se place après celle qui la
    /// précède dans l'ordre par défaut : les lieux favoris suivent les favoris, plutôt que la carte.
    static func order(from stored: String) -> [HomeSection] {
        var order: [HomeSection] = []
        for section in stored.split(separator: ",").compactMap({ HomeSection(rawValue: String($0)) })
        where !order.contains(section) {
            order.append(section)
        }
        for (index, section) in defaultOrder.enumerated() where !order.contains(section) {
            let previous = defaultOrder[..<index].last(where: order.contains)
            let position = previous.flatMap(order.firstIndex(of:)).map { $0 + 1 } ?? 0
            order.insert(section, at: position)
        }
        return order
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
/// veut pas. En cartes, comme les paramètres.
struct HomeLayoutView: View {
    @AppStorage(SettingKey.homeSectionsOrder) private var stored = ""
    @AppStorage(SettingKey.homeHiddenSections) private var storedHidden = ""
    @Environment(\.layout) private var layout

    private var order: [HomeSection] { HomeSection.order(from: stored) }
    private var hidden: Set<HomeSection> { HomeSection.hidden(from: storedHidden) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                CardSection(footer: layout.showsSecondaryPane
                            ? "Maintenez une section puis faites-la glisser pour changer l'ordre. L'œil la masque ou l'affiche à nouveau. Sur grand écran, les départs restent dans la colonne de droite ; l'ordre s'applique aux autres sections."
                            : "Maintenez une section puis faites-la glisser pour changer l'ordre. L'œil la masque ou l'affiche à nouveau.") {
                    ReorderableCardRows(items: order) { from, to in
                        var order = self.order
                        order.move(fromOffsets: IndexSet(integer: from), toOffset: to)
                        stored = HomeSection.stored(order)
                    } row: { section in
                        row(section)
                    }
                }
                CardSection {
                    Button {
                        withAnimation {
                            stored = ""
                            storedHidden = ""
                        }
                    } label: {
                        SettingsRow("Rétablir l'accueil par défaut", systemImage: "arrow.counterclockwise", color: .gray)
                    }
                    .buttonStyle(.plain)
                    .disabled(order == HomeSection.defaultOrder && hidden.isEmpty)
                    .opacity(order == HomeSection.defaultOrder && hidden.isEmpty ? 0.5 : 1)
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 30)
        }
        .readableScrollContent()
        .navigationTitle("Organiser l'accueil")
        .navigationBarTitleDisplayMode(.inline)
    }
}

extension HomeLayoutView {
    private func row(_ section: HomeSection) -> some View {
        let isHidden = hidden.contains(section)
        // La dernière section visible reste : un accueil vide n'aurait plus rien à dire.
        let isLastVisible = !isHidden && order.filter { !hidden.contains($0) }.count == 1
        return HStack(spacing: 14) {
            SettingsIcon(systemImage: section.systemImage, color: section.color)
                .opacity(isHidden ? 0.35 : 1)
            Text(section.title)
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
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isLastVisible)
            .opacity(isLastVisible ? 0.4 : 1)
            .accessibilityLabel(Text(isHidden ? "Afficher" : "Masquer") + Text(verbatim: " ") + Text(section.title))
        }
        .frame(minHeight: 50)
        .sensoryFeedback(.selection, trigger: isHidden)
    }
}

#Preview("Organiser l'accueil") {
    NavigationStack {
        HomeLayoutView()
    }
}

#Preview("Organiser l'accueil — sections masquées") {
    NavigationStack {
        HomeLayoutView()
    }
    .previewSettings([SettingKey.homeHiddenSections: HomeSection.stored([.departures, .map])])
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
