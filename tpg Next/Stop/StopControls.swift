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
    @Environment(\.layout) private var layout
    let stopName: String
    let stopSloid: String
    let quays: [Quay]

    var body: some View {
        Menu {
            Button(action: toggleFavorite) {
                favoritesViewModel.isFavoriteID(stopSloid) ? Label("Retirer des favoris", systemImage: "star.fill") : Label("Ajouter aux favoris", systemImage: "star")
            }
            Divider()
            // Sur grand écran, la carte des quais est déjà affichée : son plein écran est sur elle.
            if !quays.isEmpty, !layout.showsSecondaryPane {
                Button {
                    openRoute(.stopMap(quays: quays, sloid: stopSloid, name: stopName))
                } label: {
                    Label("Carte des quais", systemImage: "map")
                }
            }
            TripActionsMenu(stop: createStop(nomarret: stopName, sloid: sloidHarmonizer(code: stopSloid)), includesQuickTrip: false)
        } label: {
            Label("Plus d'actions", systemImage: "ellipsis")
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

/// Les boutons du haut de la page d'un arrêt, en éléments de barre du système (iOS 26) : le
/// système dessine le verre, les regroupe, montre l'état de la bascule et replie ce qui ne tient
/// pas. Le temps restant (bascule), puis le menu « … ». Le choix de l'heure est en bas, entre
/// les flèches (`TimeShiftButtons`).
@available(iOS 26, *)
struct StopToolbar: ToolbarContent {
    @Binding var showTime: Bool
    let stopName: String
    let stopSloid: String
    let quays: [Quay]

    var body: some ToolbarContent {
        TrailingBarButtons(showTime: $showTime) {
            StopActionsMenu(stopName: stopName, stopSloid: stopSloid, quays: quays)
        }
    }
}

/// Les boutons du bas de la liste des départs (iOS 26), posés par `.safeAreaBar` sur la colonne
/// de la liste : une barre d'outils du bas ne s'affiche pas avec la barre d'onglets, et couvrirait
/// les deux moitiés sur grand écran. Deux capsules de verre, comme les groupes d'une barre
/// d'outils : tri et filtre, puis départs précédents et suivants.
@available(iOS 26, *)
struct StopBottomBar: View {
    @Binding var isGroupedByLine: Bool
    /// Un filtre est posé : le bouton est actif.
    let isFiltered: Bool
    /// La capsule du filtre est ouverte : le bouton est seulement sélectionné.
    let isFilterOpen: Bool
    let showFilters: () -> Void
    let moveTime: (_ earlier: Bool) -> Void
    /// L'horloge, entre les flèches : la liste n'est plus à l'heure actuelle (actif), le choix de
    /// l'heure est ouvert (sélectionné).
    var isShifted = false
    var isTimeOpen = false
    var chooseTime: (() -> Void)?
    // Le filtre rebondit quand il s'allume et tremble quand il s'éteint.
    @State private var filterOn = false
    @State private var filterOff = false

    /// Dans le `GlassEffectContainer` de la barre (voir `StopView`), avec la capsule du filtre.
    var body: some View {
        HStack {
                GlassBarGroup {
                    GlassBarButton("Trier par ligne", isActive: isGroupedByLine) {
                        isGroupedByLine.toggle()
                    } icon: {
                        Image(systemName: "rectangle.grid.1x2")
                            .symbolVariant(isGroupedByLine ? .fill : .none)
                            .contentTransition(.symbolEffect(.replace.upUp.byLayer))
                    }
                    GlassBarButton("Filtrer", isActive: isFiltered, isSelected: isFilterOpen, action: showFilters) {
                        Image(systemName: "line.3.horizontal.decrease")
                            .symbolEffect(.bounce.up.byLayer, value: filterOn)
                            .symbolEffect(.wiggle, value: filterOff)
                    }
                }
                Spacer()
                TimeShiftButtons(moveTime: moveTime, isShifted: isShifted, isClockOpen: isTimeOpen,
                                 chooseTime: chooseTime)
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
        // Plafonnés, comme les barres d'outils du système.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .onChange(of: isFiltered) {
            if isFiltered { filterOn.toggle() } else { filterOff.toggle() }
        }
    }
}

/// Le filtre des départs, au-dessus du bouton de filtre (iOS 26) : une capsule de verre avec les
/// lignes de l'arrêt, puis, pour une ligne à plusieurs directions, une bulle au-dessus pour les
/// choisir. La liste se filtre à chaque toucher. À droite, ↺ vide la sélection et ✓ referme la
/// capsule, comme un toucher ailleurs. Avant iOS 26 : `LineFilterSheet`.
///
/// Verre non interactif : sur une capsule aussi large, l'effet de toucher assombrissait toute la
/// surface. Ce sont ses boutons qui réagissent.
@available(iOS 26, *)
struct LineFilterBar: View {
    /// Départs groupés par clé « ligne;destination ».
    let groups: [String: [StopEvent]]
    @Binding var selection: Set<String>
    let done: () -> Void
    /// La ligne dont les directions sont ouvertes.
    @State private var openLine: String?

    private struct Line: Identifiable {
        let name: String
        let operatorName: String
        /// Ses clés « ligne;destination », une par direction.
        let keys: [String]
        var id: String { name }
    }

    /// Les lignes de l'arrêt, dans l'ordre des départs par ligne.
    private var lines: [Line] {
        var order: [String] = []
        var keysByLine: [String: [String]] = [:]
        for key in groups.keys.sorted(by: lineGroupPrecedes) {
            let name = splitString(key, separator: ";").0
            if keysByLine[name] == nil { order.append(name) }
            keysByLine[name, default: []].append(key)
        }
        return order.map { name in
            let keys = keysByLine[name] ?? []
            return Line(name: name, operatorName: keys.first.flatMap { groups[$0]?.first?.operatorName } ?? "", keys: keys)
        }
    }

    var body: some View {
        let lines = self.lines
        VStack(alignment: .leading, spacing: 8) {
            if let line = lines.first(where: { $0.name == openLine }), line.keys.count > 1 {
                directions(of: line)
            }
            HStack(spacing: 4) {
                ViewThatFits(in: .horizontal) {
                    lineChips(lines)
                    ScrollView(.horizontal, showsIndicators: false) {
                        lineChips(lines)
                    }
                    .capsuleScrollMask()
                }
                if !selection.isEmpty {
                    Button {
                        selection = []
                        openLine = nil
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.title3)
                            .foregroundStyle(.primary)
                            .frame(width: 40, height: 40)
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Réinitialiser le filtre")
                    .transition(.scale.combined(with: .opacity))
                }
                Button(action: done) {
                    Image(systemName: "checkmark")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(selection.isEmpty ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.white))
                        .frame(width: 44, height: 40)
                        .background(Capsule().fill(selection.isEmpty ? AnyShapeStyle(.fill.tertiary) : AnyShapeStyle(.tint)))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                // Rien à valider : un toucher ailleurs, ou le bouton de filtre, referme la capsule.
                .disabled(selection.isEmpty)
                .accessibilityLabel("Valider le filtre")
            }
            .padding(4)
            .glassEffect(.regular, in: .capsule)
            .glassEffectTransition(.materialize)
        }
        .animation(.snappy, value: openLine)
        .animation(.snappy, value: selection)
    }

    private func lineChips(_ lines: [Line]) -> some View {
        HStack(spacing: 2) {
            ForEach(lines) { line in
                lineChip(line)
            }
        }
    }

    private func lineChip(_ line: Line) -> some View {
        let kept = line.keys.filter(selection.contains).count
        return Button {
            if line.keys.count == 1 {
                toggle(line.keys[0])
                openLine = nil
            } else {
                openLine = openLine == line.name ? nil : line.name
            }
        } label: {
            BusLineIcon(lineName: line.name, operatorName: line.operatorName)
                .padding(.horizontal, 6)
                .frame(minWidth: 48, minHeight: 40)
                .background {
                    // Toutes ses directions gardées : pastille teintée ; une partie : plus pâle.
                    if kept > 0 {
                        Capsule().fill(.tint.opacity(kept == line.keys.count ? 0.35 : 0.15))
                    }
                    if openLine == line.name {
                        Capsule().strokeBorder(.tint, lineWidth: 1.5)
                    }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Ligne \(line.name)"))
        .accessibilityValue(kept == 0 ? Text("") : kept == line.keys.count ? Text("Gardée") : Text("En partie gardée"))
        .accessibilityHint(line.keys.count > 1 ? Text("Choisir la direction") : Text(""))
    }

    private func directions(of line: Line) -> some View {
        let allKept = line.keys.allSatisfy(selection.contains)
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 2) {
                chip(isOn: allKept) {
                    if allKept {
                        selection.subtract(line.keys)
                    } else {
                        selection.formUnion(line.keys)
                    }
                } label: {
                    Text("Toutes").font(.subheadline.weight(.medium))
                }
                ForEach(line.keys, id: \.self) { key in
                    // Comme dans la liste : la commune au-dessus, le nom dessous.
                    chip(isOn: selection.contains(key)) {
                        toggle(key)
                    } label: {
                        StopNameView(splitString(key, separator: ";").1, style: .row)
                    }
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .clipShape(.capsule)
        .padding(4)
        .glassEffect(.regular, in: .capsule)
        // Le verre apparaît et disparaît par la transition qui lui est propre : mis à l'échelle ou
        // en fondu, il se rendait un instant en sombre.
        .glassEffectTransition(.materialize)
    }

    private func chip<Label: View>(isOn: Bool, action: @escaping () -> Void,
                                   @ViewBuilder label: () -> Label) -> some View {
        GlassChip(isOn: isOn, minHeight: 46, action: action, label: label)
    }
}

/// Une pastille des capsules de filtre et d'heure : teintée quand elle est choisie.
@available(iOS 26, *)
struct GlassChip<Label: View>: View {
    let isOn: Bool
    var minHeight: CGFloat = 40
    let action: () -> Void
    let label: Label

    init(isOn: Bool, minHeight: CGFloat = 40, action: @escaping () -> Void, @ViewBuilder label: () -> Label) {
        self.isOn = isOn
        self.minHeight = minHeight
        self.action = action
        self.label = label()
    }

    var body: some View {
        Button(action: action) {
            label
                .foregroundStyle(isOn ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
                .padding(.horizontal, 14)
                .frame(minHeight: minHeight)
                .background {
                    if isOn {
                        Capsule().fill(.tint)
                    }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

@available(iOS 26, *)
private extension LineFilterBar {
    func toggle(_ key: String) {
        if selection.contains(key) {
            selection.remove(key)
        } else {
            selection.insert(key)
        }
    }
}

extension View {
    /// Le masque d'une rangée qui défile dans une capsule : l'arrondi de la capsule à gauche, un
    /// fondu à droite, avant les boutons.
    func capsuleScrollMask() -> some View {
        mask {
            HStack(spacing: 0) {
                UnevenRoundedRectangle(topLeadingRadius: 20, bottomLeadingRadius: 20, style: .continuous)
                LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing)
                    .frame(width: 20)
            }
        }
    }
}

/// Le choix de l'heure des départs, au-dessus de l'horloge (iOS 26), comme le filtre : une
/// capsule avec « Maintenant » et les jours, puis, au-dessus, une bulle avec la roue des heures.
/// Rien ne s'applique avant ✓ (chaque changement relancerait une requête) ; un toucher ailleurs
/// annule. « Maintenant » s'applique aussitôt. Avant iOS 26 : `DepartureTimeSheet`.
@available(iOS 26, *)
struct DepartureTimeBar: View {
    /// L'heure choisie, et ✓.
    let apply: (Date) -> Void
    /// « Maintenant » : la liste suit de nouveau l'heure actuelle.
    let returnToNow: () -> Void
    @State private var draft: Date

    init(time: Date, apply: @escaping (Date) -> Void, returnToNow: @escaping () -> Void) {
        self.apply = apply
        self.returnToNow = returnToNow
        _draft = State(initialValue: time)
    }

    /// Aujourd'hui et les six jours suivants.
    private var days: [Date] {
        let today = Calendar.current.startOfDay(for: .now)
        return (0..<7).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: today) }
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            DatePicker("Heure", selection: $draft, displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .frame(width: 200, height: 120)
                .clipped()
//                .padding(.horizontal, 12)
//                .padding(.vertical, 4)
                .glassEffect(.regular, in: .rect(cornerRadius: 28))
                .glassEffectTransition(.materialize)
            HStack(spacing: 4) {
                ViewThatFits(in: .horizontal) {
                    chips
                    ScrollView(.horizontal, showsIndicators: false) {
                        chips
                    }
                    .capsuleScrollMask()
                }
                Button {
                    apply(draft)
                } label: {
                    Image(systemName: "checkmark")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 40)
                        .background(Capsule().fill(.tint))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Afficher les départs à cette heure")
            }
            .padding(4)
            .glassEffect(.regular, in: .capsule)
            .glassEffectTransition(.materialize)
        }
        .animation(.snappy, value: draft)
    }

    private var chips: some View {
        HStack(spacing: 2) {
            GlassChip(isOn: false, action: returnToNow) {
                Text("Maintenant").font(.subheadline.weight(.medium))
            }
            ForEach(days, id: \.self) { day in
                GlassChip(isOn: Calendar.current.isDate(draft, inSameDayAs: day)) {
                    draft = Self.date(day, at: draft)
                } label: {
                    Text(Self.title(of: day)).font(.subheadline.weight(.medium))
                }
            }
        }
    }

    /// Le jour `day` à l'heure de `time`.
    private static func date(_ day: Date, at time: Date) -> Date {
        let clock = Calendar.current.dateComponents([.hour, .minute], from: time)
        return Calendar.current.date(bySettingHour: clock.hour ?? 0, minute: clock.minute ?? 0, second: 0, of: day) ?? day
    }

    /// « Aujourd'hui », « Demain », puis « jeu. 2 ».
    private static func title(of day: Date) -> String {
        if Calendar.current.isDateInToday(day) { return String(localized: "Aujourd'hui") }
        if Calendar.current.isDateInTomorrow(day) { return String(localized: "Demain") }
        return day.formatted(.dateTime.weekday(.abbreviated).day())
    }
}

/// Départs ou itinéraires précédents et suivants, dans une capsule de verre (iOS 26). Les
/// flèches rebondissent à chaque toucher. Avant iOS 26 : `AdjustTimeButton`.
@available(iOS 26, *)
struct TimeShiftButtons: View {
    let moveTime: (_ earlier: Bool) -> Void
    var earlierTitle: LocalizedStringKey = "Départs précédents"
    var laterTitle: LocalizedStringKey = "Départs suivants"
    /// L'horloge entre les flèches (`chooseTime`) : active quand la liste n'est plus à l'heure
    /// actuelle, sélectionnée quand le choix de l'heure est ouvert. Sans `chooseTime`, pas d'horloge.
    var isShifted = false
    var isClockOpen = false
    var chooseTime: (() -> Void)?
    @State private var earlier = false
    @State private var later = false
    @State private var clock = false

    var body: some View {
        GlassBarGroup {
            GlassBarButton(earlierTitle) {
                moveTime(true)
                earlier.toggle()
            } icon: {
                Image(systemName: "text.line.first.and.arrowtriangle.forward")
                    .symbolEffect(.bounce.down.byLayer, value: earlier)
            }
            if let chooseTime {
                GlassBarButton("Choisir l'heure", isActive: isShifted, isSelected: isClockOpen) {
                    chooseTime()
                    clock.toggle()
                } icon: {
                    Image(systemName: "clock")
                        .symbolEffect(.bounce.down.byLayer, value: clock)
                }
            }
            GlassBarButton(laterTitle) {
                moveTime(false)
                later.toggle()
            } icon: {
                Image(systemName: "text.line.last.and.arrowtriangle.forward")
                    .symbolEffect(.bounce.down.byLayer, value: later)
            }
        }
    }
}

/// Un groupe de boutons dans une capsule de verre, comme un groupe de barre d'outils (iOS 26).
@available(iOS 26, *)
struct GlassBarGroup<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        HStack(spacing: 0) {
            content
        }
        .padding(4)
        .glassEffect(.regular.interactive(), in: .capsule)
    }
}

/// Un bouton de `GlassBarGroup`. Actif, il prend la forme que le système donne à une bascule
/// active de la barre du haut (le temps restant) : l'icône blanche sur une pastille de la
/// couleur de l'app.
@available(iOS 26, *)
struct GlassBarButton<Icon: View>: View {
    let title: LocalizedStringKey
    var isActive = false
    /// Sélectionné sans être actif (le panneau qu'il ouvre est affiché) : une pastille discrète.
    var isSelected = false
    let action: () -> Void
    @ViewBuilder var icon: Icon

    init(_ title: LocalizedStringKey, isActive: Bool = false, isSelected: Bool = false,
         action: @escaping () -> Void, @ViewBuilder icon: () -> Icon) {
        self.title = title
        self.isActive = isActive
        self.isSelected = isSelected
        self.action = action
        self.icon = icon()
    }

    var body: some View {
        Button(action: action) {
            icon
                .font(.title3)
                .foregroundStyle(isActive ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
                .frame(width: 48, height: 40)
                .background {
                    if isActive {
                        Capsule().fill(.tint)
                    } else if isSelected {
                        Capsule().fill(.fill.secondary)
                    }
                }
                .contentShape(Capsule())
                .animation(.snappy, value: isActive)
                .animation(.snappy, value: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(title))
        .accessibilityAddTraits(isActive || isSelected ? .isSelected : [])
    }
}

/// Boutons flottants au bas de la liste : tri par ligne, filtres, décalage de l'heure.
/// Avant iOS 26 ; ensuite, `StopToolbar`.
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

#Preview("Contrôles flottants") {
    @Previewable @State var grouped = false
    @Previewable @State var showsFilters = false
    @Previewable @State var filtered = false
    @Previewable @State var shift = 0
    VStack {
        Text(verbatim: "Tri par ligne : \(grouped) · filtre : \(filtered) · décalage : \(shift)")
            .font(.caption)
        Toggle("Filtre actif" as String, isOn: $filtered)
            .padding(.horizontal, 40)
        Spacer()
        StopFloatingControls(isGroupedByLine: grouped, toggleGrouping: { grouped.toggle() },
                             showsFilters: $showsFilters, isFiltered: $filtered,
                             moveTime: { earlier in shift += earlier ? -1 : 1 })
    }
    .previewEnvironment(navigation: false)
}

#Preview("Choix de l'heure — feuille (avant iOS 26)") {
    @Previewable @State var time = Date()
    Color.clear
        .sheet(isPresented: .constant(true)) {
            DepartureTimeSheet(time: $time) {}
        }
        .previewEnvironment(navigation: false)
}

#Preview("Filtre des lignes — feuille (avant iOS 26)") {
    @Previewable @State var selection: Set<String> = []
    @Previewable @State var filtered = false
    Color.clear
        .sheet(isPresented: .constant(true)) {
            LineFilterSheet(groups: PreviewData.departures.groupedByLineAndDestination(),
                            selection: $selection, isFiltered: $filtered) {}
        }
        .previewEnvironment(navigation: false)
}

#Preview("Menu de l'arrêt") {
    Color.clear
        .toolbar {
            StopActionsMenu(stopName: PreviewData.rive.name, stopSloid: PreviewData.rive.sloid, quays: PreviewData.quays)
        }
        .previewEnvironment()
}

#Preview("Aucun départ", traits: .sizeThatFitsLayout) {
    VStack(spacing: 30) {
        DeparturesUnavailableText(errorMessage: "STOPEVENT_LOCATIONUNSERVED")
        DeparturesUnavailableText(errorMessage: "")
    }
    .padding()
}

// MARK: - Aperçus iOS 26
// La barre du bas complète, sur une liste de départs : aperçus « Barre du bas » de `StopView`.

#Preview("Filtre des lignes — capsule") {
    @Previewable @State var selection: Set<String> = []
    VStack {
        Text(verbatim: "\(selection.count) direction(s) gardée(s)")
            .font(.caption)
        Spacer()
        if #available(iOS 26, *) {
            GlassEffectContainer(spacing: 8) {
                LineFilterBar(groups: PreviewData.departures.groupedByLineAndDestination(),
                              selection: $selection) {}
            }
            .padding(.horizontal)
        }
    }
    .previewEnvironment(navigation: false)
}

