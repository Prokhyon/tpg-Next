//
//  TripLiveActivity.swift
//  tpg Next
//
//  L'activité en direct d'un trajet : écran verrouillé et Dynamic Island.
//  Compilé aussi pour le widget, qui l'affiche (exception dans le projet, comme BasicViews.swift).
//

import SwiftUI
import WidgetKit
import ActivityKit
import tpgNextFunc

struct TripLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TripActivityAttributes.self) { context in
            TripActivityContent(step: TripActivityStep(attributes: context.attributes, state: context.state, now: Date()),
                                alert: context.state.alert, key: context.attributes.key)
                // Une question ne ressemble pas au reste : elle se démarque par son fond.
                .activityBackgroundTint(context.state.question == nil ? nil : Color.orange.opacity(0.25))
                .widgetURL(TripActivityLink.url(for: context.attributes.key))
        } dynamicIsland: { context in
            let step = TripActivityStep(attributes: context.attributes, state: context.state, now: Date())
            return DynamicIsland {
                // De part et d'autre de la caméra : le trajet (ou le véhicule, à bord) et l'heure
                // d'arrivée. Dessous, sur toute la largeur, la frise et ses traits de lignes.
                DynamicIslandExpandedRegion(.leading) {
                    TripIslandTitle(step: step)
                        .padding(.leading, 6)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    TripIslandArrival(step: step)
                        .padding(.trailing, 6)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if let question = step.question {
                        TripActivityQuestion(question: question, key: context.attributes.key, compact: true)
                            .padding(.horizontal, 6)
                    } else {
                        // L'en-tête de la frise est déjà autour de la caméra.
                        TripActivityTimeline(step: step, alert: context.state.alert, compact: true,
                                             verticalInset: 4, showsHeader: false)
                            .padding(.horizontal, 6)
                    }
                }
            } compactLeading: {
                // De l'air autour du badge : collé au bord, la caméra le rogne.
                TripActivityMarker(step: step, compact: true)
                    .padding(.horizontal, 3)
            } compactTrailing: {
                // Les minutes, comme sur l'écran verrouillé : les secondes promettraient une
                // précision que les heures estimées n'ont pas. Le système n'a pas de forme
                // courte (« 4' ») : « 12 minutes » se réduit un peu pour tenir.
                TripActivityMinutes(target: step.target)
                    .font(.caption2.bold())
                    .minimumScaleFactor(0.6)
                    .frame(maxWidth: 64)
                    .padding(.trailing, 4)
            } minimal: {
                TripActivityMarker(step: step, compact: true)
                    .padding(.horizontal, 2)
            }
            .widgetURL(TripActivityLink.url(for: context.attributes.key))
            .keylineTint(step.color)
        }
        // Pile intelligente de l'Apple Watch (et CarPlay) : la présentation `.small`.
        .supplementalActivityFamilies([.small])
    }
}

/// L'écran verrouillé, ou la montre qui demande la présentation réduite.
struct TripActivityContent: View {
    @Environment(\.activityFamily) private var family
    let step: TripActivityStep
    let alert: String?
    let key: String

    var body: some View {
        switch family {
        case .small:
            TripActivityWatchView(step: step, alert: alert)
        default:
            if let question = step.question {
                TripActivityQuestion(question: question, key: key)
                    .padding(.horizontal, 16)
            } else {
                TripActivityTimeline(step: step, alert: alert)
                    .padding(.horizontal, 16)
            }
        }
    }
}

