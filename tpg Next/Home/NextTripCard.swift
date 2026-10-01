//
//  NextTripCard.swift
//  tpg Next
//
//  L'accueil commence par le prochain trajet, régulier ou enregistré : quand partir, l'itinéraire
//  et ce qui a changé.
//

import SwiftUI
import tpgNextFunc

/// Le prochain trajet, avec son titre. L'accueil le choisit (`NextTrip.next`), affiche sa date
/// au-dessus et redemande les itinéraires enregistrés à OJP.
struct NextTripSection: View {
    let next: NextTrip

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HomeSectionTitle("Prochain trajet")
            NextTripCard(trip: next)
                .padding(.horizontal, 10)
        }
    }
}

extension NextTrip {
    /// Au-delà, ce n'est plus « le prochain trajet » mais un trajet à venir.
    private static let horizon: TimeInterval = 12 * 3600

    /// Le trajet régulier ou l'itinéraire enregistré qui part le premier.
    static func next(regular regularTripsModel: RegularTripsModel, saved savedTripsModel: SavedTripsModel,
                     now: Date) -> NextTrip? {
        var candidates: [NextTrip] = []
        if let occurrence = regularTripsModel.upcoming(after: now, days: 2).first,
           let trip = regularTripsModel.trip(for: occurrence) {
            candidates.append(.regular(occurrence, trip))
        }
        let saved = savedTripsModel.savedTrips
            .filter { ($0.endDate ?? .distantPast) > now }
            .min { ($0.startDate ?? .distantFuture) < ($1.startDate ?? .distantFuture) }
        if let saved {
            candidates.append(.saved(saved))
        }
        return candidates
            .filter { $0.plannedDeparture.timeIntervalSince(now) < horizon }
            .min { $0.plannedDeparture < $1.plannedDeparture }
    }
}

enum NextTrip {
    case regular(RegularTripOccurrence, RegularTrip)
    case saved(TripEvent)

    var plannedDeparture: Date {
        switch self {
        case .regular(let occurrence, _): occurrence.plannedDeparture
        case .saved(let trip): trip.startDate ?? .distantFuture
        }
    }
}

/// Quand partir, puis l'itinéraire comme dans les résultats (heures, frise, départ et
/// arrivée), l'état en direct et les actions.
struct NextTripCard: View {
    @Environment(RegularTripsModel.self) private var regularTripsModel
    @Environment(SavedTripsModel.self) private var savedTripsModel
    @Environment(\.displayTime) private var now
    @Environment(\.openRoute) private var openRoute
    private var liveActivities = TripLiveActivities.shared
    let trip: NextTrip

    @State private var showsAlternatives = false

    init(trip: NextTrip) {
        self.trip = trip
    }

