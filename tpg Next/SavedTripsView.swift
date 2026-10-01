//
//  SavedTripsView.swift
//  tpg Next
//
//  Mes itinéraires : les itinéraires enregistrés et les trajets réguliers, mélangés jour par
//  jour, du haut vers le bas. L'écran montre les prochains ; les itinéraires passés sont
//  au-dessus, repliés derrière un bouton.
//

import SwiftUI
import MapKit
import tpgNextFunc

/// Mes itinéraires, racine de l'onglet Trajets. Sur iPhone, un itinéraire s'ouvre par-dessus et
/// le retour ramène à la liste ; sur grand écran, il se détaille dans la moitié droite, carte
/// comprise, comme dans les résultats d'une recherche.
struct SavedTripsView: View {
    @Environment(\.openRoute) private var openRoute
    @Environment(\.layout) private var layout
    @Environment(SavedTripsModel.self) private var savedTripsModel
    @Environment(RegularTripsModel.self) private var regularTripsModel
    @Environment(\.displayTime) private var now
    @AppStorage(SettingKey.clockTimeByDefault) private var timeDefault = false
    /// Tenu par la navigation : une notification de trajet régulier ouvre l'onglet sur les réguliers.
    @Binding var filter: SavedTripsFilter
    /// Sur grand écran, l'itinéraire détaillé à droite, et la carte de l'agenda qui l'a donné.
    @State private var selectedTrip: TripEvent?
    @State private var selectedItemID: String?
    @State private var showTime = true

    var body: some View {
        AdaptiveSplit {
            SavedTripsAgenda(filter: $filter, selectedItemID: $selectedItemID) { trip in
                if layout.showsSecondaryPane {
                    withAnimation { selectedTrip = trip }
                } else {
                    openRoute(.trip(trip))
                }
            }
        } secondary: {
            TripDetailPane(trip: detailedTrip, showTime: $showTime) {
                withAnimation {
                    selectedTrip = nil
                    selectedItemID = nil
                }
            }
        }
        .onAppear { showTime = timeDefault }
        // Carte retouchée dans l'agenda : le détail se ferme.
        .onChange(of: selectedItemID) {
            if selectedItemID == nil { withAnimation { selectedTrip = nil } }
        }
        // Sur iPhone, rien n'est détaillé à côté : aucune carte ne reste entourée.
        .onChange(of: layout.showsSecondaryPane) {
            if !layout.showsSecondaryPane {
                selectedTrip = nil
                selectedItemID = nil
            }
        }
        .toolbar {
            if layout.showsSecondaryPane, selectedTrip != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    ShowTimeButton(showTime: $showTime)
                }
            }
        }
        .navigationTitle("Trajets")
        // En deux moitiés, un grand titre se réduisait en faisant défiler l'agenda, et la barre
        // rétrécie faisait remonter l'itinéraire détaillé à droite.
        .navigationBarTitleDisplayMode(layout.showsSecondaryPane ? .inline : .automatic)
    }

    /// L'itinéraire détaillé, tel que l'agenda l'affiche : ses itinéraires sont redemandés chaque
    /// minute (retard, horaire modifié, trajet remplacé), le panneau suit. À défaut, celui du toucher.
    private var detailedTrip: TripEvent? {
        guard let selectedItemID else { return selectedTrip }
        if let trip = savedTripsModel.savedTrips.first(where: { AgendaItem.saved($0).id == selectedItemID }) {
            // Passé, il n'est plus redemandé : l'agenda l'affiche tel qu'il a été enregistré.
            let hasPassed = (trip.endDate ?? trip.startDate ?? .distantPast) <= now
            return hasPassed ? trip : savedTripsModel.displayedTrip(for: trip)
        }
        if let occurrence = regularTripsModel.upcoming(after: now).first(where: { AgendaItem.regular($0).id == selectedItemID }) {
            if case .found(let match, _) = regularTripsModel.state(of: occurrence) {
                return match.trip
            }
            return regularTripsModel.displayedTrip(for: occurrence) ?? selectedTrip
        }
        return selectedTrip
    }
}

