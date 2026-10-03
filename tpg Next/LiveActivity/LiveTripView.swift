//
//  LiveTripView.swift
//  tpg Next
//
//  Le trajet suivi dans l'app : le bandeau attaché en bas, et le trajet en entier par-dessus.
//

import SwiftUI
import tpgNextFunc

/// Le trajet suivi ouvert par-dessus l'app, comme le lecteur de Musique : le bandeau s'ouvre en
/// plein écran, et se referme en glissant vers le bas (le bandeau réapparaît alors).
///
/// La feuille est posée par `ContentView`, au-dessus des onglets : le bandeau, lui, est refait à
/// chaque changement d'étape, et emporterait sa feuille avec lui.
@MainActor
@Observable
final class LiveTripPresentation {
    static let shared = LiveTripPresentation()

    /// Le trajet ouvert en plein écran, s'il y en a un.
    private(set) var openedKey: String?

    var isOpen: Bool {
        get { openedKey != nil }
        set { if !newValue { openedKey = nil } }
    }

    func open(_ key: String) { openedKey = key }
    func close() { openedKey = nil }
}

/// Le bandeau du trajet suivi, attaché au-dessus des onglets (comme le lecteur de Musique).
/// Il montre l'étape en cours, et ouvre le trajet en entier.
struct TripLiveAccessory: View {
    @Environment(\.displayTime) private var now
    let key: String
    let live: TripLiveActivities.LiveTrip

    var body: some View {
        let step = TripActivityStep(attributes: live.attributes, state: live.state, now: now)
        Button {
            LiveTripPresentation.shared.open(key)
        } label: {
            HStack(spacing: 10) {
                TripActivityMarker(step: step, compact: true)
                VStack(alignment: .leading, spacing: 0) {
                    Text(step.action)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    // Le nom court, coupé s'il le faut : pas de `TripActivityStopName` ici, son
                    // `ViewThatFits` faisait boucler la mise en page de la barre d'onglets.
                    Text(shortStopName(step.stopName))
                        .font(.subheadline.bold())
                }
                .lineLimit(1)
                Spacer(minLength: 6)
                TripActivityMinutes(target: step.target)
                    .font(.subheadline.bold())
                    .minimumScaleFactor(0.7)
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Trajet suivi : \(step.action) \(step.stopName)"))
    }
}

/// Pose le bandeau du trajet suivi : attaché aux onglets sur iOS 26, flottant avant.
struct TripLiveAccessoryModifier: ViewModifier {
    private var liveActivities = TripLiveActivities.shared

    /// Un bandeau vide occupe quand même sa place : quand rien n'est suivi, il n'est pas posé
    /// du tout, plutôt que posé sans contenu.
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26, *), let current = liveActivities.current {
            content.tabViewBottomAccessory {
                TripLiveAccessory(key: current.key, live: current.trip)
            }
        } else {
            content
        }
    }
}

extension View {
    /// Le trajet suivi, attaché sous les onglets.
    func liveTripAccessory() -> some View { modifier(TripLiveAccessoryModifier()) }
}

// MARK: - Le trajet en entier

/// Tout le trajet suivi, de haut en bas, comme le détail d'un itinéraire : le départ, chaque
/// véhicule entre sa montée et sa descente sur le trait de sa ligne, les marches et attentes,
/// puis l'arrivée. L'étape en cours est entourée et décompte ; les étapes passées s'effacent.
struct LiveTripView: View {
    let key: String
    /// Pour les aperçus : le trajet à afficher quand rien n'est suivi.
    var previewTrip: TripLiveActivities.LiveTrip?

    @Environment(\.displayTime) private var now
    @Environment(\.dismiss) private var dismiss
    /// Les véhicules dont on a déplié les arrêts intermédiaires.
    @State private var expanded: Set<Int> = []
    private var liveActivities = TripLiveActivities.shared

    private var trip: TripLiveActivities.LiveTrip? { liveActivities.live[key] ?? previewTrip }