/// La question d'une correspondance serrée, à la place de la frise : elle n'a rien à voir avec
/// ce qui s'affiche le reste du temps, et mérite son propre écran.
struct TripActivityQuestion: View {
    let question: TripActivityState.Question
    let key: String
    var compact = false

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 6 : 10) {
            HStack(spacing: 8) {
                Image(systemName: "questionmark.circle.fill")
                    .foregroundStyle(.orange)
                Text("Correspondance serrée à \(question.stop)")
                    .font(compact ? .caption.bold() : .subheadline.bold())
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Text("Êtes-vous monté dans le \(question.line) ?")
                .font(compact ? .caption2 : .footnote)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            HStack(spacing: 8) {
                Button(intent: TripBoardingIntent(key: key, aboard: true)) {
                    Text("Je suis monté")
                        .font(compact ? .caption.bold() : .subheadline.bold())
                        .frame(maxWidth: .infinity, minHeight: compact ? 28 : 34)
                }
                .buttonStyle(.borderedProminent)
                Button(intent: TripBoardingIntent(key: key, aboard: false)) {
                    Text("Manqué")
                        .font(compact ? .caption.bold() : .subheadline.bold())
                        .frame(maxWidth: .infinity, minHeight: compact ? 28 : 34)
                }
                .buttonStyle(.bordered)
            }
            .tint(.orange)
        }
        .padding(.vertical, compact ? 4 : 14)
    }
}

// MARK: - Dynamic Island dépliée

/// À gauche de la caméra : le nom du trajet, ou à bord l'arrêt où se trouve le véhicule.
struct TripIslandTitle: View {
    let step: TripActivityStep

    var body: some View {
        Text(step.vehicleNote ?? step.title)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .frame(maxHeight: .infinity)
    }
}

/// À droite de la caméra : l'heure d'arrivée et son retard. À l'arrivée, elle est déjà sous
/// l'arrêt : une seule fois suffit.
struct TripIslandArrival: View {
    let step: TripActivityStep

