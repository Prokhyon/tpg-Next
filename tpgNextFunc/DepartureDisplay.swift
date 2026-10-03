//
//  DepartureDisplay.swift
//  tpgNextFunc
//
//  L'heure d'un départ et son quai, tels que l'app, la montre et le widget les affichent.
//

import SwiftUI

/// Ce qu'un départ affiche à la place de son heure brute.
///
/// Remplace une chaîne codée (`"0"` pour « à l'arrêt », `"14:05;(+3')"` pour un retard)
/// que chaque vue redécoupait à sa façon.
public enum DepartureDisplay: Equatable {
    /// Le véhicule est à l'arrêt : l'app montre son icône.
    case atStop
    case lessThanAMinute(delayed: Bool)
    case minutes(Int, delayed: Bool)
    /// Une heure de passage, « 14:05 ».
    case clock(String, delayed: Bool)
    /// L'heure prévue et le retard, affichés séparément : « 14:05 » et « (+3') ».
    case plannedWithDelay(planned: String, delay: String)
    /// Course supprimée à cet arrêt.
    case cancelled
    /// Heure illisible.
    case unknown

    /// Le texte affiché, et lu par VoiceOver. `"0"` pour un véhicule à l'arrêt.
    public var text: String {
        switch self {
        case .atStop: return "0"
        case .lessThanAMinute: return "< 1'"
        case .minutes(let minutes, _): return "\(minutes)'"
        case .clock(let time, _): return time
        case .plannedWithDelay(let planned, let delay): return "\(planned);\(delay)"
        case .cancelled: return String(localized: "Supprimé", bundle: #bundle)
        case .unknown: return ""
        }
    }

    /// Mis en évidence (couleur d'accent) : départ en retard.
    public var isHighlighted: Bool {
        switch self {
        case .lessThanAMinute(let delayed), .minutes(_, let delayed), .clock(_, let delayed): return delayed
        case .plannedWithDelay: return true
        case .atStop, .cancelled, .unknown: return false
        }
    }
}

/// Minutes restantes, heure de passage ou heure prévue avec son retard.
/// - Parameter now: l'instant de référence du décompte. Le widget passe la date de
///   l'entrée de timeline qu'il est en train de construire, pas l'heure courante.
/// L'affichage d'un départ : « Supprimé » pour une course supprimée, son heure sinon.
public func departureDisplay(for event: StopEvent, showTime: Bool, at now: Date = Date()) -> DepartureDisplay {
    if event.cancelled {
        return .cancelled
    }
    return departureDisplay(timetabled: event.timetabledTime, estimated: event.estimatedTime, showTime: showTime, at: now)
}

public func departureDisplay(timetabled: String, estimated: String, showTime: Bool, at now: Date = Date()) -> DepartureDisplay {
    let estimated = estimated.isEmpty ? timetabled : estimated
    guard let timetableTime = OJPDate.date(from: timetabled),
          let estimatedTime = OJPDate.date(from: estimated) else {
        Log.data.error("Dates illisibles : \(timetabled) / \(estimated)")
        return .unknown
    }
    // Lu dans le groupe d'app : @AppStorage écrit dans .standard, invisible depuis le widget.
    let delayIncludedInTime = SharedStorage.bool(forSetting: SettingKey.delayIncludedInTime)
    let minutesRemaining = estimatedTime.timeIntervalSince(now) / 60
    let delay = Int(estimatedTime.timeIntervalSince(timetableTime) / 60)

    if showTime && minutesRemaining > 0 {
        if delay == 0 {
            return .clock(OJPDate.clockTime(from: timetableTime), delayed: false)
        }
        if delayIncludedInTime {
            return .clock(OJPDate.clockTime(from: estimatedTime), delayed: delay > 0)
        }
        return .plannedWithDelay(planned: OJPDate.clockTime(from: timetableTime),
                                 delay: delay > 0 ? "(+\(delay)')" : "(\(delay)')")
    } else if minutesRemaining < 60 && minutesRemaining > 1 {
        return .minutes(Int(minutesRemaining), delayed: delay > 0)
    } else if minutesRemaining <= 1 && minutesRemaining > 0.5 {
        return .lessThanAMinute(delayed: delay > 0)
    } else if Int(minutesRemaining) == 0 {
        return .atStop
    } else {
        return .clock(OJPDate.clockTime(from: estimatedTime), delayed: false)
    }
}

/// L'heure d'un départ, telle que l'app l'affiche partout.
public struct DepartureTimeView: View {
    public enum Layout {
        /// Heure prévue au-dessus du retard.
        case stacked
        /// Heure prévue et retard côte à côte.
        case inline(spacing: CGFloat)
    }

