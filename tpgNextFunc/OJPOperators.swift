//
//  OJPOperators.swift
//  tpgNextFunc
//
//  OJP 2.0 ne donne que la référence d'un exploitant (`siri:OperatorRef`), alors que
//  `LineColors` est indexé par son nom complet, celui qu'OJP 1.0 envoyait.
//

import Foundation

enum OJPOperators {
    /// Relevé le 17.09.2026 en croisant, course par course, les réponses OJP 1.0 (nom) et 2.0
    /// (référence) de gares et d'arrêts de la région. Introuvables alors : TAC (Annemasse), LEB,
    /// CarPostal ; leurs lignes prennent la couleur par défaut.
    private static let names: [String: String] = [
        "ojp:881": "Transports Publics Genevois",
        "ojp:11": "Schweizerische Bundesbahnen SBB",
        "ojp:151": "Transports Publics de la Région Lausannoise sa",
        "ojp:184": "CGN SA",
        "ojp:199": "Mouettes genevoises SA",
        "ojp:23": "Transports Publics du Chablais",
        "ojp:818": "Transports Publics du Chablais (Bus)",
        "ojp:29": "Transports de la région Morges-Bière-Cossonay",
        "ojp:764": "Automobiles MBC",
        "ojp:42": "Montreux-Vevey-Riviera (cev)",
        "ojp:64": "Montreux-Oberland Bernois",
        "ojp:66": "Compagnie du chemin de fer Nyon - St-Cergue - Morez",
        "ojp:738": "Transports Publics de la Région Nyonnaise",
        "ojp:741": "Bus Nyon-Prangins",
        "ojp:74": "Regionalps",
        "ojp:876": "Transports publics Vevey-Montreux-Chillon-Villeneuve",
        "ojp:97": "Transports Vallée de Joux-Yverdon-Ste-Croix",
        "ojp:839": "Zugerland Verkehrsbetriebe",
    ]

    /// Nom complet de l'exploitant, `nil` s'il n'est pas connu.
    static func name(forRef ref: String) -> String? {
        names[ref]
    }
}