    var body: some View {
        HStack(spacing: 3) {
            if !step.isArrived {
                Text("Arrivée \(step.arrival.formatted(date: .omitted, time: .shortened))")
                if step.arrivalDelay >= 2 {
                    Text("+\(step.arrivalDelay)'")
                        .foregroundStyle(.orange)
                }
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .frame(maxHeight: .infinity)
    }
}

enum TripActivityLink {
    /// Ouvre le trajet suivi dans l'app.
    static func url(for key: String) -> URL? {
        var components = URLComponents()
        components.scheme = "tpgnext"
        components.host = "livetrip"
        components.queryItems = [URLQueryItem(name: "key", value: key)]
        return components.url
    }
}

/// Ce qu'il faut afficher maintenant, lu dans l'état à l'heure du dessin.
struct TripActivityStep {
    let phase: TripActivityState.Phase
    /// Le véhicule de l'étape en cours (le dernier à l'arrivée).
    let leg: TripActivityState.Leg?
    /// La montée ou la descente attendue.
    let target: Date?
    /// En petit au-dessus : où se trouve le véhicule.
    let vehicleNote: String?
    /// En gros : l'arrêt de montée, de descente, ou d'arrivée, en entier (commune comprise).
    let stopName: String
    /// En petit dessous : ce qu'on y fait (texte brut, pour l'accessibilité et le bandeau).
    let action: String
    /// La même chose mise en forme : la direction écrite comme un arrêt, « Carouge **Bachet** ».
    let actionText: Text
    /// L'étape d'après, en petit sous la frise.
    let next: TripActivityState.NextStep?
    /// En haut : le nom du trajet, l'heure d'arrivée et son retard.
    let title: String
    let arrival: Date
    let arrivalDelay: Int
    /// La ligne de l'étape d'après, pour la frise.
    let nextLeg: TripActivityState.Leg?
    /// Vrai quand le voyageur marche vers l'arrêt, plutôt que d'y attendre.
    let isWalking: Bool
    /// Vrai quand le véhicule attendu arrive à l'arrêt (une minute avant la montée).
    let isVehicleApproaching: Bool
    /// La question posée au voyageur, s'il y en a une.
    let question: TripActivityState.Question?

    init(attributes: TripActivityAttributes, state: TripActivityState, now: Date) {
        phase = state.phase(at: now)
        isWalking = state.isWalking(at: now)
        isVehicleApproaching = state.isVehicleApproaching(at: now)
        question = state.question
        target = state.target(of: phase)
        next = state.nextStep(after: phase)
        title = attributes.title
        arrival = state.arrival
        arrivalDelay = state.arrivalDelay
        if case .transfer(let index, _) = next { nextLeg = state.legs[index] } else { nextLeg = nil }

        switch phase {
        case .waiting(let index):
            let leg = state.legs[index]
            self.leg = leg
            stopName = leg.boardName
            // En attente, l'arrêt de montée et les minutes suffisent.
            vehicleNote = nil
            var parts = [String(localized: "Montée")]
            if !leg.boardQuay.isEmpty { parts.append(String(localized: "quai \(leg.boardQuay)")) }
            // La direction en entier : « Village » seul ne dit pas où va la ligne.
            // La ligne dans le texte : en attente, le marqueur montre la marche ou l'attente.
            let lead = (parts + [leg.line]).joined(separator: " · ")
            let delay = leg.delay >= 2 ? " · +\(leg.delay)'" : ""
            action = "\(lead) → \(leg.destination)\(delay)"
            actionText = Text(verbatim: "\(lead) → ") + Text(stopName: leg.destination) + Text(verbatim: delay)
        case .riding(let index):
            let leg = state.legs[index]
            self.leg = leg
            stopName = leg.alightName
            // Déjà à l'arrêt de descente : l'arrêt en gros suffit. Les passages embarqués
            // portent des noms courts (l'état doit tenir en 4 Ko).
            vehicleNote = leg.vehicleStop(at: now).flatMap { stop in
                stop == shortStopName(leg.alightName) ? nil : String(localized: "Actuellement à \(stop)")
            }
            action = String(localized: "Descente")
            actionText = Text(action)
        case .arrived:
            leg = state.legs.last
            vehicleNote = nil
            stopName = attributes.destination
            // Le trajet est fini : on le dit, sans répéter le retard affiché en route.
            action = String(localized: "Trajet terminé · arrivé à \(state.arrival.formatted(date: .omitted, time: .shortened))")
            actionText = Text(action)
        }
    }

    var color: Color {
        guard let leg else { return .secondary }
        return LineColors.lineColor(for: leg.line, operatorName: leg.operatorName)
    }

    var isRiding: Bool {
        if case .riding = phase { return true }
        return false
    }

    var isArrived: Bool {
        if case .arrived = phase { return true }
        return false
    }

    /// « Genève **Terrassière** · 5' de trajet », « 6' d'attente », « Arrivée à 18:55 ».
    var nextText: Text? {
        switch next {
        case .ride(let stop, let minutes):
            return Text("\(Text(stopName: stop)) · \(minutes)' de trajet")
        case .transfer(_, let wait):
            guard let nextLeg else { return nil }
            return Text("\(wait)' d'attente · \(nextLeg.line) → \(Text(stopName: nextLeg.destination))")
        case .arrival(let date, let walk):
            let time = date.formatted(date: .omitted, time: .shortened)
            return walk > 0
                ? Text("Arrivée à \(time) · \(walk)' à pied")
                : Text("Arrivée à \(time)")
        case nil:
            return nil
        }
    }
}

/// L'étape en cours et la suivante, avec la frise verticale à gauche.
///
/// À bord, le trait de la ligne sort par le haut de la carte, et celui de la correspondance
/// par le bas : les marges du haut et du bas sont donc dans les rangées (`verticalInset`), pour
/// que les traits aillent jusqu'au bord.
struct TripActivityTimeline: View {
    let step: TripActivityStep
    let alert: String?
    var compact = false
    var verticalInset: CGFloat = 14
    /// Faux dans la Dynamic Island, qui place le titre et l'arrivée autour de la caméra.
    var showsHeader = true

    private var railWidth: CGFloat { compact ? 34 : 40 }
    private let railSpacing: CGFloat = 10

    /// La ligne de la correspondance, qui sort par le bas.
    private var nextColor: Color? {
        guard case .transfer = step.next, let nextLeg = step.nextLeg else { return nil }
        return LineColors.lineColor(for: nextLeg.line, operatorName: nextLeg.operatorName)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // En haut : le véhicule (à bord) ou le trajet, et l'heure d'arrivée. À bord, le trait
            // de la ligne vient du bord de la carte jusqu'au badge.
            if showsHeader {
                row(rail: step.isRiding ? step.color : nil, topInset: verticalInset) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(step.vehicleNote ?? step.title)
                            .lineLimit(1)
                        Spacer(minLength: 8)
                        // À l'arrivée, l'heure est déjà sous l'arrêt : une seule fois suffit.
                        if !step.isArrived {
                            arrivalText
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 4)
                }
            } else {
                // Sans en-tête, à bord, le trait de la ligne sort quand même par le haut.
                row(rail: step.isRiding ? step.color : nil, topInset: 0) {
                    Color.clear.frame(height: verticalInset)
                }
            }

            // L'étape en cours ; le trait descend jusqu'à l'étape suivante.
            HStack(alignment: .top, spacing: railSpacing) {
                VStack(spacing: 0) {
                    TripActivityMarker(step: step, compact: compact)
                    if step.next != nil {
                        TripActivityConnector(step: step)
                    }
                }
                .frame(width: railWidth)

                VStack(alignment: .leading, spacing: 1) {
                    HStack(alignment: .firstTextBaseline) {
                        TripActivityStopName(name: step.stopName)
                            .font(compact ? .title3 : .title2)
                        Spacer(minLength: 8)
                        TripActivityMinutes(target: step.target)
                            .font(compact ? .subheadline.bold() : .headline)
                    }
                    step.actionText
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .padding(.bottom, step.next == nil ? verticalInset : 10)
            }
            .fixedSize(horizontal: false, vertical: true)

            if let nextText = step.nextText {
                HStack(alignment: .top, spacing: railSpacing) {
                    VStack(spacing: 0) {
                        TripActivityNextMarker(step: step)
                        // La correspondance : son trait sort par le bas.
                        if let nextColor {
                            railLine(nextColor)
                        }
                    }
                    .frame(width: railWidth)
                    nextText
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .padding(.top, 1)
                        .padding(.bottom, alert == nil ? verticalInset : 6)
                }
                .fixedSize(horizontal: false, vertical: true)
            }

            if let alert {
                row(rail: nextColor, topInset: 0) {
                    Label(alert, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                        .lineLimit(1)
                        .padding(.bottom, verticalInset)
                }
            }
        }
    }

    /// Une rangée sans marqueur : le trait `rail` la traverse de haut en bas (rien si `nil`).
    private func row<Content: View>(rail: Color?, topInset: CGFloat, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .top, spacing: railSpacing) {
            Group {
                if let rail { railLine(rail) } else { Color.clear }
            }
            .frame(width: railWidth)
            content()
                .padding(.top, topInset)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func railLine(_ color: Color) -> some View {
        Rectangle()
            .fill(color)
            .frame(width: 5)
            .frame(maxHeight: .infinity)
    }

    /// « Arrivée 18:55 », avec le retard en orange.
    private var arrivalText: some View {
        HStack(spacing: 3) {
            Text("Arrivée \(step.arrival.formatted(date: .omitted, time: .shortened))")
            if step.arrivalDelay >= 2 {
                Text("+\(step.arrivalDelay)'")
                    .foregroundStyle(.orange)
            }
        }
        .lineLimit(1)
        .layoutPriority(1)
    }
}

/// La pile intelligente de l'Apple Watch : la ligne, l'arrêt, les minutes et l'étape suivante.
struct TripActivityWatchView: View {
    let step: TripActivityStep
    let alert: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                TripActivityMarker(step: step, compact: true)
                Spacer(minLength: 4)
                TripActivityMinutes(target: step.target)
                    .font(.caption.bold())
                    .minimumScaleFactor(0.7)
            }
            TripActivityStopName(name: step.stopName)
                .font(.headline)
            if let alert {
                Text(alert)
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .lineLimit(1)
            } else if let detail = step.nextText ?? (step.isArrived ? step.actionText : nil) {
                detail
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(8)
    }
}

/// En haut de la frise : la ligne de l'étape en cours, ce qu'il y a à faire en attendant, ou
/// l'arrêt d'arrivée.
struct TripActivityMarker: View {
    let step: TripActivityStep
    var compact = false

    var body: some View {
        switch step.phase {
        case .riding:
            // Dans le véhicule : sa ligne.
            if let leg = step.leg {
                TripActivityLineBadge(line: leg.line, color: step.color, compact: compact)
            }
        case .waiting:
            // Pas encore dedans : ce qu'il y a à faire d'ici là, marcher ou attendre ; puis le
            // véhicule, quand il arrive.
            if step.isVehicleApproaching {
                symbol(nil)
            } else {
                symbol(step.isWalking ? "figure.walk" : "clock")
            }
        case .arrived:
            // Le trajet est fini : le point d'arrivée, comme au bout d'un itinéraire.
            TripActivityStopIcon(terminus: true, compact: compact)
                .frame(minWidth: compact ? 28 : 40, minHeight: compact ? 19 : 27)
        }
    }

    /// Une icône à la place du badge, de la même taille pour ne pas décaler la frise.
    @ViewBuilder
    private func symbol(_ name: String?) -> some View {
        Group {
            if let name {
                Image(systemName: name)
            } else {
                transportIcon(with: step.leg?.transportType ?? "Bus")
            }
        }
        // Aussi lisibles que le badge de ligne qu'elles remplacent.
        .font(compact ? .body.weight(.semibold) : .title2.weight(.semibold))
        .foregroundStyle(step.color)
        .frame(minWidth: compact ? 28 : 40, minHeight: compact ? 19 : 27)
    }
}

/// Le numéro de ligne dans sa capsule. Taille fixe quelle que soit la longueur du numéro :
/// sans largeur minimale, « 7 » donnait un rond et « 12 » un ovale.
struct TripActivityLineBadge: View {
    let line: String
    let color: Color
    var compact = false

    private var size: CGSize { compact ? CGSize(width: 28, height: 19) : CGSize(width: 40, height: 27) }

    var body: some View {
        Text(line)
            .font(compact ? .caption.bold() : .headline)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .padding(.horizontal, compact ? 4 : 6)
            .frame(minWidth: size.width, minHeight: size.height)
            .background(Capsule().stroke(color, lineWidth: compact ? 2.5 : 3.5))
            .accessibilityLabel(Text("Ligne \(line)"))
    }
}

/// Le trait entre l'étape en cours et la suivante : plein à la couleur de la ligne pour un
/// trajet à bord, en pointillés pour une attente ou une marche.
struct TripActivityConnector: View {
    let step: TripActivityStep

    var body: some View {
        if step.isRiding {
            Line()
                .stroke(Color.secondary.opacity(0.7), style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [0.5, 6]))
                .frame(width: 3)
                .frame(maxHeight: .infinity)
                .padding(.vertical, 4)
        } else {
            Capsule()
                .fill(step.color)
                .frame(width: 5)
                .frame(maxHeight: .infinity)
                .padding(.top, 4)
        }
    }

    private struct Line: Shape {
        func path(in rect: CGRect) -> Path {
            Path { path in
                path.move(to: CGPoint(x: rect.midX, y: rect.minY))
                path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
            }
        }
    }
}

/// En bas de la frise : l'arrêt de descente, la ligne de la correspondance, ou l'arrivée.
struct TripActivityNextMarker: View {
    let step: TripActivityStep

