//
//  OJPUsage.swift
//  tpgNextFunc
//
//  L'usage des clés OJP vu depuis cet appareil : le quota que l'API renvoie avec chaque
//  réponse, les clés mises en pause et les incidents des derniers jours.
//
//  Le gestionnaire de l'API (Tyk) compte par clé, tous appareils confondus : 20 000 requêtes
//  par jour et 50 par minute. `X-Quota-Remaining` dit donc, à chaque réponse, ce qui reste à
//  tous les utilisateurs de l'app sur cette clé ; un seul appareil suffit à voir venir la limite.
//
//  La minute est glissante (vérifié le 11.10.2026) : `X-Ratelimit-Remaining` compte les requêtes
//  reçues par la clé dans les 60 secondes avant la réponse, et `X-Ratelimit-Reset` vaut toujours
//  l'instant de la réponse. Le chiffre ne vaut donc que pour ce moment-là.
//

import Foundation

/// Un signal qui mérite d'être remonté au développeur (`OJPUsage.alertHandler`).
public struct OJPAlert: Sendable, Equatable {
    public enum Kind: String, Sendable {
        /// Le quota du jour d'une clé passe sous un palier (50 %, 20 %, 5 %).
        case quotaLow
        /// Une clé a épuisé son quota du jour.
        case quotaExceeded
        /// Plus de 50 requêtes en une minute sur une clé.
        case rateLimited
        /// Une clé est refusée : invalide, révoquée ou expirée.
        case keyRejected
        /// L'API refuse la requête elle-même (400) : son format a peut-être changé.
        case badRequest
        /// Le service est en panne (5xx).
        case server
        /// Une réponse reçue mais illisible (pas du XML OJP).
        case unreadable
    }

    public let kind: Kind
    /// Le numéro de la clé (1, 2, 3…), jamais la clé elle-même.
    public let key: Int?
    public let detail: String
}

public final class OJPUsage: @unchecked Sendable {
    public static let shared = OJPUsage()

    /// Reçoit les alertes, au plus une par type, clé et heure sur cet appareil. Par défaut,
    /// elles ne vont qu'au journal (catégorie `network`, visible dans Console.app).
    public static var alertHandler: (@Sendable (OJPAlert) -> Void)?

    /// L'état d'une clé, tel que la dernière réponse l'a décrit.
    public struct KeyState: Codable, Sendable, Equatable {
        public var quotaLimit: Int?
        public var quotaRemaining: Int?
        /// Le quota repart à zéro 24 h après la première requête de la période, pas à minuit.
        public var quotaReset: Date?
        public var rateLimit: Int?
        public var rateRemaining: Int?
        /// Les requêtes que ce processus a envoyées à la clé dans la minute avant la lecture :
        /// le reste de `rateUsed` vient d'autres appareils.
        public var rateOwn: Int?
        public var updated: Date?
        /// La clé n'est plus proposée avant cette heure (quota épuisé, limite par minute, refus).
        public var pausedUntil: Date?
        public var lastFailure: String?
        /// Le plus bas palier déjà signalé pour la période `quotaReset`.
        var alertedLevel: Double?

        public init() {}

        public var quotaUsed: Int? {
            guard let quotaLimit, let quotaRemaining else { return nil }
            return quotaLimit - quotaRemaining
        }

        /// Les requêtes reçues par la clé, tous appareils confondus, dans la minute avant la lecture.
        public var rateUsed: Int? {
            guard let rateLimit, let rateRemaining else { return nil }
            return max(rateLimit - rateRemaining, 0)
        }

        /// La période du quota n'est pas finie : `quotaRemaining` vaut encore. Une fois `quotaReset`
        /// passé, le quota est reparti de zéro et les chiffres gardés sont ceux d'avant.
        public func isQuotaCurrent(now: Date = Date()) -> Bool {
            guard let quotaReset else { return true }
            return quotaReset > now
        }