/// La même liste poussée sur une autre pile, avec son propre filtre.
struct SavedTripsPage: View {
    @State var filter: SavedTripsFilter = .all

    var body: some View {
        SavedTripsView(filter: $filter)
    }
}

/// Ce que montre l'agenda.
enum SavedTripsFilter: String, CaseIterable, Identifiable {
    case all, saved, regular

    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .all: "Tous"
        case .saved: "Enregistrés"
        case .regular: "Réguliers"
        }
    }
}

/// Un itinéraire enregistré ou un trajet régulier, un jour donné.
private enum AgendaItem: Identifiable {
    case saved(TripEvent)
    case regular(RegularTripOccurrence)

    var id: String {
        switch self {
        case .saved(let trip): "saved-\(trip.id)"
        case .regular(let occurrence): "regular-\(occurrence.id)"
        }
    }

    var departure: Date {
        switch self {
        case .saved(let trip): trip.startDate ?? .distantPast
        case .regular(let occurrence): occurrence.plannedDeparture
        }
    }

    /// Arrivé : un trajet en cours reste parmi les prochains.
    func hasPassed(at now: Date) -> Bool {
        switch self {
        case .saved(let trip): (trip.endDate ?? trip.startDate ?? .distantPast) <= now
        // Les trajets réguliers ne donnent que ceux qui ne sont pas encore arrivés.
        case .regular: false
        }
    }
}

/// Les itinéraires jour par jour, filtrés par genre.
struct SavedTripsAgenda: View {
    @Environment(\.layout) private var layout
    @Environment(SavedTripsModel.self) private var savedTripsModel
    @Environment(RegularTripsModel.self) private var regularTripsModel
    @Environment(\.displayTime) private var now
    private var liveActivities = TripLiveActivities.shared
    let onSelect: (TripEvent) -> Void

    @Binding var filter: SavedTripsFilter
    /// La carte détaillée à côté, sur grand écran : entourée. `nil` sur iPhone.
    @Binding var selectedItemID: String?
    /// L'itinéraire à répéter chaque semaine.
    @State private var repeating: TripEvent?
    @State private var editing: RegularTrip?
    @State private var creating = false
    /// Le trajet régulier en cours de chargement après un toucher.
    @State private var opening: String?
    /// Les itinéraires passés, dépliés au-dessus des prochains.
    @State private var showsPast = false
    /// L'itinéraire dont on cherche d'autres horaires.
    @State private var alternatives: AlternativesRequest?

    /// Remplacer un itinéraire enregistré, ou un trajet régulier pour un jour.
    private enum AlternativesRequest: Identifiable {
        case saved(TripEvent)
        case regular(RegularTripOccurrence)

        var id: String {
            switch self {
            case .saved(let trip): "saved-\(trip.id)"
            case .regular(let occurrence): "regular-\(occurrence.id)"
            }
        }
    }

    /// Le haut des prochains.
    private static let upcomingAnchor = "upcoming"
    /// Le sélecteur, en haut de la liste : où revenir en changeant de filtre.
    private static let filterAnchor = "filter"
    /// La fin des itinéraires passés, juste au-dessus des prochains.
    private static let pastEnd = "pastEnd"

    init(filter: Binding<SavedTripsFilter>, selectedItemID: Binding<String?> = .constant(nil),
         onSelect: @escaping (TripEvent) -> Void) {
        _filter = filter
        _selectedItemID = selectedItemID
        self.onSelect = onSelect
    }