#Preview("Choix de l'heure — capsule") {
    @Previewable @State var time = Date()
    @Previewable @State var log = "—"
    VStack {
        Text(verbatim: log)
            .font(.caption)
        Spacer()
        if #available(iOS 26, *) {
            GlassEffectContainer(spacing: 8) {
                DepartureTimeBar(time: time) { date in
                    time = date
                    log = "Validé : " + date.formatted(date: .abbreviated, time: .shortened)
                } returnToNow: {
                    time = Date()
                    log = "Maintenant"
                }
            }
            .padding(.horizontal)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
    .previewEnvironment(navigation: false)
}

#Preview("Boutons de verre", traits: .sizeThatFitsLayout) {
    @Previewable @State var grouped = false
    @Previewable @State var shift = 0
    VStack(alignment: .leading, spacing: 16) {
        if #available(iOS 26, *) {
            // Normal, sélectionné (panneau ouvert), actif (réglage posé).
            GlassBarGroup {
                GlassBarButton("Filtrer") {} icon: { Image(systemName: "line.3.horizontal.decrease") }
                GlassBarButton("Filtrer", isSelected: true) {} icon: { Image(systemName: "line.3.horizontal.decrease") }
                GlassBarButton("Filtrer", isActive: true) {} icon: { Image(systemName: "line.3.horizontal.decrease") }
            }
            // Flèches seules (itinéraires), puis avec l'horloge décalée (arrêt).
            TimeShiftButtons(moveTime: { shift += $0 ? -1 : 1 })
            TimeShiftButtons(moveTime: { shift += $0 ? -1 : 1 }, isShifted: true, chooseTime: {})
            HStack(spacing: 2) {
                GlassChip(isOn: true) {} label: { Text(verbatim: "Aujourd'hui") }
                GlassChip(isOn: false) {} label: { Text(verbatim: "Demain") }
            }
            .padding(4)
            .glassEffect(.regular, in: .capsule)
            StopBottomBar(isGroupedByLine: $grouped, isFiltered: true, isFilterOpen: false, showFilters: {},
                          moveTime: { shift += $0 ? -1 : 1 }, isShifted: false, chooseTime: {})
            Text(verbatim: "Décalage : \(shift)")
                .font(.caption)
        }
    }
    .padding()
    .background(Color.color1)
}

#Preview("Barre du haut de l'arrêt") {
    @Previewable @State var showTime = true
    Text(verbatim: showTime ? "Heure de passage" : "Temps restant")
        .toolbar {
            if #available(iOS 26, *) {
                StopToolbar(showTime: $showTime, stopName: PreviewData.rive.name,
                            stopSloid: PreviewData.rive.sloid, quays: PreviewData.quays)
            }
        }
        .navigationTitle(PreviewData.rive.name)
        .navigationBarTitleDisplayMode(.inline)
        .previewEnvironment()
}
