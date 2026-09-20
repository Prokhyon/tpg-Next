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
                DynamicIslandExpandedRegion(.bottom) {
                    if let question = step.question {
                        TripActivityQuestion(question: question, key: context.attributes.key, compact: true)
                            .padding(.horizontal, 6)
                    } else {
                        TripActivityTimeline(step: step, alert: context.state.alert, compact: true, verticalInset: 4)
                            .padding(.horizontal, 6)
                    }
                }
            } compactLeading: {
                // De l'air autour du badge : collé au bord, la caméra le rogne.
                TripActivityMarker(step: step, compact: true)
                    .padding(.horizontal, 3)
            } compactTrailing: {
                // Le compte à rebours du système, en minutes et secondes : « 4 minutes » en
                // toutes lettres ne tient pas à côté de la caméra.
                TripActivityTimer(target: step.target)
                    .font(.caption2.bold())
                    .frame(maxWidth: 52)
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
    /// En gros : l'arrêt de montée, de descente, ou d'arrivée.
    let stopName: String
    /// En petit dessous : ce qu'on y fait.
    let action: String
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
    /// La question posée au voyageur, s'il y en a une.
    let question: TripActivityState.Question?

    init(attributes: TripActivityAttributes, state: TripActivityState, now: Date) {
        phase = state.phase(at: now)
        isWalking = state.isWalking(at: now)
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
            stopName = shortStopName(leg.boardName)
            // En attente, l'arrêt de montée et les minutes suffisent.
            vehicleNote = nil
            var parts = [String(localized: "Montée")]
            if !leg.boardQuay.isEmpty { parts.append(String(localized: "quai \(leg.boardQuay)")) }
            // La direction en entier : « Village » seul ne dit pas où va la ligne.
            // La ligne dans le texte : en attente, le marqueur montre la marche ou l'attente.
            parts.append("\(leg.line) → \(leg.destination)")
            if leg.delay >= 2 { parts.append("+\(leg.delay)'") }
            action = parts.joined(separator: " · ")
        case .riding(let index):
            let leg = state.legs[index]
            self.leg = leg
            let name = shortStopName(leg.alightName)
            stopName = name
            // Déjà à l'arrêt de descente : l'arrêt en gros suffit.
            vehicleNote = leg.vehicleStop(at: now).flatMap { stop in
                stop == name ? nil : String(localized: "Actuellement à \(stop)")
            }
            action = String(localized: "Descente")
        case .arrived:
            leg = state.legs.last
            vehicleNote = nil
            stopName = shortStopName(attributes.destination)
            // Le trajet est fini : on le dit, sans répéter le retard affiché en route.
            action = String(localized: "Trajet terminé · arrivé à \(state.arrival.formatted(date: .omitted, time: .shortened))")
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

    /// « Terrassière · 5' de trajet », « 6' d'attente », « Arrivée à 18:55 ».
    var nextText: String? {
        switch next {
        case .ride(let stop, let minutes):
            return String(localized: "\(shortStopName(stop)) · \(minutes)' de trajet")
        case .transfer(_, let wait):
            guard let nextLeg else { return nil }
            return String(localized: "\(wait)' d'attente · \(nextLeg.line) → \(nextLeg.destination)")
        case .arrival(let date, let walk):
            let time = date.formatted(date: .omitted, time: .shortened)
            return walk > 0
                ? String(localized: "Arrivée à \(time) · \(walk)' à pied")
                : String(localized: "Arrivée à \(time)")
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
                        Text(step.stopName)
                            .font(compact ? .title3.bold() : .title2.bold())
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Spacer(minLength: 8)
                        TripActivityMinutes(target: step.target)
                            .font(compact ? .subheadline.bold() : .headline)
                    }
                    Text(step.action)
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
                    Text(nextText)
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
            Text(step.stopName)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if let alert {
                Text(alert)
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .lineLimit(1)
            } else if let detail = step.nextText ?? (step.isArrived ? step.action : nil) {
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(8)
    }
}

/// En haut de la frise : la ligne de l'étape en cours, ou le véhicule à l'arrivée.
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
            // Pas encore dedans : ce qu'il y a à faire d'ici là, marcher ou attendre.
            symbol(step.isWalking ? "figure.walk" : "clock")
        case .arrived:
            symbol(nil)
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
        .font(compact ? .caption : .title3)
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
            Circle()
                .strokeBorder(step.color, lineWidth: 3)
                .background(Circle().fill(.background))
                .frame(width: 13, height: 13)
        case .transfer:
            if let nextLeg = step.nextLeg {
                TripActivityLineBadge(line: nextLeg.line,
                                      color: LineColors.lineColor(for: nextLeg.line, operatorName: nextLeg.operatorName),
                                      compact: true)
            }
        case .arrival:
            Image(systemName: "mappin.circle.fill")
                .font(.body)
                .foregroundStyle(.secondary)
        case nil:
            EmptyView()
        }
    }
}

/// Les minutes restantes, qui défilent sans mise à jour de l'app.
///
/// Les formats système n'ont pas de forme courte : « 4 minutes », pas « 4' ». Un format maison
/// ne serait pas évalué par l'écran verrouillé, qui redessine le texte sans l'extension.
/// Arrondi à la minute la plus proche (l'ancre est décalée de 30 s).
/// Le décompte court de la Dynamic Island : « 4:32 », qui défile tout seul. Les formats en
/// toutes lettres du système (« 4 minutes ») ne tiennent pas à côté de la caméra.
struct TripActivityTimer: View {
    let target: Date?

    var body: some View {
        if let target, target > .now {
            Text(timerInterval: Date.now...target, countsDown: true, showsHours: false)
                .monospacedDigit()
                .lineLimit(1)
                .multilineTextAlignment(.trailing)
        }
    }
}

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

private extension TripActivityState {
    /// Le 12 de Rive à Terrassière, puis le 19 jusqu'à Cornavin. Données inventées, calées sur
    /// maintenant ; `boardIn` : minutes avant la montée dans le 12 (négatif : déjà à bord).
    static func preview(boardIn: Double = 4, delay: Int = 0, alert: String? = nil) -> TripActivityState {
        let now = Date()
        let board = now.addingTimeInterval(boardIn * 60)
        let calls = ["Bel-Air", "Molard", "Rive", "Terrassière"].enumerated().map { index, name in
            Call(name: name, time: board.addingTimeInterval(TimeInterval(index - 2) * 120))
        }
        return TripActivityState(
            legs: [
                .init(line: "12", operatorName: "Transports Publics Genevois", transportType: "Tram",
                      destination: "Carouge, Bachet", boardName: "Genève, Rive", boardQuay: "B",
                      board: board, alight: board.addingTimeInterval(5 * 60), alightName: "Genève, Terrassière",
                      delay: delay, calls: calls),
                .init(line: "19", operatorName: "Transports Publics Genevois", transportType: "Bus",
                      destination: "Vernier, Village", boardName: "Genève, Terrassière", boardQuay: "",
                      board: board.addingTimeInterval(11 * 60), alight: board.addingTimeInterval(19 * 60),
                      alightName: "Genève, gare Cornavin", delay: 0),
            ],
            departure: now, arrival: board.addingTimeInterval(21 * 60), arrivalDelay: delay,
            alert: alert, updated: now)
    }
}

private let previewAttributes = TripActivityAttributes(key: "preview", title: "Travail",
                                                       origin: "Genève, Rive", destination: "Genève, gare Cornavin")

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
}

#Preview("Dynamic Island compacte", as: .dynamicIsland(.compact), using: previewAttributes) {
    TripLiveActivity()
} contentStates: {
    TripActivityState.preview()
}
