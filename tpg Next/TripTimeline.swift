//
//  TripTimeline.swift
//  tpg Next
//
//  La frise d'un itinéraire, partagée par les résultats, les itinéraires enregistrés, le
//  prochain trajet de l'accueil et son widget. Compilé aussi pour le widget : ses aperçus, qui
//  utilisent `PreviewData`, sont dans `TripTimelinePreviews.swift`.
//

import SwiftUI
import tpgNextFunc

/// La frise d'un itinéraire, de gauche à droite : chaque ligne à la place et sur la durée de
/// son étape, la marche en pointillés. Si les badges ne tiennent pas même serrés, elle défile.
///
/// Plafonnée à XXXL : aux tailles d'accessibilité, les badges débordaient au-dessus et en
/// dessous. Quand elle défile, ses fondus débordent de 15 points sur les côtés : laisser au
/// moins autant de marge autour.
struct TripTimeline: View {
    let event: TripEvent

    var body: some View {
        CappedTripTimeline(event: event)
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }
}

extension EnvironmentValues {
    /// Faux dans un widget, qui ne défile pas : une frise trop large y devient la suite de ses
    /// lignes (« 12 › 15 »).
    @Entry var tripTimelineScrolls = true
}

/// Une vue à part pour que sa hauteur suive le plafond posé par `TripTimeline` : un
/// `@ScaledMetric` lit la taille de texte de la vue qui le déclare.
private struct CappedTripTimeline: View {
    let event: TripEvent
    @Environment(\.tripTimelineScrolls) private var scrolls
    /// Hauteur de la frise : 30 à la taille normale, plus avec un texte agrandi.
    @ScaledMetric private var height: CGFloat = 30
    /// Diamètre des arrêts de départ et d'arrivée : la piste passe dessous et semble en sortir.
    private let endpointSize: CGFloat = 18
    /// Largeur des fondus d'une frise qui défile. Ils débordent d'autant dans la marge autour
    /// de la frise, qui doit donc être au moins aussi large.
    private let fadeLength: CGFloat = 15

    var body: some View {
        ViewThatFits(in: .horizontal) {
            content
            if scrolls {
                scrolling
            } else {
                // Un widget ne défile pas : les lignes seules, à la suite.
                lineSequence
            }
        }
        .frame(height: height)
    }

    /// Trop large : la frise défile, entre deux fondus.
    private var scrolling: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            content
                .padding(.horizontal, fadeLength)
        }
        // Le contour des badges dépasse de la frise : rogné par le ScrollView, le haut et
        // le bas des badges disparaissaient. Seuls les fondus limitent la vue, et
        // uniquement sur les côtés.
        .scrollClipDisabled()
        .mask {
            Rectangle()
                .overlay(alignment: .leading) {
                    ScrollMask(leading: true, vertical: false, gradientLength: fadeLength)
                }
                .padding(.vertical, -8)
        }
        .mask {
            Rectangle()
                .overlay(alignment: .trailing) {
                    ScrollMask(leading: false, vertical: false, gradientLength: fadeLength)
                }
                .padding(.vertical, -8)
        }
        // Les fondus débordent dans la marge autour de la frise : défilée jusqu'à un bout,
        // la frise a son arrêt aligné sur celui des frises qui ne défilent pas.
        .padding(.horizontal, -fadeLength)
    }

    /// Faute de place, et sans défilement : « 12 › 15 », de gauche à droite.
    private var lineSequence: some View {
        let lines = event.vehicleLegs
        return HStack(spacing: 4) {
            ForEach(Array(lines.enumerated()), id: \.offset) { index, leg in
                if index > 0 {
                    Image(systemName: "chevron.forward")
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                }
                BusLineIcon(lineName: leg.publishedLineName, operatorName: leg.legOperator)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var content: some View {
        let spans = event.legSpans
        return HStack(spacing: 0) {
            StopIcon(color: .customBackground, size: endpointSize)
                .zIndex(1) // au-dessus du bout de la piste
            TripTimelineLayout(endOverhang: endpointSize / 2) {
                // La piste pleine, interrompue là où l'on marche.
                ForEach(Array(trackRanges(spans).enumerated()), id: \.offset) { _, range in
                    RoundedRectangle(cornerRadius: 5)
                        .frame(height: 2)
                        .timelineFill(range, reachesEnds: true)
                }
                ForEach(spans) { span in
                    let leg = span.leg
                    if !leg.publishedLineName.isEmpty {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(LineColors.lineColor(for: leg.publishedLineName, operatorName: leg.legOperator))
                            .frame(height: 5)
                            // Distinctes entre elles et des arrêts de départ et d'arrivée.
                            .padding(.horizontal, 2)
                            .timelineFill(span.range)
                        BusLineIcon(lineName: leg.publishedLineName, operatorName: leg.legOperator)
                            .background {
                                Capsule()
                                    .fill(.color1)
                            }
                            .timelineBadge(span.range)
                    } else if let walk = drawnWalk(span) {
                        DottedLine()
                            .stroke(Color.primary, style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [0, 3]))
                            .frame(height: 2)
                            // Les points ne touchent ni la piste pleine ni les arrêts.
//                            .padding(.horizontal, 3)
                            .timelineFill(walk)
//                        if (leg.walkDuration ?? 0) >= 5 * 60 {
//                            Image(systemName: "figure.walk")
//                                .font(.caption)
////                                .background {
////                                    Circle()
////                                        .fill(.color1)
////                                        .blur(radius: 3)
////                                }
//                                .timelineBadge(walk)
//                        }
                    }
                }
            }
            StopIcon(color: .customBackground, terminus: true, size: endpointSize)
                .zIndex(1)
        }
    }

    /// Les pointillés d'une étape à pied. Une minute de marche ou moins reste en trait plein.
    private func drawnWalk(_ span: TripLegSpan) -> ClosedRange<Double>? {
        (span.leg.walkDuration ?? 0) > 60 ? span.walk : nil
    }

    /// Ce qui reste de la frise une fois les pointillés retirés : les véhicules et les attentes.
    private func trackRanges(_ spans: [TripLegSpan]) -> [ClosedRange<Double>] {
        var ranges: [ClosedRange<Double>] = []
        var start = 0.0
        for walk in spans.compactMap(drawnWalk).sorted(by: { $0.lowerBound < $1.lowerBound }) {
            if walk.lowerBound > start {
                ranges.append(start...walk.lowerBound)
            }
            start = max(start, walk.upperBound)
        }
        if start < 1 {
            ranges.append(start...1)
        }
        return ranges
    }
}

private struct DottedLine: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        }
    }
}

