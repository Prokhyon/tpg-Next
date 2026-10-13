//
//  OJPClient.swift
//  tpgNextFunc
//

import Foundation

/// L'unique point d'accès à l'API OJP : URL, en-têtes, clé, délai d'attente et journal.
///
/// Les trois requêtes (départs, itinéraires, course) dupliquaient ce code, avec un
/// `Content-Type` posé deux fois et des échecs rendus sur une file de fond.
///
/// Chaque clé a son quota (50 requêtes par minute, 20 000 par jour, partagés par tous les
/// appareils). Une clé épuisée, limitée ou refusée est mise en pause et la requête repart
/// aussitôt avec une autre : l'utilisateur ne voit l'échec que si toutes manquent.
public enum OJPClient {
    public enum Version: String {
        /// Départs, courses et itinéraires. OJP 1.0 (`ojp2020`) ne sert plus.
        case v2 = "ojp20"

        var url: URL { URL(string: "https://api.opentransportdata.swiss/" + rawValue)! }
    }

    public enum Failure: Error {
        /// Pas de réseau : mode avion, aucune connexion.
        case offline
        /// Pas de réponse dans les 20 secondes.
        case timeout
        /// Une autre erreur de connexion (DNS, TLS, connexion coupée).
        case network(Error)
        /// La vue a disparu ou la tâche a été annulée : ni affiché ni compté.
        case cancelled
        /// 429 : plus de 50 requêtes en une minute sur la clé.
        case rateLimited
        /// 403 « Quota exceeded » : les 20 000 requêtes du jour de la clé sont passées.
        case quotaExceeded
        /// 401, ou 403 sans quota en cause : clé absente, invalide, révoquée.
        case keyRejected(status: Int)
        /// Un autre 4xx : l'API refuse la requête elle-même.
        case badRequest(status: Int)
        /// 5xx : le service est en panne ou surchargé.
        case server(status: Int)
        case emptyResponse
        /// Une réponse reçue mais illisible (signalée par les parseurs).
        case unreadable

        /// Un identifiant court et stable, pour les compteurs et le journal.
        public var code: String {
            switch self {
            case .offline: "hors-ligne"
            case .timeout: "délai"
            case .network(let error): "réseau (\((error as? URLError)?.code.rawValue ?? 0))"
            case .cancelled: "annulée"
            case .rateLimited: "limite-minute"
            case .quotaExceeded: "quota-jour"
            case .keyRejected(let status): "clé-refusée (\(status))"
            case .badRequest(let status): "requête-refusée (\(status))"
            case .server(let status): "serveur (\(status))"
            case .emptyResponse: "réponse-vide"
            case .unreadable: "illisible"
            }
        }

        /// La faute est à la connexion de l'appareil, pas au service.
        public var isConnectivity: Bool {
            switch self {
            case .offline, .timeout, .network: true
            default: false
            }
        }

        /// Une autre clé réussira peut-être.
        var isKeySpecific: Bool {
            switch self {
            case .rateLimited, .quotaExceeded, .keyRejected: true
            default: false
            }
        }

        /// Une panne passagère de la passerelle : un nouvel essai, une seconde plus tard.
        var isTransient: Bool {
            if case .server(let status) = self { return [502, 503, 504].contains(status) }
            return false
        }

        var isRecorded: Bool {
            if case .cancelled = self { return false }
            return true
        }

