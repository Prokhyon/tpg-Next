//
//  TripStepAlerts.swift
//  tpg Next
//
//  Les alertes d'un trajet suivi : monter, descendre, arriver.
//

import Foundation
import UserNotifications
import tpgNextFunc

/// Les moments où lever les yeux de son livre : le véhicule qui arrive, l'approche de l'arrêt
/// où descendre (« Préparez-vous à descendre »), l'arrêt lui-même (« Descendez ici », avec la
/// suite du trajet), et l'arrivée quand elle se fait à pied.
///
/// Comme les rappels de départ, ces alertes sont posées à l'avance auprès du système : elles
/// partent même si l'app ne tourne pas. Elles sont reposées à chaque mise à jour du trajet
/// suivi, donc elles suivent les retards tant que l'app a pu relire les horaires.
///
/// Chacune ne part qu'une fois : une alerte déjà partie n'est pas reposée quand l'heure recule
/// ensuite (bus annoncé une minute plus tard, correction par la position), sinon elle
/// sonnerait deux fois.
enum TripStepAlerts {
    private static let prefix = "livestep_"
    /// L'heure prévue de chaque alerte, par identifiant : passée, l'alerte est partie.
    private static let firedStore = CodableStore<[String: Date]>(key: "liveStepAlertDates")
    /// Le véhicule arrive : une minute avant la montée.
    private static let boardingLead: TimeInterval = 60
    /// Se préparer à descendre, faute de connaître l'arrêt précédent : deux minutes avant.
    private static let preparingLead: TimeInterval = 120
    /// « Descendez ici » : le véhicule entre dans l'arrêt.
    private static let alightingLead: TimeInterval = 30
    /// Une montée qui suit de si près le « Descendez ici » n'a rien à ajouter : il l'annonce déjà.
    private static let transferQuiet: TimeInterval = 3 * 60
    /// Le moment passé, l'alerte ne sert plus : elle quitte le centre de notifications.
    private static let stale: TimeInterval = 60

    static func schedule(key: String, title: String, state: TripActivityState, now: Date = Date()) {
        var steps: [UNNotificationRequest?] = []

        for (index, leg) in state.legs.enumerated() {
            // La ligne et l'arrêt dans l'identifiant : après une suite recalculée, l'étape de
            // même rang est un autre véhicule, qui mérite ses propres alertes.
            let vehicle = "\(index)_\(leg.line)_\(leg.boardName)"
            let stop = shortStopName(leg.alightName)
            let alighting = leg.alight.addingTimeInterval(-alightingLead)

            let previousAlighting = index > 0 ? state.legs[index - 1].alight.addingTimeInterval(-alightingLead) : nil
            if previousAlighting.map({ leg.board.addingTimeInterval(-boardingLead).timeIntervalSince($0) > transferQuiet }) ?? true {
                let quay = leg.boardQuay.isEmpty ? "" : String(localized: ", quai \(leg.boardQuay)")
                steps.append(request(key: key, step: "board\(vehicle)", at: leg.board.addingTimeInterval(-boardingLead),
                                        now: now, until: leg.board.addingTimeInterval(stale),
                                        title: title, subtitle: String(localized: "Votre véhicule arrive"),
                                        body: String(localized: "Le \(leg.line) arrive à \(shortStopName(leg.boardName))\(quay)")))
            }

            // Se préparer : quand le véhicule quitte l'arrêt d'avant, s'il est connu ; sinon deux
            // minutes avant. Rien pour un trajet si court qu'on vient à peine de monter.
            let preparing = previousStop(before: leg)
            let preparingDate = preparing?.time ?? leg.alight.addingTimeInterval(-preparingLead)
            if preparingDate > leg.board.addingTimeInterval(30), preparingDate < alighting {
                steps.append(request(key: key, step: "prepare\(vehicle)", at: preparingDate, now: now,
                                        until: leg.alight.addingTimeInterval(stale),
                                        title: title, subtitle: String(localized: "Préparez-vous à descendre"),
                                        body: preparing == nil
                                            ? String(localized: "Vous descendez à \(stop) dans 2 min")
                                            : String(localized: "Prochain arrêt : \(stop)")))
            }

            // Descendre : l'arrêt, puis ce qui suit.
            let then: String
            if state.legs.indices.contains(index + 1) {
                let next = state.legs[index + 1]
                let quay = next.boardQuay.isEmpty ? "" : String(localized: ", quai \(next.boardQuay)")
                then = String(localized: "Ensuite : le \(next.line) à \(dateToString(with: next.board))\(quay).")
            } else if state.arrival.timeIntervalSince(leg.alight) > 60 {
                let minutes = max(1, Int((state.arrival.timeIntervalSince(leg.alight) / 60).rounded()))
                then = String(localized: "Ensuite : \(minutes) min à pied jusqu'à destination.")
            } else {
                then = String(localized: "Vous êtes arrivé.")
            }
            steps.append(request(key: key, step: "alight\(vehicle)", at: alighting, now: now,
                                    until: leg.alight.addingTimeInterval(stale),
                                    title: title, subtitle: String(localized: "Descendez ici"),
                                    body: String(localized: "C'est votre arrêt : \(stop). \(then)")))
        }
        var requests = steps.compactMap { $0 }
        // L'arrivée, quand elle n'est pas la descente du dernier véhicule (marche finale).
        if let last = state.legs.last, state.arrival.timeIntervalSince(last.alight) > 60 {
            requests.append(contentsOf: [
                request(key: key, step: "arrival", at: state.arrival, now: now,
                        until: state.arrival.addingTimeInterval(stale),
                        title: title, subtitle: String(localized: "Arrivée"),
                        body: String(localized: "Vous arrivez à destination")),
            ].compactMap { $0 })
        }

        // Déjà partie : ni reposée, ni retirée.
        var dates = firedStore.load() ?? [:]
        requests.removeAll { request in
            guard let previous = dates[request.identifier] else { return false }
            return previous <= now
        }
        for request in requests {
            if let trigger = request.trigger as? UNTimeIntervalNotificationTrigger {
                dates[request.identifier] = now.addingTimeInterval(trigger.timeInterval)
            }
        }
        // Rien ne sert au-delà d'une journée.
        firedStore.save(dates.filter { now.timeIntervalSince($0.value) < 24 * 3600 })

        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { pending in
            let stale = pending.map(\.identifier).filter { $0.hasPrefix(prefix + key) }
            center.removePendingNotificationRequests(withIdentifiers: stale)
            for request in requests {
                center.add(request) { error in
                    if let error {
                        Log.notifications.error("Alerte d'étape non prévue : \(error.localizedDescription)")
                    }
                }
            }
        }
    }

