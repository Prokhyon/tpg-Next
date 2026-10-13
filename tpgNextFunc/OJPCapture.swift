//
//  OJPCapture.swift
//  tpgNextFunc
//
//  Captures de l'App Store (Debug seulement) : les réponses d'OJP enregistrées une fois,
//  puis relues à 9:41 quel que soit le moment de la capture.
//
//  Dans les deux modes, l'app se croit à 9:41 (`AppClock`) : toutes les requêtes portent sur
//  9:41, et chaque lancement reste cohérent avec les autres (un trajet régulier choisi dans
//  l'un est retrouvé dans l'autre).
//
//  - `-CaptureRecord` : chaque réponse est écrite dans Documents/Capture du conteneur de
//    l'app, avec le jour de l'enregistrement (son 9:41).
//  - `-CaptureMode` : l'app ne joint plus l'API. La réponse enregistrée pour la même requête
//    est rendue, décalée de 9:41 le jour de l'enregistrement à 9:41 aujourd'hui. Sans réponse
//    enregistrée : erreur dans le journal.
//
//  Une requête est reconnue à son contenu, sans ses horodatages, son heure demandée et son
//  jour d'exploitation, qui changent d'une capture à l'autre. Les fichiers se rangent dans
//  `tpg Next/Preview Content/Capture` (exclu des archives) : `capture-<clé>_<minute>.xml`
//  et `capture-index.json` (« clé_minute » → 9:41 le jour de l'enregistrement).
//

#if DEBUG
import Foundation
import CryptoKit

enum OJPCapture {
    static let isRecording = ProcessInfo.processInfo.arguments.contains("-CaptureRecord")
    static let isReplaying = ProcessInfo.processInfo.arguments.contains("-CaptureMode")
    private static let queue = DispatchQueue(label: "tpgNext.ojpCapture")

    // MARK: Clé

    /// La requête sans ce qui change d'une capture à l'autre.
    static func key(for body: String) -> String {
        var text = body
        for tag in ["siri:RequestTimestamp", "DepArrTime", "OperatingDayRef"] {
            text = text.replacing(try! Regex("<\(tag)>[^<]*</\(tag)>"), with: "<\(tag)/>")
        }
        text = text.replacing(try! Regex(#"\s+"#), with: " ")
        let digest = SHA256.hash(data: Data(text.utf8))
        return digest.prefix(8).map { String(format: "%02x", $0) }.joined()
    }

    /// L'heure demandée, en minutes depuis 9:41 (0 sans heure) : une même requête peut être
    /// faite à plusieurs heures (recherche du trajet, puis sa vérification).
    static func minute(of body: String) -> Int {
        guard let match = body.firstMatch(of: try! Regex(#"<DepArrTime>([^<]*)</DepArrTime>"#)),
              let value = match.output[1].substring, let date = OJPDate.date(from: String(value)) else { return 0 }
        return Int((date.timeIntervalSince(AppClock.captureReference) / 60).rounded())
    }

    /// Le type de requête, pour le journal.
    private static func kind(of body: String) -> String {
        body.firstMatch(of: try! Regex(#"<(OJP\w+Request)>"#))?.output[1].substring.map(String.init) ?? "?"
    }

    // MARK: Enregistrement

    private static var folder: URL {
        URL.documentsDirectory.appending(path: "Capture", directoryHint: .isDirectory)
    }

    static func record(_ data: Data, for body: String) {
        let name = "\(key(for: body))_\(minute(of: body))"
        let day = AppClock.captureReference
        queue.async {
            do {
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                try data.write(to: folder.appending(path: "capture-\(name).xml"))
                let indexURL = folder.appending(path: "capture-index.json")
                var index = (try? JSONDecoder().decode([String: String].self, from: Data(contentsOf: indexURL))) ?? [:]
                index[name] = OJPDate.string(from: day)
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                try encoder.encode(index).write(to: indexURL)
            } catch {
                Log.network.error("Capture : enregistrement impossible, \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    // MARK: Relecture

    /// « clé_minute » → 9:41 le jour de l'enregistrement.
    private static let index: [String: String] = {
        guard let url = Bundle.main.url(forResource: "capture-index", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let index = try? JSONDecoder().decode([String: String].self, from: data) else { return [:] }
        return index
    }()

    /// La réponse enregistrée pour cette requête, à l'heure demandée la plus proche, recalée
    /// sur 9:41 aujourd'hui ; `nil` sans enregistrement.
    static func replay(_ body: String) -> Data? {
        let key = key(for: body)
        let wanted = minute(of: body)
        let candidates = index.keys.filter { $0.hasPrefix(key + "_") }
        guard let name = candidates.min(by: {
                  abs((Int($0.dropFirst(key.count + 1)) ?? 0) - wanted) < abs((Int($1.dropFirst(key.count + 1)) ?? 0) - wanted)
              }),
              let recorded = index[name].flatMap(OJPDate.date(from:)),
              let url = Bundle.main.url(forResource: "capture-\(name)", withExtension: "xml"),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            Log.network.error("Capture : pas de réponse enregistrée pour \(kind(of: body), privacy: .public) \(key, privacy: .public)")
            return nil
        }
        return Data(rebase(text, from: recorded, to: AppClock.captureReference).utf8)
    }

    /// Décale toutes les heures du texte de `target - recorded`, et les jours d'exploitation
    /// du nombre de jours qui les séparent (heure suisse).
    static func rebase(_ text: String, from recorded: Date, to target: Date) -> String {
        let shift = target.timeIntervalSince(recorded)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Zurich") ?? .current
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: recorded),
                                           to: calendar.startOfDay(for: target)).day ?? 0
        let timestamp = try! Regex(#"(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2})(\.\d+)?(Z|[+-]\d{2}:\d{2})"#)
        var rebased = text.replacing(timestamp) { match in
            let original = String(text[match.range])
            guard let base = match.output[1].substring, let zone = match.output[3].substring,
                  let date = OJPDate.date(from: String(base) + String(zone)) else { return original }
            return OJPDate.string(from: date.addingTimeInterval(shift))
        }
        guard days != 0 else { return rebased }
        let day = try! Regex(#"OperatingDayRef>(\d{4}-\d{2}-\d{2})<"#)
        let dayFormatter = DateFormatter()
        dayFormatter.locale = Locale(identifier: "en_US_POSIX")
        dayFormatter.timeZone = calendar.timeZone
        dayFormatter.dateFormat = "yyyy-MM-dd"
        let source = rebased
        rebased = source.replacing(day) { match in
            let original = String(source[match.range])
            guard let value = match.output[1].substring, let date = dayFormatter.date(from: String(value)),
                  let moved = calendar.date(byAdding: .day, value: days, to: date) else { return original }
            return "OperatingDayRef>\(dayFormatter.string(from: moved))<"
        }
        return rebased
    }
}
#endif
