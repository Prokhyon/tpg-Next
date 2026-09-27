//
//  CloudSync.swift
//  tpgNextFunc
//
//  Les favoris et les itinéraires partagés entre les appareils via le stockage clé-valeur d'iCloud.
//

import Foundation

/// L'état d'une collection tel que partagé par iCloud, et gardé en miroir sur l'appareil.
///
/// On ne synchronise pas un tableau entier : le dernier appareil à écrire effacerait les
/// changements faits entre-temps ailleurs (la synchro clé-valeur peut prendre des minutes,
/// ou attendre qu'un appareil hors ligne revienne). Chaque élément porte donc sa date de
/// modification, chaque suppression laisse une trace, et deux états se fusionnent élément
/// par élément : le plus récent gagne.
public struct CloudSnapshot<Item: Codable>: Codable {
    public struct Entry: Codable {
        public var value: Item
        public var modified: Date
    }

    public var entries: [String: Entry] = [:]
    /// Les éléments supprimés, avec la date de suppression.
    public var removed: [String: Date] = [:]
    /// L'ordre choisi par l'utilisateur. Il a sa propre date : réordonner ne touche pas aux éléments.
    public var order: [String] = []
    public var orderModified: Date = .distantPast

    /// Au-delà, une trace de suppression est oubliée : un appareil resté hors ligne plus
    /// longtemps pourrait faire réapparaître l'élément.
    static var removalMemory: TimeInterval { 90 * 86_400 }

    public init() {}

    /// Les éléments dans l'ordre choisi. Ceux que l'ordre ne connaît pas encore (ajoutés
    /// ailleurs pendant qu'ici on réordonnait) suivent, du plus ancien au plus récent.
    public var items: [Item] {
        var seen = Set<String>()
        let ordered = order.filter { entries[$0] != nil && seen.insert($0).inserted }
        let others = entries
            .filter { !seen.contains($0.key) }
            .sorted { ($0.value.modified, $0.key) < ($1.value.modified, $1.key) }
            .map(\.key)
        return (ordered + others).compactMap { entries[$0]?.value }
    }

    /// Enregistre l'état local. Seuls les éléments nouveaux ou changés au sens de `isSame`
    /// prennent la date `now` : un élément identique garde la sienne.
    /// - Returns: `true` si quelque chose a changé.
    @discardableResult
    public mutating func record(_ items: [Item], now: Date,
                                id: (Item) -> String, isSame: (Item, Item) -> Bool) -> Bool {
        var changed = false
        let ids = items.map(id)
        for (itemID, item) in zip(ids, items) {
            if let entry = entries[itemID], isSame(entry.value, item) {
                entries[itemID]?.value = item
            } else {
                entries[itemID] = Entry(value: item, modified: now)
                removed[itemID] = nil
                changed = true
            }
        }
        for itemID in Set(entries.keys).subtracting(ids) {
            entries[itemID] = nil
            removed[itemID] = now
            changed = true
        }
        if order != ids {
            order = ids
            orderModified = now
            changed = true
        }
        return changed
    }

    /// La fusion de deux états : pour chaque élément la version la plus récente, sauf s'il a
    /// été supprimé après ; pour l'ordre, le plus récent.
    public func merged(with other: CloudSnapshot, now: Date = Date()) -> CloudSnapshot {
        var result = CloudSnapshot()
        let horizon = now.addingTimeInterval(-Self.removalMemory)
        result.removed = removed.merging(other.removed, uniquingKeysWith: max).filter { $0.value > horizon }
        for itemID in Set(entries.keys).union(other.entries.keys) {
            let candidates = [entries[itemID], other.entries[itemID]].compactMap { $0 }
            // À égalité, la version locale : les deux appareils gardent chacun la leur, sans dommage.
            guard let latest = candidates.max(by: { $0.modified < $1.modified }) else { continue }
            if let removedAt = result.removed[itemID], removedAt >= latest.modified { continue }
            result.entries[itemID] = latest
            // Rajouté depuis : la trace ne sert plus.
            result.removed[itemID] = nil
        }
        (result.order, result.orderModified) = other.orderModified > orderModified
            ? (other.order, other.orderModified)
            : (order, orderModified)
        return result
    }
}

/// Une collection synchronisée avec les autres appareils de l'utilisateur.
///
/// Le modèle garde son propre enregistrement local ; il appelle `record(_:)` après chaque
/// modification, et reçoit par `start(current:apply:)` la liste fusionnée quand un autre
/// appareil l'a changée. Ne fait rien tant que `start` n'a pas été appelé : le widget et
/// la montre n'y touchent pas.
public final class CloudCollection<Item: Codable> {
    public let key: String
    private let id: (Item) -> String
    private let isSame: (Item, Item) -> Bool
    /// Le dernier état fusionné, pour savoir au prochain lancement ce qui a changé ici entre-temps.
    private let mirror: CodableStore<CloudSnapshot<Item>>
    private var snapshot = CloudSnapshot<Item>()
    /// La liste telle que le modèle la connaît.
    private var local: [Item] = []
    private var apply: (([Item]) -> Void)?
    private var observer: NSObjectProtocol?