    var body: some View {
        let items = self.items
        let past = items.filter { $0.hasPassed(at: now) }
        let upcoming = items.filter { !$0.hasPassed(at: now) }

        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    // Dans la liste et non posé au-dessus : tirée vers le bas, la liste étire le
                    // grand titre, qui passait sur un sélecteur resté immobile. Ils bougent ensemble.
                    Picker("Afficher", selection: $filter) {
                        ForEach(SavedTripsFilter.allCases) { filter in
                            Text(filter.title).tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.bottom, 8)
                    .id(Self.filterAnchor)
                    // Repliés : l'écran s'ouvre sur les prochains sans avoir à défiler, ce qui
                    // n'a pas lieu pendant l'animation de la feuille ou de la pile.
                    if !past.isEmpty {
                        if showsPast {
                            pastSection(past)
                        } else {
                            showPastButton
                        }
                    }
                    upcomingSection(upcoming)
                        .id(Self.upcomingAnchor)
                }
                .padding(.horizontal, 15)
                .padding(.bottom, 30)
                .animation(.default, value: filter)
            }
            // Les passés arrivent au-dessus : on descend jusqu'aux plus récents, les prochains
            // juste en dessous, plutôt que de rester sur les plus anciens.
            .onChange(of: showsPast) {
                if showsPast { proxy.scrollTo(Self.pastEnd, anchor: UnitPoint(x: 0.5, y: 0.7)) }
            }
            .onChange(of: filter) {
                showsPast = false
                // En haut, sélecteur compris : il vient d'être touché, il ne doit pas disparaître.
                proxy.scrollTo(Self.filterAnchor, anchor: .top)
            }
        }
        .readableScrollContent()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    creating = true
                } label: {
                    Label("Nouveau trajet régulier", systemImage: "calendar.badge.plus")
                }
            }
        }
        .sheet(item: $repeating) { trip in
            RegularTripEditor(creatingFrom: trip)
                .environment(regularTripsModel)
        }
        .sheet(item: $editing) { trip in
            RegularTripEditor(trip: trip)
                .environment(regularTripsModel)
        }
        .sheet(isPresented: $creating) {
            NewRegularTripView()
                .environment(regularTripsModel)
        }
        .sheet(item: $alternatives) { request in
            alternativesView(request)
        }
        // Les itinéraires enregistrés, redemandés tant que l'écran est affiché (le modèle
        // espace lui-même les requêtes).
        .task {
            while !Task.isCancelled {
                await savedTripsModel.refresh()
                do { try await Task.sleep(for: .seconds(60)) } catch { break }
            }
        }
    }

    @ViewBuilder
    private func alternativesView(_ request: AlternativesRequest) -> some View {
        switch request {
        case .saved(let trip):
            TripAlternativesView(title: "Autres horaires",
                                 footer: "L'itinéraire choisi remplace celui enregistré.",
                                 replacing: trip) { savedTripsModel.replaceTrip(trip, with: $0) }
        case .regular(let occurrence):
            if let trip = regularTripsModel.trip(for: occurrence) {
                TripAlternativesView(title: "Choisir un autre trajet",
                                     footer: "Pour ce jour seulement : les autres jours gardent le trajet habituel.",
                                     origin: trip.origin, destination: trip.destination,
                                     around: occurrence.target, isArrivalTime: trip.anchor == .arrival,
                                     current: regularTripsModel.displayedTrip(for: occurrence)) {
                    regularTripsModel.choose($0, for: occurrence)
                }
            }
        }
    }

    private var items: [AgendaItem] {
        var items: [AgendaItem] = []
        if filter != .regular {
            items += savedTripsModel.savedTrips.map(AgendaItem.saved)
        }
        if filter != .saved {
            items += regularTripsModel.upcoming(after: now).map(AgendaItem.regular)
        }
        return items.sorted { $0.departure < $1.departure }
    }

    // MARK: Sections

    private var showPastButton: some View {
        Button {
            showsPast = true
        } label: {
            Label("Afficher les itinéraires passés", systemImage: "clock.arrow.circlepath")
                .font(.subheadline)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .frame(maxWidth: .infinity)
        .padding(.top, 6)
    }

    /// Du plus ancien au plus récent, comme les prochains : le temps s'écoule vers le bas.
    private func pastSection(_ past: [AgendaItem]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Itinéraires passés")
                    .font(.title2).bold()
                Spacer()
                Button("Masquer") {
                    withAnimation { showsPast = false }
                }
                .font(.subheadline)
            }
            .padding(.horizontal, 10)
            .padding(.top, 10)
            Text("Ils sont supprimés \(SavedTripsModel.retentionDays) jours après leur arrivée.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
            days(past, arePast: true)
                .opacity(0.7)
            Divider()
                .padding(.vertical, 10)
                .id(Self.pastEnd)
        }
    }

    @ViewBuilder
    private func upcomingSection(_ upcoming: [AgendaItem]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if upcoming.isEmpty {
                emptyView
            } else {
                days(upcoming)
            }

            if filter == .regular, !regularTripsModel.regularTrips.isEmpty {
                regularTripsSection
            }
        }
    }

    /// Aucun prochain itinéraire, selon le filtre.
    @ViewBuilder private var emptyView: some View {
        switch filter {
        case .regular:
            if regularTripsModel.regularTrips.isEmpty {
                RegularTripsEmptyView { creating = true }
            } else {
                Text("Aucun trajet dans les sept prochains jours.")
                    .foregroundStyle(.secondary)
                    .padding(10)
            }
        case .saved:
            AgendaEmptyView(symbol: "scurvepath.stack.fill", isAsset: true,
                            title: "Aucun itinéraire à venir",
                            message: "Dans les résultats d'une recherche, touchez longuement un itinéraire puis « Enregistrer l'itinéraire ».")
        case .all:
            AgendaEmptyView(symbol: "scurvepath.stack.fill", isAsset: true,
                            title: "Aucun itinéraire à venir",
                            message: "Enregistrez un itinéraire depuis les résultats d'une recherche, ou créez un trajet régulier : il reviendra ici chaque jour choisi.") {
                creating = true
            }
        }
    }

    /// Les itinéraires groupés par jour, dans l'ordre des départs.
    private func days(_ items: [AgendaItem], arePast: Bool = false) -> some View {
        let grouped = Dictionary(grouping: items) { Calendar.current.startOfDay(for: $0.departure) }
        return ForEach(grouped.keys.sorted(), id: \.self) { day in
            VStack(alignment: .leading, spacing: 8) {
                Text(Self.dayTitle(day))
                    .font(.title3).bold()
                    .padding(.horizontal, 10)
                    .padding(.top, 10)
                ForEach(grouped[day] ?? []) { item in
                    switch item {
                    case .saved(let trip): savedCard(trip, isPast: arePast)
                    case .regular(let occurrence): regularCard(occurrence)
                    }
                }
            }
        }
    }

    /// Les recettes, pour les modifier.
    private var regularTripsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Mes trajets réguliers")
                .font(.title3).bold()
                .padding(.horizontal, 10)
                .padding(.top, 20)
            ForEach(regularTripsModel.regularTrips) { trip in
                Button { editing = trip } label: {
                    RegularTripRow(trip: trip)
                }
                .buttonStyle(.plain)
                .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: 30))
                .contextMenu {
                    Button {
                        editing = trip
                    } label: {
                        Label("Modifier", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        withAnimation { regularTripsModel.remove(trip) }
                    } label: {
                        Label("Supprimer", systemImage: "trash")
                    }
                }
            }
            Button {
                creating = true
            } label: {
                Label("Nouveau trajet régulier", systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
            .padding(.top, 4)
        }
    }

    // MARK: Cartes

    /// Sur grand écran, retoucher la carte détaillée à côté la désélectionne ; sinon elle s'ouvre.
    private func choose(_ itemID: String, open: () -> Void) {
        if layout.showsSecondaryPane && selectedItemID == itemID {
            withAnimation { selectedItemID = nil }
        } else {
            selectedItemID = itemID
            open()
        }
    }

    /// Un itinéraire enregistré. À venir, il est redemandé à OJP : retard, horaire modifié, ou
    /// plus proposé, avec ce qui le remplacerait.
    private func savedCard(_ trip: TripEvent, isPast: Bool) -> some View {
        let state = isPast ? nil : savedTripsModel.state(of: trip)
        let displayed = isPast ? trip : savedTripsModel.displayedTrip(for: trip)
        let itemID = AgendaItem.saved(trip).id
        return AgendaCard(highlighted: selectedItemID == itemID, open: {
            choose(itemID) { onSelect(displayed) }
        }) {
            VStack(alignment: .leading, spacing: 8) {
                if Self.showsBadge(state) {
                    HStack {
                        Spacer()
                        RegularTripStatusBadge(state: state, isSavedTrip: true)
                    }
                }
                SavedTripView(event: displayed)
                if case .found(let match, _) = state, match.kind != .alternative {
                    RegularTripChanges(changes: RegularTripAlerts.changes(in: match))
                }
            }
        } actions: {
            savedActions(trip, state: state)
        }
        .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: 30))
        .contextMenu {
            if !isPast {
                Button {
                    alternatives = .saved(trip)
                } label: {
                    Label("Autres horaires…", systemImage: "clock.arrow.2.circlepath")
                }
            }
            Button {
                repeating = trip
            } label: {
                Label("Répéter chaque semaine…", systemImage: "calendar.badge.plus")
            }
            Button {
                savedTripsModel.removeTrip(trip)
            } label: {
                Label("Ne plus enregistrer l'itinéraire", image: "scurvepath.stack.fill.badge.minus")
            }
        }
    }

    /// Plus proposé : le meilleur à sa place, déjà cherché, à reprendre d'un toucher. Horaire
    /// modifié ou perturbé : d'autres horaires.
    @ViewBuilder
    private func savedActions(_ trip: TripEvent, state: RegularTripsModel.LiveState?) -> some View {
        switch state {
        case .found(let match, _) where match.kind == .alternative:
            VStack(alignment: .leading, spacing: 8) {
                Label {
                    Text("Cet itinéraire n'est plus proposé. À la place : \(RegularTripAlerts.description(of: match))")
                } icon: {
                    Image(systemName: "xmark.octagon.fill")
                }
                .font(.footnote)
                .foregroundStyle(.red)
                HStack {
                    Button("Remplacer") {
                        withAnimation { savedTripsModel.replaceTrip(trip, with: match.trip) }
                    }
                    .buttonStyle(.borderedProminent)
                    alternativesButton { alternatives = .saved(trip) }
                }
            }
        case .notFound:
            VStack(alignment: .leading, spacing: 8) {
                Label("Plus aucun itinéraire à cette heure-là.", systemImage: "xmark.octagon.fill")
                    .font(.footnote)
                    .foregroundStyle(.red)
                alternativesButton { alternatives = .saved(trip) }
            }
        case .found(let match, _) where !RegularTripAlerts.changes(in: match).isEmpty:
            alternativesButton { alternatives = .saved(trip) }
        default:
            EmptyView()
        }
    }

    /// Loin du départ, OJP n'a que l'horaire : une capsule « Horaire » sur chaque carte ne dirait
    /// rien. Elle n'apparaît qu'avec le temps réel ou un changement.
    private static func showsBadge(_ state: RegularTripsModel.LiveState?) -> Bool {
        switch state {
        case .found(let match, _):
            return match.status.hasRealtime || match.kind != .usual || !match.status.isNormal
        case .notFound:
            return true
        case nil, .loading, .failed:
            return false
        }
    }

    private func alternativesButton(_ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label("Autres horaires…", systemImage: "clock.arrow.2.circlepath")
        }
        .buttonStyle(.bordered)
    }

    @ViewBuilder
    private func regularCard(_ occurrence: RegularTripOccurrence) -> some View {
        if let trip = regularTripsModel.trip(for: occurrence), let displayed = regularTripsModel.displayedTrip(for: occurrence) {
            let state = regularTripsModel.state(of: occurrence)
            let isChosen = trip.isOverridden(on: occurrence.day)
            let itemID = AgendaItem.regular(occurrence).id
            AgendaCard(highlighted: selectedItemID == itemID, open: {
                choose(itemID) { open(occurrence, displayed: displayed) }
            }) {
                UpcomingRegularTripCard(occurrence: occurrence, trip: trip, displayed: displayed,
                                        state: state, isOpening: opening == occurrence.id,
                                        isLive: liveActivities.isTracking(occurrence.id), isChosen: isChosen)
            } actions: {
                if Self.needsAnotherTrip(state) {
                    Button {
                        alternatives = .regular(occurrence)
                    } label: {
                        Label("Choisir un autre trajet…", systemImage: "arrow.triangle.swap")
                    }
                    .buttonStyle(.bordered)
                }
            }
            .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: 30))
            .contextMenu {
                if liveActivities.isTracking(occurrence.id) {
                    Button {
                        liveActivities.stop(occurrence.id)
                    } label: {
                        Label("Arrêter le suivi en direct", systemImage: "stop.circle")
                    }
                } else if liveActivities.areEnabled, occurrence.plannedDeparture.timeIntervalSince(now) < 6 * 3600 {
                    Button {
                        var match: RegularTripMatch?
                        if case .found(let found, _) = state { match = found }
                        liveActivities.start(occurrence: occurrence, of: trip, trip: displayed, match: match)
                    } label: {
                        Label("Suivre en direct", systemImage: "inset.filled.circle")
                    }
                }
                Button {
                    alternatives = .regular(occurrence)
                } label: {
                    Label("Choisir un autre trajet…", systemImage: "arrow.triangle.swap")
                }
                if isChosen {
                    Button {
                        withAnimation { regularTripsModel.restoreUsual(occurrence) }
                    } label: {
                        Label("Revenir au trajet habituel", systemImage: "arrow.uturn.backward")
                    }
                }
                Button {
                    withAnimation { regularTripsModel.skip(occurrence) }
                } label: {
                    Label("Pas de trajet ce jour-là", systemImage: "calendar.badge.minus")
                }
                Button {
                    editing = trip
                } label: {
                    Label("Modifier le trajet régulier", systemImage: "pencil")
                }
            }
        }
    }

    /// Le trajet du jour pose problème : en proposer un autre sur la carte même.
    private static func needsAnotherTrip(_ state: RegularTripsModel.LiveState?) -> Bool {
        switch state {
        case .notFound: true
        case .found(let match, _): !RegularTripAlerts.changes(in: match).isEmpty
        default: false
        }
    }

    /// Le trajet du jour s'il est connu ; sinon il est demandé d'abord, et l'itinéraire prévu
    /// s'ouvre si OJP ne répond pas.
    private func open(_ occurrence: RegularTripOccurrence, displayed: TripEvent) {
        if case .found(let match, _) = regularTripsModel.state(of: occurrence) {
            onSelect(match.trip)
            return
        }
        guard opening == nil else { return }
        opening = occurrence.id
        Task {
            let match = await regularTripsModel.resolve(occurrence, force: true)
            opening = nil
            onSelect(match?.trip ?? displayed)
        }
    }

    /// « Aujourd'hui », « Demain », « Hier », « Lundi 28 septembre », avec l'année si ce n'est
    /// pas celle en cours.
    static func dayTitle(_ day: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) { return String(localized: "Aujourd'hui") }
        if calendar.isDateInTomorrow(day) { return String(localized: "Demain") }
        if calendar.isDateInYesterday(day) { return String(localized: "Hier") }
        let format: Date.FormatStyle = calendar.isDate(day, equalTo: Date(), toGranularity: .year)
            ? .dateTime.weekday(.wide).day().month(.wide)
            : .dateTime.weekday(.wide).day().month(.wide).year()
        let text = day.formatted(format)
        return text.prefix(1).capitalized + text.dropFirst()
    }
}

