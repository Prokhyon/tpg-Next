//
//  SelectStopIntent.swift
//  tpg Next Widget
//
//  Created by Loris Thomas on 26.08.2026.
//

import AppIntents
import tpgNextFunc

/// L'arrêt choisi dans la configuration du widget.
///
/// L'identifiant est le sloid, comme partout ailleurs dans l'app, sauf pour
/// l'entrée « Le plus proche » qui déclenche le mode automatique.
struct StopEntity: AppEntity {
    let id: String
    let name: String
    let meansOfTransport: String

    static let automaticIdentifier = "auto"
    static let automatic = StopEntity(id: automaticIdentifier, name: "Le plus proche", meansOfTransport: "")

    var isAutomatic: Bool { id == StopEntity.automaticIdentifier }

    /// L'arrêt correspondant, `nil` en mode automatique. Sert de repli quand
    /// l'index ne résout pas le sloid : le type de transport est conservé pour
    /// que l'en-tête garde son icône train ou bateau.
    var stop: Stop? {
        guard !isAutomatic else { return nil }
        return Stop(name: name,
                    sloid: id,
                    codedidoc: "",
                    country: "",
                    canton: "",
                    meansOfTransport: meansOfTransport,
                    wgs84Coordinates: Coordinates(lon: 0, lat: 0))
    }

    init(id: String, name: String, meansOfTransport: String) {
        self.id = id
        self.name = name
        self.meansOfTransport = meansOfTransport
    }

    init(stop: Stop) {
        self.init(id: sloidHarmonizer(code: stop.sloid), name: stop.name, meansOfTransport: stop.meansOfTransport)
    }

    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Arrêt" }
    static var defaultQuery = StopEntityQuery()

    var displayRepresentation: DisplayRepresentation {
        if isAutomatic {
            return DisplayRepresentation(title: "Le plus proche",
                                         subtitle: "Suit votre position, en privilégiant vos favoris")
        }
        let split = splitString(name, separator: ",")
        return split.1.isEmpty
            ? DisplayRepresentation(title: "\(split.0)")
            : DisplayRepresentation(title: "\(split.1)", subtitle: "\(split.0)")
    }
}

/// Alimente le sélecteur d'arrêt de la configuration du widget.
///
/// Les suggestions sont les favoris — c'est ce qu'on veut voir en premier — et la
/// recherche libre passe par l'index binaire, qui couvre toute la base sans avoir
/// à charger les 6 Mo de JSON dans l'extension.
struct StopEntityQuery: EntityStringQuery {
    func entities(for identifiers: [StopEntity.ID]) async throws -> [StopEntity] {
        let reader = StopIndexReader()
        let favorites = FavoritesStorage.load()

        return identifiers.compactMap { identifier in
            if identifier == StopEntity.automaticIdentifier { return .automatic }
            if let stop = reader?.stop(sloid: identifier) { return StopEntity(stop: stop) }
            // L'index n'est pas encore écrit : l'instantané du favori suffit à réafficher le nom.
            if let favorite = favorites.first(where: { $0.sloid == identifier }) {
                return StopEntity(stop: favorite.fallbackStop)
            }
            return nil
        }
    }

    func entities(matching string: String) async throws -> [StopEntity] {
        guard let reader = StopIndexReader() else { return [] }
        return reader.search(string, limit: 20).map(StopEntity.init(stop:))
    }

    func suggestedEntities() async throws -> [StopEntity] {
        [.automatic] + FavoritesStorage.load().prefix(8).map { StopEntity(stop: $0.fallbackStop) }
    }

    func defaultResult() -> StopEntity? { .automatic }
}

struct SelectStopIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Départs" }
    static var description: IntentDescription {
        IntentDescription("Les prochains départs d'un arrêt, ou de l'arrêt le plus proche de vous.")
    }

    @Parameter(title: "Arrêt")
    var stop: StopEntity?

    /// L'arrêt demandé, en repliant l'absence de choix sur le mode automatique.
    var selection: StopEntity { stop ?? .automatic }
}