    var body: some View {
        ScrollView {
            if let trip {
                VStack(alignment: .leading, spacing: 0) {
                    header(trip)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 16)
                    if let doubt = liveActivities.doubtful[key] {
                        DoubtfulTransferCard(doubt: doubt,
                                             boarded: { liveActivities.confirmBoarded(key) },
                                             missed: { liveActivities.confirmMissed(key) })
                        .padding(.horizontal, 15)
                        .padding(.bottom, 14)
                    }
                    if let options = liveActivities.alternatives[key], options.count > 1 {
                        ReplanOptionsCard(options: options, chosen: liveActivities.chosenAlternative[key]) {
                            liveActivities.choose($0, for: key)
                        }
                        .padding(.horizontal, 15)
                        .padding(.bottom, 14)
                    }
                    timeline(trip)
                        .padding(.horizontal, 15)
                }
                .padding(.top, 28)
                .padding(.bottom, 20)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "inset.filled.circle.slash")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("Ce trajet n'est plus suivi")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 60)
            }
        }
        .readableScrollContent()
        .safeAreaInset(edge: .bottom) {
            if trip != nil {
                Button(role: .destructive) {
                    liveActivities.stop(key)
                    dismiss()
                } label: {
                    Label("Arrêter le suivi", systemImage: "stop.circle")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 46)
                }
                .prominentButtonStyle()
                .tint(.red)
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
        }
    }

    // MARK: En-tête

    /// Le nom du trajet, puis l'arrivée dans une capsule, comme l'heure d'un départ.
    private func header(_ trip: TripLiveActivities.LiveTrip) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(tripTitle: trip.attributes.title)
                .font(.title2.bold())
                .lineLimit(2)
                .minimumScaleFactor(0.7)
            HStack(spacing: 10) {
                Image(systemName: "flag.checkered")
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 0) {
                    Text("Arrivée")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(stopName: trip.attributes.destination)
                        .font(.subheadline)
                        .lineLimit(1)
                }
                Spacer(minLength: 6)
                VStack(alignment: .trailing, spacing: 0) {
                    HStack(spacing: 4) {
                        Text(dateToString(with: trip.state.arrival))
                            .font(.headline)
                        if trip.state.arrivalDelay >= 2 {
                            Text("+\(trip.state.arrivalDelay)'")
                                .font(.subheadline.bold())
                                .foregroundStyle(trip.state.arrivalDelay >= 5 ? .red : .orange)
                        }
                    }
                    TripActivityMinutes(target: trip.state.arrival > now ? trip.state.arrival : nil)
                        .font(.caption.bold())
                        .foregroundStyle(.tint)
                }
            }
            .padding(.horizontal, 16)
            .basicElementBackground(minHeight: 54)
            if let alert = trip.state.alert {
                Label(alert, systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }
            // Dans le véhicule, la position affine l'horaire : le dire, pour que l'écart avec
            // l'heure annoncée ailleurs ne surprenne pas.
            if let offset = trip.state.positionOffset {
                let minutes = max(1, Int((Double(abs(offset)) / 60).rounded()))
                Label {
                    if offset > 0 {
                        Text("Ajusté d'après votre position : \(minutes)' de retard")
                    } else {
                        Text("Ajusté d'après votre position : \(minutes)' d'avance")
                    }
                } icon: {
                    Image(systemName: "location.fill")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Les étapes

    @ViewBuilder
    private func timeline(_ trip: TripLiveActivities.LiveTrip) -> some View {
        let state = trip.state
        let phase = state.phase(at: now)
        let legs = state.legs
        // Une marche finale sépare la dernière descente de l'arrivée ; sans elle, la descente
        // est l'arrivée, et une seule capsule suffit.
        let finalWalk = legs.last.map { state.arrival.timeIntervalSince($0.alight) > 60 } ?? false

        VStack(spacing: 0) {
            if hasStart(state), let first = legs.first {
                LiveStopCapsule(name: trip.attributes.origin, caption: "Départ", time: state.departure,
                                iconColor: .white, past: state.departure < now)
                note(walking: true, minutes(state.departure, first.board), past: first.board < now)
            }

            ForEach(Array(legs.enumerated()), id: \.offset) { index, leg in
                let isEnd = index == legs.count - 1 && !finalWalk
                legBlock(leg, index: index, phase: phase, isEnd: isEnd)
                if index + 1 < legs.count {
                    note(walking: false, minutes(leg.alight, legs[index + 1].board), past: legs[index + 1].board < now)
                }
            }

            if let last = legs.last, finalWalk {
                note(walking: true, minutes(last.alight, state.arrival), past: state.arrival < now)
                LiveStopCapsule(name: trip.attributes.destination, caption: "Arrivée", time: state.arrival,
                                iconColor: .white, past: state.arrival < now, highlighted: phase == .arrived,
                                terminus: true)
            }
        }
    }

    /// Un véhicule : sa montée et sa descente en capsules, reliées par le trait de sa ligne, et
    /// entre elles la ligne, sa direction et ses arrêts.
    private func legBlock(_ leg: TripActivityState.Leg, index: Int, phase: TripActivityState.Phase,
                          isEnd: Bool) -> some View {
        let color = LineColors.lineColor(for: leg.line, operatorName: leg.operatorName)
        let stopColor = LineColors.lineColor(for: leg.line, operatorName: leg.operatorName, inverted: true)
        let waiting = phase == .waiting(leg: index)
        let riding = phase == .riding(leg: index)
        return VStack(spacing: 0) {
            LiveStopCapsule(name: leg.boardName, caption: boardCaption(leg), time: leg.board, delay: leg.delay,
                            iconColor: stopColor, past: leg.board < now, highlighted: waiting,
                            target: waiting ? leg.board : nil, cancelled: leg.cancelled == true)
            ride(leg, index: index, stopColor: stopColor, riding: riding)
            LiveStopCapsule(name: leg.alightName, caption: isEnd ? "Arrivée" : "Descente", time: leg.alight,
                            iconColor: stopColor, past: leg.alight < now,
                            highlighted: riding || (isEnd && phase == .arrived),
                            target: riding ? leg.alight : nil, terminus: isEnd)
        }
        // Le trait de la ligne, du point de la montée à celui de la descente.
        .background(alignment: .leading) {
            RoundedRectangle(cornerRadius: 5)
                .fill(color.opacity(leg.alight < now && !riding ? 0.35 : 1))
                .frame(width: 8)
                .padding(.vertical, 30)
                .padding(.leading, LiveStopCapsule.trailX - 4)
        }
    }

    private func boardCaption(_ leg: TripActivityState.Leg) -> LocalizedStringKey {
        leg.boardQuay.isEmpty ? "Montée" : "Montée · quai \(leg.boardQuay)"
    }

    /// Vrai si le trajet commence par une marche jusqu'à la première montée.
    private func hasStart(_ state: TripActivityState) -> Bool {
        guard let first = state.legs.first else { return false }
        return first.board.timeIntervalSince(state.departure) > 60
    }

    private func minutes(_ from: Date, _ to: Date) -> Int {
        max(0, Int((to.timeIntervalSince(from) / 60).rounded()))
    }

    /// « [12] → Carouge **Bachet** » entre la montée et la descente, comme dans le détail d'un
    /// itinéraire ; à bord, où est le véhicule, et ses arrêts dépliés.
    @ViewBuilder
    private func ride(_ leg: TripActivityState.Leg, index: Int, stopColor: Color, riding: Bool) -> some View {
        let calls = (leg.calls ?? []).filter { $0.time > leg.board && $0.time < leg.alight }
        // Le véhicule en route : ses arrêts s'ouvrent d'eux-mêmes, pour voir où il en est.
        let open = expanded.contains(index) || riding
        let vehicleStop = riding ? leg.vehicleStop(at: now) : nil
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Color.clear.frame(width: LiveStopCapsule.trailX + 14, height: 1)
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        BusLineIcon(lineName: leg.line, operatorName: leg.operatorName)
                        Image(systemName: "arrow.right")
                        Text(stopName: leg.destination)
                            .font(.callout)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    if let vehicleStop {
                        Label("Actuellement à \(shortStopName(vehicleStop))", systemImage: "location.fill")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.tint)
                    } else {
                        Text("\(minutes(leg.board, leg.alight))' de trajet")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 4)
                if !calls.isEmpty, !riding {
                    Button {
                        withAnimation(.snappy) {
                            if expanded.contains(index) { expanded.remove(index) } else { expanded.insert(index) }
                        }
                    } label: {
                        HStack(spacing: 3) {
                            Text("\(calls.count) arrêts")
                            Image(systemName: open ? "chevron.up" : "chevron.down")
                        }
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                        .basicElementBackground(minHeight: 30)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.trailing, 5)
            .padding(.vertical, 10)
            .opacity(leg.alight < now && !riding ? 0.45 : 1)
            if open {
                ForEach(calls, id: \.self) { call in
                    let atVehicle = call.name == vehicleStop
                    HStack(spacing: 8) {
                        StopIcon(color: stopColor, currentStop: atVehicle, size: atVehicle ? 14 : 11)
                            .frame(width: LiveStopCapsule.trailX * 2)
                        Text(stopName: call.name)
                            .font(.footnote)
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        Text(dateToString(with: call.time))
                            .font(.footnote.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    .padding(.trailing, 20)
                    .padding(.vertical, 4)
                    .opacity(call.time < now && !atVehicle ? 0.4 : 1)
                }
                .padding(.bottom, 6)
            }
        }
    }

    /// Une marche ou une attente : l'icône sur l'axe des arrêts, et sa durée.
    private func note(walking: Bool, _ minutes: Int, past: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: walking ? "figure.walk" : "timer")
                .frame(width: LiveStopCapsule.trailX * 2)
            Text(walking ? "\(minutes)' à pied" as LocalizedStringKey : "\(minutes)' d'attente")
            Spacer()
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .padding(.vertical, 10)
        .opacity(past ? 0.45 : 1)
    }
}

/// Un arrêt du trajet suivi en capsule, comme sur la page d'une ligne : son point sur le trait,
/// son nom, et à droite l'heure, le décompte de l'étape en cours ou ce qu'on y fait.
struct LiveStopCapsule: View {
    /// L'axe des points d'arrêt, depuis le bord de la rangée.
    static let trailX: CGFloat = 30

    let name: String
    let caption: LocalizedStringKey
    let time: Date
    var delay = 0
    let iconColor: Color
    let past: Bool
    var highlighted = false
    var target: Date?
    var terminus = false
    var cancelled = false

    var body: some View {
        HStack {
            StopIcon(color: iconColor, currentStop: highlighted, terminus: terminus)
            SmallStopTitleView(stopName: name)
                .strikethrough(cancelled)
            Spacer(minLength: 6)
            VStack(alignment: .trailing, spacing: 1) {
                HStack(spacing: 4) {
                    Text(dateToString(with: time))
                        .font(.headline.monospacedDigit())
                    if delay >= 2 {
                        Text("+\(delay)'")
                            .font(.subheadline.bold())
                            .foregroundStyle(delay >= 5 ? .red : .orange)
                    }
                }
                if let target {
                    TripActivityMinutes(target: target)
                        .font(.caption.bold())
                        .foregroundStyle(.tint)
                } else {
                    Text(caption)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal)
        .basicElementBackground(minHeight: 50, highlighted: highlighted)
        .padding(5)
        .opacity(past && !highlighted ? 0.45 : 1)
        .accessibilityElement(children: .combine)
    }
}

/// La correspondance serrée : ni l'horaire ni la position ne tranchent, seul le voyageur sait.
struct DoubtfulTransferCard: View {
    let doubt: TripLiveActivities.DoubtfulTransfer
    let boarded: () -> Void
    let missed: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label {
                Text("Correspondance serrée à \(doubt.stop)")
                    .font(.subheadline.bold())
            } icon: {
                Image(systemName: "questionmark.circle.fill")
                    .foregroundStyle(.orange)
            }
            Text("Le \(doubt.line) partait au moment où vous descendiez. Êtes-vous monté dedans ?")
                .font(.footnote)
                .foregroundStyle(.secondary)
            HStack(spacing: 10) {
                Button(action: boarded) {
                    Text("Je suis monté").frame(maxWidth: .infinity, minHeight: 40)
                }
                .prominentButtonStyle()
                Button(action: missed) {
                    Text("Je l'ai manqué").frame(maxWidth: .infinity, minHeight: 40)
                }
                .secondaryButtonStyle()
            }
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BasicCard(cornerRadius: 25))
    }
}

/// Les suites proposées après un recalcul : la plus tôt arrivée s'applique, le voyageur peut
/// en préférer une autre.
struct ReplanOptionsCard: View {
    let options: [TripLiveActivities.ReplanOption]
    let chosen: String?
    let choose: (TripLiveActivities.ReplanOption) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Autres suites possibles")
                .font(.subheadline.bold())
                .padding(.bottom, 2)
            ForEach(options) { option in
                Button {
                    choose(option)
                } label: {
                    HStack(spacing: 10) {
                        TripActivityLineBadge(line: option.line,
                                              color: LineColors.lineColor(for: option.line,
                                                                          operatorName: option.operatorName),
                                              compact: true)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Départ \(dateToString(with: option.departure))")
                                .font(.subheadline)
                            Text("Arrivée \(dateToString(with: option.arrival))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: chosen == option.id ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(chosen == option.id ? Color.accentColor : .secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BasicCard(cornerRadius: 25))
    }
}

// MARK: - Aperçus

#Preview("Bandeau du trajet suivi") {
    VStack {
        Spacer()
        TripLiveAccessory(key: "preview", live: .preview)
            .frame(height: 50)
            .background(Capsule().fill(.thinMaterial))
            .padding(.horizontal)
    }
    .previewEnvironment()
}

extension TripLiveActivities.LiveTrip {
    /// Données inventées : le 12 dans quatre minutes, puis le 19.
    static var preview: TripLiveActivities.LiveTrip {
        let now = Date()
        let board = now.addingTimeInterval(4 * 60)
        let calls = ["Bel-Air", "Molard", "Rive", "Terrassière"].enumerated().map { index, name in
            TripActivityState.Call(name: name, time: board.addingTimeInterval(TimeInterval(index - 2) * 100))
        }
        let state = TripActivityState(
            legs: [
                .init(line: "12", operatorName: "Transports Publics Genevois", transportType: "Tram",
                      destination: "Carouge, Bachet", boardName: "Genève, Rive", boardQuay: "B",
                      board: board, alight: board.addingTimeInterval(300), alightName: "Genève, Terrassière",
                      delay: 0, calls: calls),
            ],
            departure: now, arrival: board.addingTimeInterval(420), arrivalDelay: 0, alert: nil, updated: now)
        return TripLiveActivities.LiveTrip(
            attributes: TripActivityAttributes(key: "preview", title: "Travail", origin: "Genève, Rive",
                                               destination: "Genève, gare Cornavin"),
            state: state)
    }

    /// Deux véhicules et une correspondance, pour voir toute la frise.
    static var previewTransfer: TripLiveActivities.LiveTrip {
        let now = Date()
        let board = now.addingTimeInterval(3 * 60)
        let firstAlight = board.addingTimeInterval(9 * 60)
        let secondBoard = firstAlight.addingTimeInterval(4 * 60)
        func calls(_ names: [String], from: Date, step: TimeInterval) -> [TripActivityState.Call] {
            names.enumerated().map { .init(name: $0.element, time: from.addingTimeInterval(TimeInterval($0.offset) * step)) }
        }
        let state = TripActivityState(
            legs: [
                .init(line: "12", operatorName: "Transports Publics Genevois", transportType: "Tram",
                      destination: "Carouge, Bachet", boardName: "Genève, Rive", boardQuay: "B",
                      board: board, alight: firstAlight, alightName: "Genève, Plainpalais", delay: 3,
                      calls: calls(["Bel-Air", "Molard", "Rive", "Cirque", "Plainpalais"],
                                   from: board.addingTimeInterval(-120), step: 150)),
                .init(line: "15", operatorName: "Transports Publics Genevois", transportType: "Tram",
                      destination: "Nations", boardName: "Genève, Plainpalais", boardQuay: "",
                      board: secondBoard, alight: secondBoard.addingTimeInterval(6 * 60),
                      alightName: "Genève, gare Cornavin", delay: 0, calls: nil),
            ],
            departure: now, arrival: secondBoard.addingTimeInterval(9 * 60), arrivalDelay: 3, alert: nil, updated: now)
        return TripLiveActivities.LiveTrip(
            attributes: TripActivityAttributes(key: "preview", title: "Travail", origin: "Genève, Terrassière",
                                               destination: "Genève, Servette"),
            state: state)
    }
}

extension TripLiveActivities.LiveTrip {
    /// À bord du premier véhicule : ses arrêts s'ouvrent, et sa position s'y lit.
    static var previewRiding: TripLiveActivities.LiveTrip {
        var trip = previewTransfer
        let shift: TimeInterval = -7 * 60
        trip.state.legs = trip.state.legs.map { leg in
            var leg = leg
            leg.board.addTimeInterval(shift)
            leg.alight.addTimeInterval(shift)
            leg.calls = leg.calls?.map { .init(name: $0.name, time: $0.time.addingTimeInterval(shift)) }
            return leg
        }
        trip.state.departure.addTimeInterval(shift)
        trip.state.arrival.addTimeInterval(shift)
        trip.state.positionOffset = 95
        return trip
    }
}

#Preview("Trajet suivi — à bord") {
    LiveTripView(key: "preview", previewTrip: .previewRiding)
        .previewEnvironment()
}

#Preview("Trajet suivi") {
    LiveTripView(key: "preview", previewTrip: .preview)
        .previewEnvironment()
}

#Preview("Trajet suivi — correspondance") {
    LiveTripView(key: "preview", previewTrip: .previewTransfer)
        .previewEnvironment()
}

extension TripLiveActivities.ReplanOption {
    /// Deux suites inventées depuis Plainpalais, pour l'aperçu.
    static var previews: [TripLiveActivities.ReplanOption] {
        var trip = PreviewData.tripWithTransfer
        guard let after = trip.trackedLegs.first, let departure = after.boardDate,
              let arrival = trip.endDate else { return [] }
        let first = TripLiveActivities.ReplanOption(
            trip: trip, after: after, line: "15", operatorName: "Transports Publics Genevois",
            departure: departure, arrival: arrival)
        trip.id += "-bis"
        let second = TripLiveActivities.ReplanOption(
            trip: trip, after: after, line: "1", operatorName: "Transports Publics Genevois",
            departure: departure.addingTimeInterval(240), arrival: arrival.addingTimeInterval(180))
        return [first, second]
    }
}

#Preview("Correspondance serrée et autres suites") {
    ScrollView {
        VStack(spacing: 14) {
            DoubtfulTransferCard(doubt: .init(leg: 0, stop: "Plainpalais", line: "15"),
                                 boarded: {}, missed: {})
            ReplanOptionsCard(options: TripLiveActivities.ReplanOption.previews,
                              chosen: TripLiveActivities.ReplanOption.previews.first?.id) { _ in }
        }
        .padding(15)
    }
    .previewEnvironment()
}

#Preview("Trajet suivi — plus suivi") {
    LiveTripView(key: "preview")
        .previewEnvironment()
}