        /// Lue il y a moins d'une minute : `rateUsed` décrit encore la minute en cours, au moins
        /// en partie. Au-delà, ce n'est plus qu'un relevé passé.
        public func isRateCurrent(now: Date = Date()) -> Bool {
            guard let updated else { return false }
            return now.timeIntervalSince(updated) < OJPUsage.rateWindow
        }
    }

    /// Un incident, pour la liste de la page de diagnostic.
    public struct Incident: Codable, Sendable, Identifiable, Equatable {
        public var id: Date { date }
        public let date: Date
        public let code: String
        public let key: Int?
        public let endpoint: String

        public init(date: Date, code: String, key: Int?, endpoint: String) {
            self.date = date
            self.code = code
            self.key = key
            self.endpoint = endpoint
        }
    }

    /// Ce qu'un processus (app, widget) a vu. Chacun écrit sous sa propre clé du groupe
    /// d'app : deux processus qui s'écraseraient perdraient leurs compteurs.
    public struct Snapshot: Codable, Sendable, Equatable {
        public var keys: [Int: KeyState] = [:]
        public var incidents: [Incident] = []
        /// Par jour (« 2026-10-01 ») : requêtes envoyées, puis échecs par code.
        public var requestsByDay: [String: Int] = [:]
        public var failuresByDay: [String: [String: Int]] = [:]
        /// Le plus de requêtes envoyées en une minute, par jour : l'app seule s'approche-t-elle
        /// des 50 par minute d'une clé ?
        public var peakPerMinuteByDay: [String: Int] = [:]

        public init() {}
    }

    private static let storagePrefix = "ojpUsage."
    /// La fenêtre glissante de la limite par minute.
    public static let rateWindow: TimeInterval = 60
    private static let quotaLevels: [Double] = [0.5, 0.2, 0.05]
    private static let maxIncidents = 40
    private static let keptDays = 14

    private let lock = NSLock()
    private var snapshot: Snapshot
    private var recentRequests: [Date] = []
    /// Les envois de la dernière minute, par clé : la part de cet appareil dans `rateUsed`.
    private var recentRequestsByKey: [Int: [Date]] = [:]
    private var lastAlerts: [String: Date] = [:]
    private let storageKey: String

    private init() {
        storageKey = Self.storagePrefix + (Bundle.main.bundleIdentifier ?? "app")
        if let data = SharedStorage.defaults.data(forKey: storageKey),
           let stored = try? JSONDecoder().decode(Snapshot.self, from: data) {
            snapshot = stored
        } else {
            snapshot = Snapshot()
        }
    }

    // MARK: Lecture

    /// Le nombre de clés embarquées.
    public static var keyCount: Int { Secrets.ojpAPIKeys.count }

    /// Ce que ce processus a vu.
    public var current: Snapshot {
        lock.withLock { snapshot }
    }

    /// Ce que l'app et le widget ont vu, réunis : pour chaque clé, l'état le plus récent ;
    /// les compteurs s'additionnent.
    public static func merged() -> Snapshot {
        let decoder = JSONDecoder()
        let stored = SharedStorage.defaults.dictionaryRepresentation()
            .filter { $0.key.hasPrefix(storagePrefix) }
            .compactMap { ($0.value as? Data).flatMap { try? decoder.decode(Snapshot.self, from: $0) } }
        var result = Snapshot()
        for part in stored + [shared.current] {
            for (key, state) in part.keys where (state.updated ?? .distantPast) > (result.keys[key]?.updated ?? .distantPast) {
                result.keys[key] = state
            }
            result.incidents += part.incidents
            for (day, count) in part.requestsByDay {
                result.requestsByDay[day, default: 0] += count
            }
            for (day, codes) in part.failuresByDay {
                for (code, count) in codes {
                    result.failuresByDay[day, default: [:]][code, default: 0] += count
                }
            }
            for (day, peak) in part.peakPerMinuteByDay {
                result.peakPerMinuteByDay[day] = max(result.peakPerMinuteByDay[day] ?? 0, peak)
            }
        }
        // `shared.current` est aussi dans le groupe d'app : sans doublons.
        var seen = Set<Incident>()
        result.incidents = result.incidents.filter { seen.insert($0).inserted }
            .sorted { $0.date > $1.date }
        return result
    }

