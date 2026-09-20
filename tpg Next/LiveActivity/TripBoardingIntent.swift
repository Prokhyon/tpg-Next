//
//  TripBoardingIntent.swift
//  tpg Next
//
//  Répondre depuis l'écran verrouillé : « je suis monté », « je l'ai manqué ».
//  Compilé aussi pour le widget, qui pose les boutons (exception dans le projet).
//

import AppIntents
import Foundation

/// Le bouton d'une activité en direct. `LiveActivityIntent` s'exécute dans le processus de
/// l'app, en arrière-plan : le widget ne fait que le déclarer.
///
/// La réponse passe par une notification plutôt que par un appel direct : le suivi des trajets
/// n'existe que dans l'app, et ce fichier doit aussi compiler dans le widget.
struct TripBoardingIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Répondre au sujet d'une correspondance"
    static var isDiscoverable: Bool = false

    @Parameter(title: "Trajet suivi")
    var key: String
    /// Vrai : le voyageur est monté dans le véhicule.
    @Parameter(title: "Monté")
    var aboard: Bool

    init() {}

    init(key: String, aboard: Bool) {
        self.key = key
        self.aboard = aboard
    }

    func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(name: .tripBoardingAnswer, object: nil,
                                        userInfo: [TripBoardingAnswer.key: key,
                                                   TripBoardingAnswer.aboard: aboard])
        return .result()
    }
}

extension Notification.Name {
    /// Le voyageur a répondu à la question d'une correspondance serrée.
    static let tripBoardingAnswer = Notification.Name("tpgNext.tripBoardingAnswer")
}

enum TripBoardingAnswer {
    static let key = "key"
    static let aboard = "aboard"
}
