//
//  LineDirectory.swift
//  tpgNextFunc
//
//  Les lignes de Suisse et leurs transporteurs, tirés du registre national (ATLAS) : numéro,
//  catégorie et parcours. Le fichier `Lines.json` est régénéré par `Scripts/lines-from-atlas.py`.
//

import Foundation

/// Un transporteur du registre.
public struct TransitOperator: Codable, Hashable, Identifiable {
    /// Identifiant ATLAS (SAID) : « 100680 » pour les tpg.
    public let id: String
    /// Le nom en français : « Transports Publics Genevois », « CarPostal SA ».
    public let name: String
    /// « TPG », « CFF », « PAG ».
    public let shortName: String
    /// Le nom qu'OJP 1.0 donnait, et qui indexe `LineColors`.
    public let colorName: String
    /// La référence d'OJP 2.0 (`siri:OperatorRef`) : « ojp:881 ».
    public let ojpRef: String

    public init(id: String, name: String, shortName: String, colorName: String, ojpRef: String) {
        self.id = id
        self.name = name
        self.shortName = shortName
        self.colorName = colorName
        self.ojpRef = ojpRef
    }
}

public struct TransitLine: Codable, Hashable, Identifiable {
    /// Identifiant suisse de la ligne (SLNID). Pas encore repris dans les horaires : on
    /// retrouve la ligne dans les départs par son numéro.
    public let slnid: String
    /// « 12 », « E », « 301 », « S5 » : le numéro affiché sur les véhicules.
    public let number: String
    /// La catégorie d'offre : `T` tram, `B` bus, `RUB` bus à la demande, `S` RER… (voir `Kind`).
    public let category: String
    /// Les principaux arrêts, séparés par « - » : « Lancy-Bachet gare - … - Thônex Moillesulaz ».
    public let description: String
    /// Le transporteur, par son identifiant (`TransitOperator.id`).
    public let `operator`: String

    public var id: String { slnid }

    public init(slnid: String, number: String, category: String, description: String, operator: String) {
        self.slnid = slnid
        self.number = number
        self.category = category
        self.description = description
        self.operator = `operator`
    }

    /// Le genre de ligne, pour grouper la liste.
    public enum Kind: Int, CaseIterable, Comparable {
        case tram, metro, bus, nightBus, onDemand, train, boat, cableway

        public static func < (lhs: Kind, rhs: Kind) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    public var kind: Kind {
        switch category {
        case "T": .tram
        case "M": .metro
        case "BN": .nightBus
        case "RUB": .onDemand
        case "S", "SN", "R", "RE", "IR", "IRE", "IC", "ICE", "EC", "TGV", "EN", "RJ", "TER", "PE", "RB", "EXT", "ES": .train
        case "BAT", "FAE": .boat
        case "FUN", "PB", "GB", "SL", "ASC": .cableway
        default: .bus
        }
    }

    public var isTram: Bool { kind == .tram }
    public var isOnDemand: Bool { kind == .onDemand }

    /// Le transporteur, s'il est dans le registre embarqué.
    public var transitOperator: TransitOperator? { LineDirectory.operator(id: `operator`) }

    /// Le nom sous lequel `LineColors` connaît le transporteur.
    public var operatorColorName: String { transitOperator?.colorName ?? "" }

    /// Les arrêts principaux du parcours, dans l'ordre. Une ligne à la demande décrit une zone :
    /// son texte n'a pas d'arrêts.
    public var mainStops: [String] {
        guard !isOnDemand else { return [] }
        return description.components(separatedBy: " - ").map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// Le premier et le dernier arrêt principal.
    public var termini: (from: String, to: String)? {
        guard let first = mainStops.first, let last = mainStops.last, first != last else { return nil }
        return (first, last)
    }
}

public enum LineDirectory {
    /// Les tpg, transporteur proposé par défaut.
    public static let tpgID = "100680"

    private struct Directory: Decodable {
        var operators: [TransitOperator]
        var lines: [TransitLine]
    }

    private static let directory: Directory = {
        guard let url = Bundle(for: StopStore.self).url(forResource: "Lines", withExtension: "json") else {
            Log.data.error("Lines.json introuvable dans le bundle")
            return Directory(operators: [], lines: [])
        }
        do {
            var directory = try JSONDecoder().decode(Directory.self, from: Data(contentsOf: url))
            directory.lines.sort { $0.number.localizedStandardCompare($1.number) == .orderedAscending }
            return directory
        } catch {
            Log.data.error("Lecture de Lines.json impossible : \(error.localizedDescription)")
            return Directory(operators: [], lines: [])
        }
    }()

    /// Toutes les lignes de Suisse, dans l'ordre des numéros (1, 2, … 10, … A1, E).
    public static var lines: [TransitLine] { directory.lines }

    /// Les transporteurs qui ont au moins une ligne, par nom.
    public static var operators: [TransitOperator] { directory.operators }

    private static let operatorsByID = Dictionary(directory.operators.map { ($0.id, $0) },
                                                  uniquingKeysWith: { first, _ in first })
    private static let operatorsByOJPRef = Dictionary(directory.operators.map { ($0.ojpRef, $0) },
                                                      uniquingKeysWith: { first, _ in first })
    private static let lineCounts = Dictionary(directory.lines.map { ($0.operator, 1) }, uniquingKeysWith: +)

    public static func `operator`(id: String) -> TransitOperator? {
        operatorsByID[id]
    }

    /// Le transporteur désigné par OJP 2.0 (« ojp:881 »).
    public static func `operator`(ojpRef: String) -> TransitOperator? {
        operatorsByOJPRef[ojpRef]
    }

    /// Les lignes des transporteurs choisis, dans l'ordre des numéros.
    public static func lines(of operatorIDs: Set<String>) -> [TransitLine] {
        lines.filter { operatorIDs.contains($0.operator) }
    }

    public static func lineCount(of operatorID: String) -> Int {
        lineCounts[operatorID] ?? 0
    }

    /// Les lignes dont le numéro est `query` (en tête), puis celles qui commencent par lui.
    /// Seulement pour un texte court, qui ressemble à un numéro : « 1 », « 12 », « E ».
    public static func search(_ query: String, in lines: [TransitLine] = lines, limit: Int = 5) -> [TransitLine] {
        let wanted = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !wanted.isEmpty, wanted.count <= 3, !wanted.contains(" ") else { return [] }
        let exact = lines.filter { $0.number.lowercased() == wanted }
        let prefix = lines.filter { $0.number.lowercased() != wanted && $0.number.lowercased().hasPrefix(wanted) }
        return Array((exact + prefix).prefix(limit))
    }
}

extension StopStore {
    /// L'arrêt dont le nom est `name` à la ponctuation près : le registre des lignes écrit
    /// « Thônex Moillesulaz » là où la base des arrêts écrit « Thônex, Moillesulaz ». Un arrêt
    /// genevois passe devant un homonyme ailleurs.
    public func stop(named name: String) -> Stop? {
        let wanted = name.normalized().lowercased()
        guard !wanted.isEmpty else { return nil }
        let matches = searchIndex.filter { $0.key == wanted }.map(\.stop)
        return matches.first { $0.canton == "Genève" } ?? matches.first
    }
}
