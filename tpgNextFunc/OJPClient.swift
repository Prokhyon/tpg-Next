//
//  OJPClient.swift
//  tpgNextFunc
//

import Foundation

/// L'unique point d'accès à l'API OJP : URL, en-têtes, clé, délai d'attente et journal.
///
/// Les trois requêtes (départs, itinéraires, course) dupliquaient ce code, avec un
/// `Content-Type` posé deux fois et des échecs rendus sur une file de fond.
public enum OJPClient {
    public enum Version: String {
        /// Départs et itinéraires.
        case v1 = "ojp2020"
        /// Courses (`OJPTripInfoRequest`).
        case v2 = "ojp20"

        var url: URL { URL(string: "https://api.opentransportdata.swiss/" + rawValue)! }
    }

    public enum Failure: Error {
        case network(Error)
        case http(status: Int)
        case emptyResponse
    }

    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 20
        return URLSession(configuration: configuration)
    }()

    private static func request(_ body: String, to version: Version) -> URLRequest {
        var request = URLRequest(url: version.url)
        request.httpMethod = "POST"
        request.setValue("text/XML", forHTTPHeaderField: "Content-Type")
        request.setValue("application/xml", forHTTPHeaderField: "Accept")
        request.setValue(keySelect(), forHTTPHeaderField: "Authorization")
        request.httpBody = Data(body.utf8)
        return request
    }

    /// Un statut HTTP hors 2xx (clé refusée, quota dépassé) est un échec : la réponse,
    /// qui n'est alors pas du OJP, finissait sinon dans les parseurs et donnait une liste vide.
    private static func validate(_ data: Data?, _ response: URLResponse?, _ error: Error?) -> Result<Data, Failure> {
        if let error {
            return .failure(.network(error))
        }
        if let status = (response as? HTTPURLResponse)?.statusCode, !(200..<300).contains(status) {
            return .failure(.http(status: status))
        }
        guard let data, !data.isEmpty else {
            return .failure(.emptyResponse)
        }
        return .success(data)
    }

    private static func log(_ result: Result<Data, Failure>, _ version: Version) {
        if case .failure(let failure) = result {
            Log.network.error("OJP \(version.rawValue) : \(String(describing: failure))")
        }
    }

    /// Envoie une requête XML et rend la réponse brute, sur `completionQueue`.
    public static func post(_ body: String,
                            to version: Version,
                            completionQueue: DispatchQueue = .main,
                            completion: @escaping (Result<Data, Failure>) -> Void) {
        session.dataTask(with: request(body, to: version)) { data, response, error in
            let result = validate(data, response, error)
            log(result, version)
            completionQueue.async { completion(result) }
        }.resume()
    }

    /// Variante `async`, qui se termine toujours (réponse, erreur ou délai dépassé) et
    /// s'annule avec la tâche appelante. Lève `OJPClient.Failure`.
    public static func post(_ body: String, to version: Version) async throws -> Data {
        let result: Result<Data, Failure>
        do {
            let (data, response) = try await session.data(for: request(body, to: version))
            result = validate(data, response, nil)
        } catch {
            result = .failure(.network(error))
        }
        log(result, version)
        return try result.get()
    }
}