    // MARK: Choix de la clé

    /// Une clé au hasard parmi celles qui ne sont pas en pause et pas encore essayées ; si toutes
    /// sont en pause, celle qui en sort la première. `nil` quand toutes ont été essayées.
    func pickKey(excluding tried: Set<Int>, now: Date = Date()) -> (number: Int, key: String)? {
        let keys = Secrets.ojpAPIKeys
        let candidates = keys.indices.map { $0 + 1 }.filter { !tried.contains($0) }
        guard !candidates.isEmpty else { return nil }
        let paused = lock.withLock { snapshot.keys.mapValues { $0.pausedUntil } }
        let available = candidates.filter { (paused[$0].flatMap { $0 } ?? .distantPast) <= now }
        let number = available.randomElement()
            ?? candidates.min { (paused[$0].flatMap { $0 } ?? .distantPast) < (paused[$1].flatMap { $0 } ?? .distantPast) }!
        return (number, keys[number - 1])
    }

    // MARK: Enregistrement

    /// Une réponse est arrivée (même en erreur) : les en-têtes de quota de la clé.
    func record(response: HTTPURLResponse, key: Int, now: Date = Date()) {
        func int(_ name: String) -> Int? {
            (response.value(forHTTPHeaderField: name)).flatMap { Int($0.trimmingCharacters(in: .whitespaces)) }
        }
        func date(_ name: String) -> Date? {
            int(name).flatMap { $0 > 0 ? Date(timeIntervalSince1970: TimeInterval($0)) : nil }
        }
        var alert: OJPAlert?
        update(now: now) { snapshot in
            var state = snapshot.keys[key] ?? KeyState()
            if let limit = int("X-Quota-Limit"), let remaining = int("X-Quota-Remaining") {
                let reset = date("X-Quota-Reset")
                if reset != state.quotaReset { state.alertedLevel = nil }
                state.quotaLimit = limit
                state.quotaRemaining = remaining
                state.quotaReset = reset
                if limit > 0 {
                    let share = Double(remaining) / Double(limit)
                    // Le plus bas palier franchi, s'il ne l'a pas déjà été pendant cette période.
                    if let level = Self.quotaLevels.last(where: { share <= $0 }), level < (state.alertedLevel ?? 1) {
                        state.alertedLevel = level
                        alert = OJPAlert(kind: .quotaLow, key: key,
                                         detail: "\(remaining)/\(limit) restantes (palier \(Int(level * 100)) %)")
                    }
                }
            }
            if let limit = int("X-Ratelimit-Limit") { state.rateLimit = limit }
            if let remaining = int("X-Ratelimit-Remaining") {
                state.rateRemaining = remaining
                state.rateOwn = (recentRequestsByKey[key] ?? []).filter { now.timeIntervalSince($0) < Self.rateWindow }.count
            }
            state.updated = now
            snapshot.keys[key] = state
        }
        if let alert { send(alert) }
    }

    /// Une requête part avec la clé `key` : les compteurs du jour et le pic par minute.
    func recordRequest(key: Int, now: Date = Date()) {
        update(now: now) { snapshot in
            let day = Self.day(now)
            snapshot.requestsByDay[day, default: 0] += 1
            recentRequests = recentRequests.filter { now.timeIntervalSince($0) < Self.rateWindow } + [now]
            snapshot.peakPerMinuteByDay[day] = max(snapshot.peakPerMinuteByDay[day] ?? 0, recentRequests.count)
            recentRequestsByKey[key] = (recentRequestsByKey[key] ?? []).filter { now.timeIntervalSince($0) < Self.rateWindow } + [now]
        }
    }

