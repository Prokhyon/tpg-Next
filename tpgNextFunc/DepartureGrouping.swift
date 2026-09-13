//
//  DepartureGrouping.swift
//  tpgNextFunc
//
//  Regroupement des départs par ligne, commun à l'iPhone et à la montre.
//

import Foundation

extension Array where Element == StopEvent {
    /// Les départs regroupés par ligne et destination, sous la clé « ligne;destination »
    /// que les vues redécoupent pour l'affichage.
    public func groupedByLineAndDestination() -> [String: [StopEvent]] {
        Dictionary(grouping: self) { "\($0.lineName);\($0.destination)" }
    }
}

/// Ordre des groupes « ligne;destination » : la ligne d'abord, numériquement quand les deux
/// en sont (« 2 » avant « 12 »), puis la destination.
public func lineGroupPrecedes(_ lhs: String, _ rhs: String) -> Bool {
    let lhsComponents = lhs.split(separator: ";")
    let rhsComponents = rhs.split(separator: ";")

    let lhsLine = lhsComponents.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let lhsDestination = lhsComponents.last?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let rhsLine = rhsComponents.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let rhsDestination = rhsComponents.last?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

    guard lhsLine == rhsLine else {
        if let lhsNumber = Int(lhsLine), let rhsNumber = Int(rhsLine) {
            return lhsNumber < rhsNumber
        }
        return lhsLine < rhsLine
    }
    return lhsDestination < rhsDestination
}