    var body: some View {
        switch step.next {
        case .ride:
            // L'arrêt où descendre, comme sur la page de la ligne.
            if let leg = step.leg {
                StopIcon(color: LineColors.lineColor(for: leg.line, operatorName: leg.operatorName, inverted: true),
                         size: 16)
            }
        case .transfer:
            if let nextLeg = step.nextLeg {
                TripActivityLineBadge(line: nextLeg.line,
                                      color: LineColors.lineColor(for: nextLeg.line, operatorName: nextLeg.operatorName),
                                      compact: true)
            }
        case .arrival:
            TripActivityStopIcon(terminus: true, compact: true)
        case nil:
            EmptyView()
        }
    }
}

/// Un nom d'arrêt en entier sur une ligne, « Genève **Rive** » (la commune en régulier,
/// l'arrêt en gras) ; trop long pour la place, sans la commune. La police vient de l'appelant.
///
/// Jamais dans le bandeau de l'app (`TripLiveAccessory`) : la barre d'onglets dimensionne le
/// bandeau d'après son contenu, et le choix de `ViewThatFits` y basculait en boucle — l'app
/// gelait pendant tout le suivi.
struct TripActivityStopName: View {
    let name: String

    var body: some View {
        ViewThatFits(in: .horizontal) {
            Text(stopName: name)
                .lineLimit(1)
            Text(stopName: shortStopName(name))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
    }
}

/// Le point de départ ou d'arrivée d'un trajet, comme aux deux bouts d'un itinéraire
/// (`TripTimeline`). Le fond du système : la couleur de l'app n'existe pas dans le widget.
struct TripActivityStopIcon: View {
    var terminus = false
    var compact = false