    /// Retire les alertes d'un trajet qui n'est plus suivi, y compris celles déjà reçues.
    static func cancel(key: String) {
        if let dates = firedStore.load() {
            firedStore.save(dates.filter { !$0.key.hasPrefix(prefix + key) })
        }
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { pending in
            center.removePendingNotificationRequests(
                withIdentifiers: pending.map(\.identifier).filter { $0.hasPrefix(prefix + key) })
        }
        center.getDeliveredNotifications { delivered in
            center.removeDeliveredNotifications(
                withIdentifiers: delivered.map(\.request.identifier).filter { $0.hasPrefix(prefix + key) })
        }
    }

    /// Le passage à l'arrêt qui précède la descente, d'après les passages embarqués dans l'état.
    /// `nil` s'ils manquent, ou si c'est l'arrêt de montée.
    private static func previousStop(before leg: TripActivityState.Leg) -> TripActivityState.Call? {
        let stop = shortStopName(leg.alightName)
        guard let calls = leg.calls, let index = calls.lastIndex(where: { $0.name == stop }), index > 0 else { return nil }
        let previous = calls[index - 1]
        guard previous.time > leg.board, previous.time < leg.alight else { return nil }
        return previous
    }

    /// `nil` si le moment est déjà passé.
    private static func request(key: String, step: String, at date: Date, now: Date, until: Date,
                                title: String, subtitle: String, body: String) -> UNNotificationRequest? {
        guard date > now else { return nil }
        let content = UNMutableNotificationContent()
        content.title = title
        content.subtitle = subtitle
        content.body = body
        content.sound = UNNotificationSound(named: UNNotificationSoundName("tpgNextNotificationSound.caf"))
        content.userInfo = [TripStepAlerts.userInfoKey: key]
        NotificationExpiry.mark(content, after: until)
        content.threadIdentifier = key
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(date.timeIntervalSince(now), 1), repeats: false)
        return UNNotificationRequest(identifier: "\(prefix)\(key)_\(step)", content: content, trigger: trigger)
    }

    /// Clé du `userInfo` : le toucher ouvre la page du trajet suivi.
    static let userInfoKey = "liveTripKey"
}