    private var cloud: NSUbiquitousKeyValueStore { .default }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        // Des clés triées : deux états identiques donnent les mêmes octets, et on n'écrit pas pour rien.
        encoder.outputFormatting = .sortedKeys
        return encoder
    }

    /// - Parameter isSame: quand deux versions d'un élément sont considérées identiques.
    ///   Les favoris ignorent leur instantané : chaque appareil le rafraîchit depuis sa propre base.
    public init(key: String, id: @escaping (Item) -> String,
                isSame: @escaping (Item, Item) -> Bool) {
        self.key = key
        self.id = id
        self.isSame = isSame
        self.mirror = CodableStore(key: "\(key).mirror")
    }

    /// Branche la synchro. `apply` est appelé sur le fil principal, avec la liste fusionnée,
    /// chaque fois qu'elle diffère de celle du modèle.
    public func start(current: [Item], apply: @escaping ([Item]) -> Void) {
        guard self.apply == nil else { return }
        self.apply = apply
        local = current
        if let saved = mirror.load() {
            snapshot = saved
            // Modifié pendant que la synchro ne tournait pas (tâche de fond, montre).
            snapshot.record(current, now: Date(), id: id, isSame: isSame)
        } else {
            // Première synchro de cet appareil : ses éléments rejoignent ceux d'iCloud sans
            // rien écraser, et une suppression faite ailleurs l'emporte.
            snapshot.record(current, now: .distantPast, id: id, isSame: isSame)
        }
        observer = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: cloud, queue: .main
        ) { [weak self] notification in
            self?.cloudDidChange(notification)
        }
        cloud.synchronize()
        sync()
    }

    /// À appeler après chaque modification locale.
    public func record(_ items: [Item]) {
        guard apply != nil else { return }
        local = items
        guard snapshot.record(items, now: Date(), id: id, isSame: isSame) else { return }
        sync()
    }

    private func cloudDidChange(_ notification: Notification) {
        let reason = notification.userInfo?[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int
        switch reason {
        case NSUbiquitousKeyValueStoreQuotaViolationChange:
            Log.sync.error("iCloud : quota du stockage clé-valeur dépassé")
            return
        case NSUbiquitousKeyValueStoreAccountChange:
            // Les données locales rejoignent le nouveau compte plutôt que de disparaître.
            Log.sync.info("iCloud : changement de compte")
        default:
            let keys = notification.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] ?? []
            guard keys.contains(key) else { return }
        }
        sync()
    }

    /// Fusionne avec iCloud, y écrit le résultat s'il diffère, et le rend au modèle s'il a changé.
    private func sync() {
        let remoteData = cloud.data(forKey: key)
        var merged = snapshot
        if let remoteData {
            do {
                merged = snapshot.merged(with: try JSONDecoder().decode(CloudSnapshot<Item>.self, from: remoteData))
            } catch {
                // Une version future de l'app a pu changer le format : on ne l'écrase pas.
                Log.sync.error("iCloud : « \(self.key) » illisible : \(error.localizedDescription)")
                return
            }
        }
        snapshot = merged
        mirror.save(merged)

        do {
            let data = try Self.encoder.encode(merged)
            if data != remoteData {
                cloud.set(data, forKey: key)
                Log.sync.debug("iCloud : « \(self.key) » envoyé (\(data.count) octets)")
            }
        } catch {
            Log.sync.error("iCloud : envoi de « \(self.key) » impossible : \(error.localizedDescription)")
        }

        let items = resolved(merged.items)
        guard !matchesLocal(items) else { return }
        local = items
        apply?(items)
    }

    /// Garde la version locale des éléments identiques au sens de `isSame`.
    private func resolved(_ items: [Item]) -> [Item] {
        let localByID = Dictionary(local.map { (id($0), $0) }, uniquingKeysWith: { first, _ in first })
        return items.map { item in
            guard let mine = localByID[id(item)], isSame(mine, item) else { return item }
            return mine
        }
    }

    private func matchesLocal(_ items: [Item]) -> Bool {
        items.count == local.count && zip(items, local).allSatisfy { id($0) == id($1) && isSame($0, $1) }
    }
}

extension CloudCollection where Item: Equatable {
    public convenience init(key: String, id: @escaping (Item) -> String) {
        self.init(key: key, id: id, isSame: ==)
    }
}