    var body: some View {
        StopIcon(color: Color(uiColor: .systemBackground), terminus: terminus, size: compact ? 16 : 22)
    }
}

/// Les minutes restantes, qui défilent sans mise à jour de l'app.
///
/// Les formats système n'ont pas de forme courte : « 4 minutes », pas « 4' » (le minuteur réglé
/// à la minute aussi). Un format maison ne serait pas évalué par l'écran verrouillé, qui
/// redessine le texte sans l'extension. Arrondi à la minute la plus proche (l'ancre est
/// décalée de 30 s).
struct TripActivityMinutes: View {
    let target: Date?

    var body: some View {
        if let target {
            Text(.currentDate, format: .offset(to: target.addingTimeInterval(30), allowedFields: [.minute],
                                               maxFieldCount: 1, sign: .never))
                .monospacedDigit()
                .lineLimit(1)
        }
    }
}

// MARK: - Aperçus

#if DEBUG
extension TripActivityState {
    /// Le 12 de Rive à Terrassière, puis le 19 jusqu'à Cornavin. Données inventées, calées sur
    /// maintenant ; `boardIn` : minutes avant la montée dans le 12 (négatif : déjà à bord).
    /// `alightName` : la descente du 12, pour essayer un nom long.
    static func preview(boardIn: Double = 4, delay: Int = 0, alert: String? = nil,
                        question: Question? = nil, alightName: String = "Genève, Terrassière") -> TripActivityState {
        let now = Date()
        let board = now.addingTimeInterval(boardIn * 60)
        let calls = ["Bel-Air", "Molard", "Rive", "Terrassière"].enumerated().map { index, name in
            Call(name: name, time: board.addingTimeInterval(TimeInterval(index - 2) * 120))
        }
        return TripActivityState(
            legs: [
                .init(line: "12", operatorName: "Transports Publics Genevois", transportType: "Tram",
                      destination: "Carouge, Bachet", boardName: "Genève, Rive", boardQuay: "B",
                      board: board, alight: board.addingTimeInterval(5 * 60), alightName: alightName,
                      delay: delay, calls: calls),
                .init(line: "19", operatorName: "Transports Publics Genevois", transportType: "Bus",
                      destination: "Vernier, Village", boardName: "Genève, Terrassière", boardQuay: "",
                      board: board.addingTimeInterval(11 * 60), alight: board.addingTimeInterval(19 * 60),
                      alightName: "Genève, gare Cornavin", delay: 0),
            ],
            departure: now, arrival: board.addingTimeInterval(21 * 60), arrivalDelay: delay,
            alert: alert, updated: now)
            .asking(question)
    }

