//
//  CardSection.swift
//  tpg Next
//
//  Les sections des paramètres et du guide, dans le style de l'app : un titre, puis une carte
//  légèrement ombrée (`BasicCard`) sur le fond blanc, et un texte d'explication dessous.
//

import SwiftUI

/// Une section en carte. Les lignes se séparent par `CardDivider()`, posé entre elles.
struct CardSection<Content: View>: View {
    var title: Text?
    var footer: Text?
    @ViewBuilder var content: Content

    init(_ title: LocalizedStringKey? = nil, footer: LocalizedStringKey? = nil,
         @ViewBuilder content: () -> Content) {
        self.title = title.map { Text($0) }
        self.footer = footer.map { Text($0) }
        self.content = content()
    }

    /// Un texte d'explication calculé (« Du lundi au vendredi »).
    init(_ title: LocalizedStringKey? = nil, footer: Text?, @ViewBuilder content: () -> Content) {
        self.title = title.map { Text($0) }
        self.footer = footer
        self.content = content()
    }

    /// Les titres du guide (`LocalizedStringResource`).
    init(_ title: LocalizedStringResource, @ViewBuilder content: () -> Content) {
        self.title = Text(title)
        self.footer = nil
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title {
                title
                    .font(.headline)
                    .padding(.leading, 8)
            }
            VStack(alignment: .leading, spacing: 0) {
                content
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(BasicCard(cornerRadius: 26))
            if let footer {
                footer
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// Le trait entre deux lignes d'une carte, aligné sur le texte, après l'icône.
struct CardDivider: View {
    var inset: CGFloat = 44

    var body: some View {
        Divider()
            .padding(.leading, inset)
    }
}

/// L'icône d'une ligne : le symbole blanc dans un carré de couleur, comme dans les Réglages d'iOS.
struct SettingsIcon: View {
    let systemImage: String
    let color: Color
    var size: CGFloat = 30

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: size * 0.5, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(color.gradient, in: RoundedRectangle(cornerRadius: size * 0.25, style: .continuous))
            .accessibilityHidden(true)
    }
}

/// Une ligne de carte : l'icône, le titre (et un sous-titre), puis à droite un nombre et le
/// chevron d'une ligne qui ouvre une page.
struct SettingsRow: View {
    let title: Text
    var subtitle: Text?
    let systemImage: String
    let color: Color
    var value: Int?
    var showsChevron = false

    init(_ title: LocalizedStringKey, subtitle: LocalizedStringKey? = nil, systemImage: String, color: Color,
         value: Int? = nil, showsChevron: Bool = false) {
        self.title = Text(title)
        self.subtitle = subtitle.map { Text($0) }
        self.systemImage = systemImage
        self.color = color
        self.value = value
        self.showsChevron = showsChevron
    }

    /// Un titre déjà mis en forme (« Genève **Rive** → … »).
    init(_ title: Text, subtitle: String? = nil, systemImage: String, color: Color, showsChevron: Bool = false) {
        self.title = title
        self.subtitle = subtitle.map { Text(verbatim: $0) }
        self.systemImage = systemImage
        self.color = color
        self.showsChevron = showsChevron
    }

    /// Un titre et un sous-titre venus des données (nom d'un trajet), tels quels.
    init(verbatim title: String, subtitle: String? = nil, systemImage: String, color: Color,
         showsChevron: Bool = false) {
        self.title = Text(verbatim: title)
        self.subtitle = subtitle.map { Text(verbatim: $0) }
        self.systemImage = systemImage
        self.color = color
        self.showsChevron = showsChevron
    }

    var body: some View {
        HStack(spacing: 14) {
            SettingsIcon(systemImage: systemImage, color: color)
            VStack(alignment: .leading, spacing: 2) {
                title
                    .foregroundStyle(.primary)
                if let subtitle {
                    subtitle
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .multilineTextAlignment(.leading)
            Spacer(minLength: 4)
            if let value {
                Text(verbatim: "\(value)")
                    .foregroundStyle(.secondary)
            }
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.footnote.bold())
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(minHeight: 50)
        .contentShape(Rectangle())
    }
}

/// Une ligne de carte qui ouvre une page.
struct CardLink: View {
    let route: AppRoute
    let row: SettingsRow

    init(_ route: AppRoute, @ViewBuilder row: () -> SettingsRow) {
        self.route = route
        self.row = row()
    }

    var body: some View {
        NavigationLink(value: route) {
            row
        }
        .buttonStyle(.plain)
    }
}

/// Des lignes de carte qu'on réordonne du doigt : appui long sur une ligne, puis glisser. La
/// carte garde ainsi le style de l'app, là où une `List` en mode édition imposait le sien.
/// VoiceOver propose « Monter » et « Descendre » sur chaque ligne.
struct ReorderableCardRows<Item: Identifiable, Row: View>: View {
    let items: [Item]
    var dividerInset: CGFloat = 44
    /// Comme `List.onMove` : `to` est la place d'insertion, avant le déplacement.
    let move: (_ from: Int, _ to: Int) -> Void
    @ViewBuilder let row: (Item) -> Row
    @State private var dragged: Item.ID?

    var body: some View {
        let ids = items.map(\.id)
        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
            if index > 0 {
                CardDivider(inset: dividerInset)
            }
            HStack(spacing: 12) {
                row(item)
                Image(systemName: "line.3.horizontal")
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .background(Color.color1)
            .contentShape(.dragPreview, RoundedRectangle(cornerRadius: 14, style: .continuous))
            .onDrag {
                dragged = item.id
                return NSItemProvider(object: String(describing: item.id) as NSString)
            }
            .onDrop(of: [.text], delegate: CardRowDropDelegate(target: item.id, ids: ids, dragged: $dragged) { from, to in
                withAnimation(.snappy) { move(from, to) }
            })
            .accessibilityAction(named: Text("Monter")) {
                if index > 0 { move(index, index - 1) }
            }
            .accessibilityAction(named: Text("Descendre")) {
                if index < items.count - 1 { move(index, index + 2) }
            }
        }
    }
}

/// La ligne glissée prend la place de celle qu'elle survole, sans attendre d'être lâchée.
private struct CardRowDropDelegate<ID: Hashable>: DropDelegate {
    let target: ID
    let ids: [ID]
    @Binding var dragged: ID?
    let move: (_ from: Int, _ to: Int) -> Void

    func dropEntered(info: DropInfo) {
        guard let dragged, dragged != target,
              let from = ids.firstIndex(of: dragged), let to = ids.firstIndex(of: target) else { return }
        move(from, to > from ? to + 1 : to)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        dragged = nil
        return true
    }
}

#Preview("Section en carte") {
    ScrollView {
        CardSection("Accueil", footer: "Un texte d'explication, sous la carte.") {
            CardLink(.homeLayout) {
                SettingsRow("Organiser l'accueil", systemImage: "rectangle.3.group.fill", color: .blue, showsChevron: true)
            }
            CardDivider()
            SettingsRow("Arrêts favoris", systemImage: "star.fill", color: .yellow, value: 8, showsChevron: true)
            CardDivider()
            Toggle(isOn: .constant(true)) {
                SettingsRow("Rappels avant le départ", systemImage: "bell.fill", color: .red)
            }
        }
        .padding()
    }
    .previewEnvironment()
}