/// Une carte de l'agenda : le contenu ouvre l'itinéraire, les actions dessous restent des
/// boutons à part (un bouton dans un autre ne répond pas toujours).
struct AgendaCard<Content: View, Actions: View>: View {
    var highlighted = false
    let open: () -> Void
    let content: Content
    let actions: Actions

    init(highlighted: Bool = false, open: @escaping () -> Void,
         @ViewBuilder content: () -> Content, @ViewBuilder actions: () -> Actions) {
        self.highlighted = highlighted
        self.open = open
        self.content = content()
        self.actions = actions()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(action: open) {
                content
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            actions
                .controlSize(.small)
                .buttonBorderShape(.capsule)
        }
        .padding(15)
        .background(BasicCard(cornerRadius: 30, highlighted: highlighted))
        .padding(.vertical, 2)
    }
}

private extension View {
    /// Sous la barre de navigation. Sur iOS 26, la liste s'estompe dessous comme sous la barre ;
    /// avant, elle passe sous un fond de barre.
    @ViewBuilder func filterBar<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        if #available(iOS 26, *) {
            safeAreaBar(edge: .top, content: content)
        } else {
            safeAreaInset(edge: .top) { content().background(.bar) }
        }
    }
}

/// Rien à afficher : pourquoi, et comment remplir la liste.
struct AgendaEmptyView: View {
    let symbol: String
    var isAsset = false
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    var onCreate: (() -> Void)?