    func asking(_ question: Question?) -> TripActivityState {
        var state = self
        state.question = question
        return state
    }
}

let previewAttributes = TripActivityAttributes(key: "preview", title: "Travail",
                                               origin: "Genève, Rive", destination: "Genève, gare Cornavin")

/// L'activité dans ses états, dessinée dans l'app : le simulateur ne montre ni l'écran
/// verrouillé ni la Dynamic Island (capture : `tpgnext://sheet?name=activity`).
struct TripActivityGallery: View {
    private let states: [(String, TripActivityState)] = [
        ("Attente", .preview()),
        ("Le véhicule arrive", .preview(boardIn: 0.5)),
        ("À bord", .preview(boardIn: -2)),
        ("À bord, nom long", .preview(boardIn: -2, alightName: "Plan-les-Ouates, ZIPLO-Pré-Fleuri Nord")),
        ("Correspondance", .preview(boardIn: -7)),
        ("Arrivé", .preview(boardIn: -30)),
    ]

    /// `TPG_ACTIVITY_REVERSED` : les derniers états en haut, pour les capturer sans défiler.
    private var shown: [(String, TripActivityState)] {
        ProcessInfo.processInfo.environment["TPG_ACTIVITY_REVERSED"] == nil ? states : states.reversed()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(shown, id: \.0) { title, state in
                    let step = TripActivityStep(attributes: previewAttributes, state: state, now: Date())
                    Text(title).font(.caption).foregroundStyle(.secondary)
                    TripActivityContent(step: step, alert: state.alert, key: "preview")
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
                    // La Dynamic Island compacte : marqueur à gauche, minutes à droite.
                    HStack {
                        TripActivityMarker(step: step, compact: true)
                            .padding(.horizontal, 3)
                        Spacer(minLength: 90)
                        TripActivityMinutes(target: step.target)
                            .font(.caption2.bold())
                            .minimumScaleFactor(0.6)
                            .frame(maxWidth: 64)
                            .padding(.trailing, 4)
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 37)
                    .foregroundStyle(.white)
                    .background(.black, in: Capsule())
                    .frame(width: 250)
                }
            }
            .padding()
        }
    }
}

#Preview("Écran verrouillé", as: .content, using: previewAttributes) {
    TripLiveActivity()
} contentStates: {
    TripActivityState.preview()
    TripActivityState.preview(boardIn: -2)
    TripActivityState.preview(boardIn: -7)
    TripActivityState.preview(boardIn: -16)
    TripActivityState.preview(boardIn: -30)
    TripActivityState.preview(delay: 6, alert: "Ligne 12 : environ 5 min de retard.")
}

#Preview("Dynamic Island", as: .dynamicIsland(.expanded), using: previewAttributes) {
    TripLiveActivity()
} contentStates: {
    TripActivityState.preview()
    TripActivityState.preview(boardIn: -2)
    TripActivityState.preview(boardIn: -7, alert: "Le 19 a 4 minutes de retard")
    TripActivityState.preview(boardIn: -22)
    TripActivityState.preview(boardIn: -4, question: .init(stop: "Terrassière", line: "19"))
}

#Preview("Dynamic Island compacte", as: .dynamicIsland(.compact), using: previewAttributes) {
    TripLiveActivity()
} contentStates: {
    TripActivityState.preview()
}
#endif