/// Ce qu'une vue occupe sur la frise.
private struct TimelinePlacement {
    var range: ClosedRange<Double>
    var isBadge: Bool
    var reachesEnds = false
}

private struct TimelinePlacementKey: LayoutValueKey {
    static let defaultValue = TimelinePlacement(range: 0...1, isBadge: false)
}

private extension View {
    /// Une barre ou un tracé : de la largeur de sa fraction du trajet.
    /// - Parameter reachesEnds: au départ et à l'arrivée, la vue se prolonge sous l'icône de
    ///   l'arrêt, qui cache ses angles arrondis.
    func timelineFill(_ range: ClosedRange<Double>, reachesEnds: Bool = false) -> some View {
        layoutValue(key: TimelinePlacementKey.self,
                    value: TimelinePlacement(range: range, isBadge: false, reachesEnds: reachesEnds))
    }

    /// Un badge : garde sa taille, centré sur sa fraction du trajet, qui s'élargit pour le contenir.
    func timelineBadge(_ range: ClosedRange<Double>) -> some View {
        zIndex(1)
            .layoutValue(key: TimelinePlacementKey.self, value: TimelinePlacement(range: range, isBadge: true))
    }
}

/// La frise : chaque vue est placée sur la fraction du trajet que lui donne `timelineFill(_:)`
/// ou `timelineBadge(_:)`, selon une `TimelineScale`.
private struct TripTimelineLayout: Layout {
    /// Espace entre deux badges voisins.
    var badgeSpacing: CGFloat = 6
    /// Largeur minimale d'un morceau de trajet sans badge (attente, bout de piste).
    var minimumGap: CGFloat = 4
    /// De combien une vue `reachesEnds` dépasse de la frise, sous les arrêts de départ et d'arrivée.
    var endOverhang: CGFloat = 0