    var body: some View {
        VStack(spacing: 10) {
            (isAsset ? Image(symbol) : Image(systemName: symbol))
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if let onCreate {
                Button(action: onCreate) {
                    Label("Nouveau trajet régulier", systemImage: "calendar.badge.plus")
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(25)
    }
}

/// Un itinéraire enregistré : les heures et le résumé, la frise, puis le départ et
/// l'arrivée, chacun sous son arrêt.
struct SavedTripView: View {
    var event: TripEvent

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text(dateToString(with: event.startDate ?? Date()))
                Spacer()
                HStack {
                    Image(systemName: "arrowshape.bounce.forward")
                    Text(": \(event.transfers)")
                        .padding(.trailing)
                    Image(systemName: "timer")
                    Text(": \(durationText(event.duration))")
                }
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                Spacer()
                Text(dateToString(with: event.endDate ?? Date()))
            }
            // Aux tailles d'accessibilité, les deux heures ne laissaient que « : » entre elles.
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            TripTimeline(event: event)
            HStack(alignment: .top, spacing: 12) {
                StopNameView(event.startName, style: .row)
                    .frame(maxWidth: .infinity, alignment: .leading)
                StopNameView(event.endName, style: .row, alignment: .trailing)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }
}

// MARK: - Aperçus

/// Des itinéraires enregistrés hier, aujourd'hui et dans deux jours.
private enum SavedTripsPreview {
    static var trips: [TripEvent] {
        let base = PreviewData.trips
        return base.enumerated().map { index, trip in
            shifted(trip, days: [-1, 0, 2, -3][index % 4])
        }
    }

    static func shifted(_ trip: TripEvent, days: Int) -> TripEvent {
        let delta = TimeInterval(days * 86400)
        func shift(_ time: String) -> String {
            OJPDate.date(from: time).map { OJPDate.string(from: $0.addingTimeInterval(delta)) } ?? time
        }
        var trip = trip
        trip.id += "-\(days)"
        trip.startTime = shift(trip.startTime)
        trip.endTime = shift(trip.endTime)
        trip.legs = trip.legs.map { leg in
            var leg = leg
            leg.legBoardTimetableTime = shift(leg.legBoardTimetableTime)
            leg.legAlightTimetableTime = shift(leg.legAlightTimetableTime)
            leg.legBoardEstimatedTime = shift(leg.legBoardEstimatedTime)
            leg.legAlightEstimatedTime = shift(leg.legAlightEstimatedTime)
            return leg
        }
        return trip
    }

    static var regularTrips: RegularTripsModel {
        RegularTripsModel(previewTrips: [
            RegularTrip(trip: PreviewData.tripWithTransfer, weekdays: Set(Weekday.allCases), name: "Travail"),
        ])
    }
}

#Preview("Mes itinéraires") {
    SavedTripsPage()
        .environment(SavedTripsPreview.regularTrips)
        .previewEnvironment(savedTrips: SavedTripsPreview.trips)
}

#Preview("Mes itinéraires — iPad", traits: .iPadLandscape) {
    SavedTripsPage()
        .environment(SavedTripsPreview.regularTrips)
        .previewEnvironment(savedTrips: SavedTripsPreview.trips)
}

#Preview("Mes itinéraires — vide") {
    SavedTripsPage()
        .environment(RegularTripsModel(previewTrips: []))
        .previewEnvironment(savedTrips: [])
}

#Preview("Trajet enregistré") {
    VStack {
        ForEach(PreviewData.trips.prefix(3)) { trip in
            SavedTripView(event: trip)
                .padding(15)
                .background(BasicCard(cornerRadius: 30))
                .padding(5)
        }
    }
    .padding()
    .previewEnvironment(navigation: false)
}
