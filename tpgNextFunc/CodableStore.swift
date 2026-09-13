//
//  CodableStore.swift
//  tpgNextFunc
//

import Foundation

/// Une valeur `Codable` enregistrée en JSON dans des préférences.
///
/// Les itinéraires enregistrés, les trajets réguliers, les recherches récentes et les
/// favoris de la montre répétaient chacun le même couple lecture / écriture.
public struct CodableStore<Value: Codable> {
    public let key: String
    public let defaults: UserDefaults

    public init(key: String, defaults: UserDefaults = .standard) {
        self.key = key
        self.defaults = defaults
    }

    /// `nil` si rien n'est enregistré, ou si l'enregistrement est illisible.
    public func load() -> Value? {
        guard let data = defaults.data(forKey: key) else { return nil }
        do {
            return try JSONDecoder().decode(Value.self, from: data)
        } catch {
            Log.data.error("Lecture de « \(self.key) » impossible : \(error.localizedDescription)")
            return nil
        }
    }

    public func save(_ value: Value) {
        do {
            defaults.set(try JSONEncoder().encode(value), forKey: key)
        } catch {
            Log.data.error("Enregistrement de « \(self.key) » impossible : \(error.localizedDescription)")
        }
    }
}