    var body: some View {
        let displayed = self.displayed
        AgendaCard(open: { open(displayed) }) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    title
                        .font(.subheadline.bold())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer()
                    RegularTripStatusBadge(state: state, isSavedTrip: isSaved)
                }
                departure(displayed)
                // Comme un itinéraire : heures, frise, puis le départ et l'arrivée.
                SavedTripView(event: displayed)
                changes
            }
        } actions: {
            HStack {
                if !isTracking, liveActivities.areEnabled, trip.plannedDeparture.timeIntervalSince(now) < 6 * 3600 {
                    Button {
                        startLive(displayed)
                    } label: {
                        Label("Suivre en direct", systemImage: "inset.filled.circle")
                    }
                    .buttonStyle(.bordered)
                }
                Button {
                    showsAlternatives = true
                } label: {
                    Label(isSaved ? "Autres horaires…" as LocalizedStringKey : "Autre trajet…",
                          systemImage: "clock.arrow.2.circlepath")
                }
                .buttonStyle(.bordered)
            }
        }
        .sheet(isPresented: $showsAlternatives) { alternatives }
    }

    // MARK: Contenu

    @ViewBuilder private var title: some View {
        switch trip {
        case .regular(_, let recipe):
            Label(recipe.displayName, systemImage: "repeat")
        case .saved:
            Label("Itinéraire enregistré", image: "scurvepath.stack.fill")
        }
    }

    /// Quand partir, en gros (« Départ dans 8 min », « Partir dans 3 min »), puis la marche
    /// jusqu'à l'arrêt et le quai. La ligne, elle, est sur la frise.
    @ViewBuilder
    private func departure(_ displayed: TripEvent) -> some View {
        let countdown = TripCountdown(trip: displayed)
        let isBefore = countdown.map { $0.phase(at: now) != .onTheWay } ?? false
        let quay = displayed.vehicleLegs.first?.legBoardQuay ?? ""
        VStack(alignment: .leading, spacing: 4) {
            if isTracking {
                Label("Suivi en direct", systemImage: "inset.filled.circle")
                    .foregroundStyle(.tint)
                    .font(.title2.bold())
            } else {
                Text(verbatim: countdown?.headline(at: now) ?? dateToString(with: trip.plannedDeparture))
                    .font(.title2.bold())
            }
            if isBefore, countdown?.walkDescription != nil || !quay.isEmpty {
                HStack(spacing: 8) {
                    if let walk = countdown?.walkDescription {
                        Label(walk, systemImage: "figure.walk")
                            .lineLimit(1)
                    }
                    Spacer(minLength: 4)
                    if !quay.isEmpty {
                        Text("Quai \(quay)")
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder private var changes: some View {
        if case .found(let match, _) = state {
            if isSaved, match.kind == .alternative {
                Label("Cet itinéraire n'est plus proposé. À la place : \(RegularTripAlerts.description(of: match))",
                      systemImage: "xmark.octagon.fill")
                    .font(.footnote)
                    .foregroundStyle(.red)
            } else {
                RegularTripChanges(changes: RegularTripAlerts.changes(in: match))
            }
        } else if case .notFound = state {
            Label("Plus aucun itinéraire à cette heure-là.", systemImage: "xmark.octagon.fill")
                .font(.footnote)
                .foregroundStyle(.red)
        }
    }

    // MARK: État

    private var isSaved: Bool {
        if case .saved = trip { return true }
        return false
    }

    private var state: RegularTripsModel.LiveState? {
        switch trip {
        case .regular(let occurrence, _): regularTripsModel.state(of: occurrence)
        case .saved(let saved): savedTripsModel.state(of: saved)
        }
    }

    /// Le trajet du jour, avec son temps réel s'il est connu.
    private var displayed: TripEvent {
        switch trip {
        case .regular(let occurrence, let recipe):
            regularTripsModel.displayedTrip(for: occurrence) ?? recipe.plannedTrip(for: occurrence)
        case .saved(let saved):
            savedTripsModel.displayedTrip(for: saved)
        }
    }

    private var liveKey: String {
        switch trip {
        case .regular(let occurrence, _): occurrence.id
        case .saved(let saved): TripLiveActivities.key(for: saved)
        }
    }

    private var isTracking: Bool { liveActivities.isTracking(liveKey) }

    // MARK: Actions

    /// Suivi en direct : le trajet en cours, en plein écran. Sinon, sa page.
    private func open(_ displayed: TripEvent) {
        if isTracking {
            LiveTripPresentation.shared.open(liveKey)
        } else {
            openRoute(.trip(displayed))
        }
    }

    private func startLive(_ displayed: TripEvent) {
        switch trip {
        case .regular(let occurrence, let recipe):
            var match: RegularTripMatch?
            if case .found(let found, _) = state { match = found }
            liveActivities.start(occurrence: occurrence, of: recipe, trip: displayed, match: match)
        case .saved:
            liveActivities.start(trip: displayed)
        }
    }

    @ViewBuilder private var alternatives: some View {
        switch trip {
        case .regular(let occurrence, let recipe):
            TripAlternativesView(title: "Choisir un autre trajet",
                                 footer: "Pour ce jour seulement : les autres jours gardent le trajet habituel.",
                                 origin: recipe.origin, destination: recipe.destination,
                                 around: occurrence.target, isArrivalTime: recipe.anchor == .arrival,
                                 current: displayed) {
                regularTripsModel.choose($0, for: occurrence)
            }
        case .saved(let saved):
            TripAlternativesView(title: "Autres horaires",
                                 footer: "L'itinéraire choisi remplace celui enregistré.",
                                 replacing: saved) { savedTripsModel.replaceTrip(saved, with: $0) }
        }
    }
}

#Preview("Prochain trajet") {
    let trip = RegularTrip(trip: PreviewData.tripWithTransfer, weekdays: Set(Weekday.allCases), name: "Travail")
    let model = RegularTripsModel(previewTrips: [trip])
    ScrollView {
        if let occurrence = model.upcoming().first {
            NextTripSection(next: .regular(occurrence, trip))
        }
    }
    .environment(model)
    .previewEnvironment(navigation: false)
}