    /// Sans largeur proposée (dans un `ScrollView`, ou mesurée par `ViewThatFits`) : la plus
    /// petite largeur où tous les badges tiennent sans se toucher.
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let height = subviews.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
        let minimum = scale(subviews, width: nil).width
        return CGSize(width: max(proposal.width ?? minimum, minimum), height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let scale = scale(subviews, width: bounds.width)
        for subview in subviews {
            let placement = subview[TimelinePlacementKey.self]
            if placement.isBadge {
                subview.place(at: CGPoint(x: bounds.minX + scale.center(of: placement.range), y: bounds.midY),
                              anchor: .center,
                              proposal: .unspecified)
            } else {
                var start = scale.x(placement.range.lowerBound)
                var end = scale.x(placement.range.upperBound)
                if placement.reachesEnds {
                    if placement.range.lowerBound <= 0 { start -= endOverhang }
                    if placement.range.upperBound >= 1 { end += endOverhang }
                }
                subview.place(at: CGPoint(x: bounds.minX + start, y: bounds.midY),
                              anchor: .leading,
                              proposal: ProposedViewSize(width: max(0, end - start), height: bounds.height))
            }
        }
    }

    private func scale(_ subviews: Subviews, width: CGFloat?) -> TimelineScale {
        let badges = subviews
            .filter { $0[TimelinePlacementKey.self].isBadge }
            .map { (range: $0[TimelinePlacementKey.self].range, width: $0.sizeThatFits(.unspecified).width + badgeSpacing) }
        return TimelineScale(badges: badges, width: width, minimumGap: minimumGap)
    }
}

/// D'une fraction du trajet à une abscisse : proportionnel au temps, sauf là où un badge a
/// besoin de plus de place que la durée de son étape ne lui en donne. Le reste du trajet se
/// resserre d'autant.
private struct TimelineScale {
    private var times: [Double] = [0]
    private var positions: [CGFloat] = [0]
    private var badgeFrames: [(range: ClosedRange<Double>, start: CGFloat, end: CGFloat)] = []
    /// La largeur proposée, ou la plus petite où tous les badges tiennent.
    private(set) var width: CGFloat = 0

    init(badges: [(range: ClosedRange<Double>, width: CGFloat)], width proposedWidth: CGFloat?, minimumGap: CGFloat) {
        // Le trajet découpé en morceaux : les étapes à badge, et ce qu'il y a entre elles.
        var pieces: [(time: Double, minimum: CGFloat, badge: ClosedRange<Double>?)] = []
        var cursor = 0.0
        for badge in badges.sorted(by: { $0.range.lowerBound < $1.range.lowerBound }) {
            let start = max(badge.range.lowerBound, cursor)
            let end = max(badge.range.upperBound, start)
            if start > cursor {
                pieces.append((start - cursor, minimumGap, nil))
            }
            pieces.append((end - start, badge.width, badge.range))
            cursor = end
        }
        if cursor < 1 {
            pieces.append((1 - cursor, minimumGap, nil))
        }
        let minimumWidth = pieces.reduce(CGFloat(0)) { $0 + $1.minimum }
        width = max(proposedWidth ?? minimumWidth, minimumWidth)

        // Les morceaux trop courts pour leur minimum le reçoivent ; les autres se partagent le
        // reste au prorata du temps. Chaque tour en fixe au moins un de plus.
        var fixed = Set<Int>()
        var ratio: CGFloat = 0
        while true {
            let fixedWidth = fixed.reduce(CGFloat(0)) { $0 + pieces[$1].minimum }
            let freeTime = pieces.indices.filter { !fixed.contains($0) }.reduce(0.0) { $0 + pieces[$1].time }
            ratio = freeTime > 0 ? (width - fixedWidth) / CGFloat(freeTime) : 0
            let tooShort = pieces.indices.filter { !fixed.contains($0) && CGFloat(pieces[$0].time) * ratio < pieces[$0].minimum }
            if tooShort.isEmpty { break }
            fixed.formUnion(tooShort)
        }

        var x: CGFloat = 0
        var time = 0.0
        for (index, piece) in pieces.enumerated() {
            let pieceWidth = fixed.contains(index) ? piece.minimum : CGFloat(piece.time) * ratio
            if let badge = piece.badge {
                badgeFrames.append((badge, x, x + pieceWidth))
            }
            x += pieceWidth
            time += piece.time
            times.append(time)
            positions.append(x)
        }
    }

    func x(_ time: Double) -> CGFloat {
        for index in times.indices.dropLast() where time <= times[index + 1] {
            let duration = times[index + 1] - times[index]
            guard duration > 0 else { continue }
            let progress = CGFloat((time - times[index]) / duration)
            return positions[index] + (positions[index + 1] - positions[index]) * progress
        }
        return positions.last ?? 0
    }

    func center(of range: ClosedRange<Double>) -> CGFloat {
        if let frame = badgeFrames.first(where: { $0.range == range }) {
            return (frame.start + frame.end) / 2
        }
        return x((range.lowerBound + range.upperBound) / 2)
    }
}