        /// Ce qui mérite de prévenir le développeur ; les coupures de l'utilisateur, non.
        var alertKind: OJPAlert.Kind? {
            switch self {
            case .quotaExceeded: .quotaExceeded
            case .rateLimited: .rateLimited
            case .keyRejected: .keyRejected
            case .badRequest: .badRequest
            case .server: .server
            case .unreadable: .unreadable
            default: nil
            }
        }
    }

    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 20
        return URLSession(configuration: configuration)
    }()

    private static func request(_ body: String, to version: Version, key: String) -> URLRequest {
        var request = URLRequest(url: version.url)
        request.httpMethod = "POST"
        request.setValue("text/XML", forHTTPHeaderField: "Content-Type")
        request.setValue("application/xml", forHTTPHeaderField: "Accept")
        request.setValue(key, forHTTPHeaderField: "Authorization")
        request.httpBody = Data(body.utf8)
        return request
    }

    /// Un statut HTTP hors 2xx est un échec : la réponse, qui n'est alors pas du OJP, finissait
    /// sinon dans les parseurs et donnait une liste vide. Le gestionnaire de l'API répond 403
    /// aussi bien pour une clé refusée que pour un quota épuisé : seul le texte les distingue
    /// (`{"error": "Quota exceeded"}`).
    static func classify(status: Int, body: Data) -> Failure? {
        switch status {
        case 200..<300:
            return body.isEmpty ? .emptyResponse : nil
        case 429:
            return .rateLimited
        case 403:
            let text = String(decoding: body.prefix(500), as: UTF8.self).lowercased()
            if text.contains("quota") { return .quotaExceeded }
            if text.contains("rate limit") { return .rateLimited }
            return .keyRejected(status: status)
        case 401:
            return .keyRejected(status: status)
        case 400..<500:
            return .badRequest(status: status)
        default:
            return .server(status: status)
        }
    }

    static func classify(_ error: Error) -> Failure {
        if error is CancellationError { return .cancelled }
        guard let urlError = error as? URLError else { return .network(error) }
        switch urlError.code {
        case .cancelled: return .cancelled
        case .timedOut: return .timeout
        case .notConnectedToInternet, .dataNotAllowed, .internationalRoamingOff: return .offline
        default: return .network(error)
        }
    }

    /// Un seul envoi, avec une clé donnée, enregistré dans `OJPUsage`.
    private static func send(_ body: String, to version: Version, key: (number: Int, key: String)) async -> Result<Data, Failure> {
        let usage = OJPUsage.shared
        usage.recordRequest(key: key.number)
        let failure: Failure
        var httpResponse: HTTPURLResponse?
        do {
            let (data, response) = try await session.data(for: request(body, to: version, key: key.key))
            httpResponse = response as? HTTPURLResponse
            if let httpResponse {
                usage.record(response: httpResponse, key: key.number)
            }
            guard let classified = classify(status: httpResponse?.statusCode ?? 200, body: data) else {
                return .success(data)
            }
            failure = classified
        } catch {
            failure = classify(error)
        }
        usage.record(failure: failure, key: key.number, endpoint: version.rawValue, response: httpResponse)
        if failure.isRecorded {
            Log.network.error("OJP \(version.rawValue, privacy: .public), clé \(key.number, privacy: .public) : \(failure.code, privacy: .public)")
        }
        return .failure(failure)
    }

    /// Envoie une requête XML et rend la réponse brute, sur `completionQueue`.
    public static func post(_ body: String,
                            to version: Version,
                            completionQueue: DispatchQueue = .main,
                            completion: @escaping (Result<Data, Failure>) -> Void) {
        Task {
            let result: Result<Data, Failure>
            do {
                result = .success(try await post(body, to: version))
            } catch let failure as Failure {
                result = .failure(failure)
            } catch {
                result = .failure(classify(error))
            }
            completionQueue.async { completion(result) }
        }
    }

    /// Variante `async`, qui se termine toujours (réponse, erreur ou délai dépassé) et
    /// s'annule avec la tâche appelante. Lève `OJPClient.Failure`.
    ///
    /// Essaie chaque clé au plus une fois quand l'échec tient à la clé, et refait une
    /// fois la requête après une panne passagère de la passerelle (502, 503, 504).
    public static func post(_ body: String, to version: Version) async throws -> Data {
        #if DEBUG
        // Captures de l'App Store : réponses enregistrées, relues à 9:41 (OJPCapture).
        if OJPCapture.isReplaying {
            guard let data = OJPCapture.replay(body) else { throw Failure.offline }
            return data
        }
        if OJPCapture.isRecording {
            let data = try await postToAPI(body, to: version)
            OJPCapture.record(data, for: body)
            return data
        }
        #endif
        return try await postToAPI(body, to: version)
    }

    private static func postToAPI(_ body: String, to version: Version) async throws -> Data {
        var tried = Set<Int>()
        var retriedTransient = false
        var lastFailure = Failure.keyRejected(status: 0)
        while let key = OJPUsage.shared.pickKey(excluding: tried) {
            tried.insert(key.number)
            switch await send(body, to: version, key: key) {
            case .success(let data):
                return data
            case .failure(let failure):
                lastFailure = failure
                if failure.isKeySpecific {
                    continue
                }
                if failure.isTransient, !retriedTransient {
                    retriedTransient = true
                    tried.remove(key.number)
                    try? await Task.sleep(for: .seconds(1))
                    continue
                }
                throw failure
            }
        }
        throw lastFailure
    }

    // MARK: - Vérification des clés

    /// Une requête minuscule par clé, pour relire son quota (page de diagnostic). Chacune
    /// compte comme une requête dans le quota.
    public static func checkAllKeys() async {
        let body = stopEventRequestXML(stopName: "Vérification", stopSloid: "ch:1:sloid:0", count: 1, at: Date())
        await withTaskGroup(of: Void.self) { group in
            for (index, key) in Secrets.ojpAPIKeys.enumerated() {
                group.addTask {
                    _ = await send(body, to: .v2, key: (index + 1, key))
                }
            }
        }
    }
}