    /// Un échec : compté, ajouté aux incidents, et la clé mise en pause si c'est elle.
    func record(failure: OJPClient.Failure, key: Int?, endpoint: String, response: HTTPURLResponse? = nil,
                now: Date = Date()) {
        guard failure.isRecorded else { return }
        update(now: now) { snapshot in
            let day = Self.day(now)
            snapshot.failuresByDay[day, default: [:]][failure.code, default: 0] += 1
            snapshot.incidents.insert(Incident(date: now, code: failure.code, key: key, endpoint: endpoint), at: 0)
            if snapshot.incidents.count > Self.maxIncidents {
                snapshot.incidents.removeLast(snapshot.incidents.count - Self.maxIncidents)
            }
            if let key {
                var state = snapshot.keys[key] ?? KeyState()
                state.lastFailure = failure.code
                if let pause = Self.pause(after: failure, response: response, now: now) {
                    state.pausedUntil = pause
                }
                snapshot.keys[key] = state
            }
        }
        if let kind = failure.alertKind {
            send(OJPAlert(kind: kind, key: key, detail: "\(endpoint) : \(failure.code)"))
        }
    }

    /// Une réponse reçue que les parseurs n'ont pas su lire.
    public func recordUnreadable(_ context: String, now: Date = Date()) {
        record(failure: .unreadable, key: nil, endpoint: context, now: now)
    }

    /// Jusqu'à quand ne plus proposer une clé.
    private static func pause(after failure: OJPClient.Failure, response: HTTPURLResponse?, now: Date) -> Date? {
        func header(_ name: String) -> Date? {
            response?.value(forHTTPHeaderField: name).flatMap { TimeInterval($0) }
                .map { Date(timeIntervalSince1970: $0) }
                .flatMap { $0 > now ? $0 : nil }
        }
        switch failure {
        case .rateLimited:
            // La fenêtre d'une minute ; sans en-tête, la minute entière.
            return min(header("X-Ratelimit-Reset") ?? now.addingTimeInterval(60), now.addingTimeInterval(60))
        case .quotaExceeded:
            return header("X-Quota-Reset") ?? now.addingTimeInterval(3600)
        case .keyRejected:
            return now.addingTimeInterval(3600)
        default:
            return nil
        }
    }

    // MARK: Interne

    private func update(now: Date, _ change: (inout Snapshot) -> Void) {
        let data: Data? = lock.withLock {
            change(&snapshot)
            prune(now: now)
            return try? JSONEncoder().encode(snapshot)
        }
        if let data {
            SharedStorage.defaults.set(data, forKey: storageKey)
        }
    }

    /// Garde deux semaines de compteurs.
    private func prune(now: Date) {
        let oldest = Self.day(now.addingTimeInterval(-Double(Self.keptDays) * 86_400))
        snapshot.requestsByDay = snapshot.requestsByDay.filter { $0.key >= oldest }
        snapshot.failuresByDay = snapshot.failuresByDay.filter { $0.key >= oldest }
        snapshot.peakPerMinuteByDay = snapshot.peakPerMinuteByDay.filter { $0.key >= oldest }
    }

    /// Au plus une alerte du même type et de la même clé par heure : un quota épuisé en
    /// donnerait sinon une à chaque requête.
    private func send(_ alert: OJPAlert, now: Date = Date()) {
        let id = "\(alert.kind.rawValue)-\(alert.key ?? 0)"
        let shouldSend: Bool = lock.withLock {
            if let last = lastAlerts[id], now.timeIntervalSince(last) < 3600, alert.kind != .quotaLow { return false }
            lastAlerts[id] = now
            return true
        }
        guard shouldSend else { return }
        Log.network.warning("Alerte OJP \(alert.kind.rawValue, privacy: .public), clé \(alert.key ?? 0, privacy: .public) : \(alert.detail, privacy: .public)")
        Self.alertHandler?(alert)
    }

    public static func day(_ date: Date) -> String {
        let components = Calendar(identifier: .gregorian).dateComponents(in: .current, from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }
}

extension OJPUsage.Incident: Hashable {}
