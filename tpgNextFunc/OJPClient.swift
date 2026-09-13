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

    /// Envoie une requête XML et rend la réponse brute, sur `completionQueue`.
    ///
    /// Un statut HTTP hors 2xx (clé refusée, quota dépassé) est un échec : la réponse,
    /// qui n'est alors pas du OJP, finissait sinon dans les parseurs et donnait une liste vide.
    public static func post(_ body: String,
                            to version: Version,
                            completionQueue: DispatchQueue = .main,
                            completion: @escaping (Result<Data, Failure>) -> Void) {
        var request = URLRequest(url: version.url)
        request.httpMethod = "POST"
        request.setValue("text/XML", forHTTPHeaderField: "Content-Type")
        request.setValue("application/xml", forHTTPHeaderField: "Accept")
        request.setValue(keySelect(), forHTTPHeaderField: "Authorization")
        request.httpBody = Data(body.utf8)

        session.dataTask(with: request) { data, response, error in
            let result: Result<Data, Failure>
            if let error {
                result = .failure(.network(error))
            } else if let status = (response as? HTTPURLResponse)?.statusCode, !(200..<300).contains(status) {
                result = .failure(.http(status: status))
            } else if let data, !data.isEmpty {
                result = .success(data)
            } else {
                result = .failure(.emptyResponse)
            }
            if case .failure(let failure) = result {
                Log.network.error("OJP \(version.rawValue) : \(String(describing: failure))")
            }
            completionQueue.async { completion(result) }
        }.resume()
    }
}