    let display: DepartureDisplay
    let transportType: String
    let layout: Layout
    let iconWidth: CGFloat?
    let showsIcon: Bool

    /// - Parameter showsIcon: `false` affiche « Maintenant » au lieu de l'icône du véhicule à l'arrêt.
    public init(_ display: DepartureDisplay, transportType: String, layout: Layout = .stacked,
                iconWidth: CGFloat? = nil, showsIcon: Bool = true) {
        self.display = display
        self.transportType = transportType
        self.layout = layout
        self.iconWidth = iconWidth
        self.showsIcon = showsIcon
    }

    public var body: some View {
        switch display {
        case .atStop where showsIcon:
            // Au moins la largeur de l'icône : elle grandit avec le texte et débordait
            // sur la destination quand la place réservée restait fixe.
            transportIcon(with: transportType)
                .fixedSize()
                .frame(minWidth: iconWidth)
        case .atStop:
            // « 0 », seul à côté d'un nom d'arrêt ou sous « Heure », ne se lisait pas.
            Text(String(localized: "Maintenant", bundle: #bundle))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        case .plannedWithDelay(let planned, let delay):
            stack {
                Text(planned)
                    .lineLimit(1)
                Text(delay)
                    .foregroundStyle(Color.accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
        case .cancelled:
            Text(display.text)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .foregroundStyle(.red)
        default:
            // Une seule ligne : avec un texte agrandi, « 16:17 » passait sinon à la ligne.
            Text(display.text)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .foregroundStyle(display.isHighlighted ? Color.accent : Color.primary)
        }
    }

    private var stack: AnyLayout {
        switch layout {
        case .stacked: return AnyLayout(VStackLayout(spacing: 0))
        case .inline(let spacing): return AnyLayout(HStackLayout(spacing: spacing))
        }
    }
}

/// Le quai dans un carré : « A », « 3 », « 12 ». Un point d'interrogation quand il est
/// inconnu ou n'a pas de symbole SF (« A1 », « É »), au lieu d'un symbole vide.
public struct QuayIcon: View {
    let quay: String
    let dimsUnknown: Bool

    /// - Parameter dimsUnknown: atténue le point d'interrogation (widget).
    public init(quay: String, dimsUnknown: Bool = false) {
        self.quay = quay
        self.dimsUnknown = dimsUnknown
    }

    public var body: some View {
        if let symbol = Self.symbolName(for: quay) {
            Image(systemName: symbol)
        } else if dimsUnknown {
            Image(systemName: "questionmark.square.fill").foregroundStyle(.secondary)
        } else {
            Image(systemName: "questionmark.square.fill")
        }
    }

    /// Les symboles `x.square.fill` existent pour les lettres, les chiffres et les nombres jusqu'à 50.
    static func symbolName(for quay: String) -> String? {
        let quay = quay.lowercased()
        if quay.count == 1, let character = quay.first, character.isASCII, character.isLetter || character.isNumber {
            return "\(quay).square.fill"
        }
        if let number = Int(quay), (0...50).contains(number) {
            return "\(number).square.fill"
        }
        return nil
    }
}
