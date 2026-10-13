//
//  CaptureSupport.swift
//  tpg Next
//
//  Captures de l'App Store (Debug seulement) : réglages posés par les liens `TPG_DEBUG_URLS`
//  avant d'ouvrir un écran, et choix d'un itinéraire à la frise équilibrée.
//

#if DEBUG
import SwiftUI
import tpgNextFunc

enum CaptureOptions {
    /// `quaymap?quay=B` : le quai sélectionné à l'ouverture de la carte des quais.
    static var quay: String?
    /// `quaymap?pitch=60` : la carte des quais inclinée, bâtiments en 3D.
    static var pitch: Double?
    /// `quaymap?distance=900` : la distance de la caméra inclinée, en mètres.
    static var distance: Double = 450
    /// `quicktrip?select=1` : sur grand écran, le meilleur résultat s'ouvre à droite.
    static var selectsBestTrip = false

    /// `stop?grouped=1` : les départs groupés par ligne.
    static var stopGrouped = false
    /// `stop?count=120` : le nombre de départs demandés, pour remplir chaque ligne.
    static var stopCount: Int?
    /// `stop?filter=1:Trois,5:Vallard` : les directions gardées (ligne et un morceau de la
    /// destination, sans accents), la capsule du filtre ouverte.
    static var stopFilter: [(line: String, destination: String)] = []
    /// `stop?open=5` : la ligne dont les directions sont dépliées dans le filtre.
    static var stopOpenLine: String?

    /// Les clés « ligne;destination » des groupes qui correspondent à `stopFilter`.
    static func filterKeys(in groups: [String: [StopEvent]]) -> Set<String> {
        let fold = { (text: String) in text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil) }
        return Set(groups.keys.filter { key in
            let parts = key.split(separator: ";", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { return false }
            return stopFilter.contains { $0.line == parts[0] && fold(parts[1]).contains(fold($0.destination)) }
        })
    }
}

extension TripEvent {
    private var vehicleLegs: [TripLeg] { legs.filter { !$0.transfer } }

    /// Les lignes empruntées.
    var captureLines: Set<String> { Set(vehicleLegs.map(\.publishedLineName)) }

    /// L'écart entre les deux couleurs de lignes les plus proches (0 : identiques), dans
    /// l'espace RGB ; 0,6 pour un trajet d'une seule ligne.
    private var colorContrast: Double {
        let colors = vehicleLegs.map { leg -> Color.Resolved in
            LineColors.lineColor(for: leg.publishedLineName, operatorName: leg.legOperator).resolve(in: EnvironmentValues())
        }
        guard colors.count > 1 else { return 0.6 }
        var closest = Double.infinity
        for i in colors.indices {
            for j in colors.indices where j > i {
                let (a, b) = (colors[i], colors[j])
                let distance = sqrt(pow(Double(a.red - b.red), 2) + pow(Double(a.green - b.green), 2) + pow(Double(a.blue - b.blue), 2))
                closest = min(closest, distance)
            }
        }
        return closest
    }

    /// La part du trajet passée en véhicule, un point s'il prend au moins deux lignes, et le
    /// contraste de leurs couleurs : une frise colorée plutôt que de la marche et de l'attente.
    var captureScore: Double {
        guard let start = startDate, let end = endDate, end > start else { return 0 }
        let riding = vehicleLegs.compactMap { leg -> Double? in
            guard let board = leg.boardDate, let alight = leg.alightDate else { return nil }
            return alight.timeIntervalSince(board)
        }.reduce(0, +)
        return riding / end.timeIntervalSince(start) + (vehicleLegs.count >= 2 ? 1 : 0) + min(colorContrast, 0.6)
    }
}

extension Array where Element == TripEvent {
    /// Le plus bel itinéraire qui part dans l'heure suivant `date` (à cinq minutes près), en
    /// évitant les lignes déjà montrées ailleurs (`avoiding`).
    func bestForCapture(after date: Date = AppClock.now(), avoiding lines: Set<String> = []) -> TripEvent? {
        let window = filter {
            guard let start = $0.startDate else { return false }
            return start >= date.addingTimeInterval(-300) && start <= date.addingTimeInterval(3600)
        }
        return (window.isEmpty ? self : window).max {
            $0.captureScore - Double($0.captureLines.intersection(lines).count) <
                $1.captureScore - Double($1.captureLines.intersection(lines).count)
        }
    }
}
#endif
