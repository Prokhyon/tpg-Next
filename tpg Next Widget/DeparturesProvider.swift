//
//  DeparturesProvider.swift
//  tpg Next Widget
//
//  Created by Loris Thomas on 26.08.2026.
//

import WidgetKit
import SwiftUI
import CoreLocation
import tpgNextFunc

// MARK: - Entrée de timeline

struct DeparturesEntry: TimelineEntry {
    /// Conforme à `Error` pour servir de branche d'échec au `Result` du provider.
    enum Status: Error {
        case ok
        /// Position indisponible : autorisation refusée, ou jamais obtenue par l'app.
        case noLocation
        /// L'index des arrêts n'a pas encore été écrit : l'app n'a jamais été ouverte.
        case indexMissing
        /// Le conteneur du groupe d'app est hors d'atteinte : la capacité App Groups
        /// manque sur l'une des deux cibles, ou le profil ne la porte pas.
        /// Distinct d'`indexMissing` pour que le widget dise lui-même laquelle des
        /// deux causes s'applique sur un appareil réel.
        case sharedStorageUnavailable
        case noStopNearby
        case noDepartures
        case networkError
    }

    let date: Date
    let stop: Stop?
    let events: [StopEvent]
    let status: Status
    /// Distance à l'arrêt en mode automatique, `nil` si l'arrêt a été choisi à la main.
    let distance: CLLocationDistance?

    static func message(_ status: Status, at date: Date = Date()) -> DeparturesEntry {
        DeparturesEntry(date: date, stop: nil, events: [], status: status, distance: nil)
    }
}

// MARK: - Provider

struct DeparturesProvider: AppIntentTimelineProvider {
    /// Assez de départs pour tenir trois quarts d'heure sans rappeler l'API.
    private let requestedDepartures = 15
    /// En dessous de trois départs à afficher, la liste se vide : mieux vaut redemander.
    private let minimumRowsToKeepGoing = 3
    /// Le pas du décompte. À 30 s, une minute affichée bascule au plus une demi-minute
    /// après sa vraie échéance, contre une minute entière avec un pas de 60 s.
    /// Ça ne coûte aucune requête : seulement deux fois plus d'entrées dans la
    /// même timeline, que WidgetKit pré-rend au moment de la construire.
    private let entryInterval: TimeInterval = 30

    /// Durée couverte par une seule requête réseau. C'est elle, et non `entryInterval`,
    /// qui fixe la fréquence des appels à l'API.
    private let coverage: TimeInterval = 45 * 60

    private var maximumEntries: Int { Int(coverage / entryInterval) }

    func placeholder(in context: Context) -> DeparturesEntry {
        DeparturesEntry(date: Date(), stop: PreviewData.stop, events: PreviewData.events, status: .ok, distance: 120)
    }

    /// Vrai quand le code tourne dans l'agent d'aperçu de Xcode, où ni la
    /// localisation ni le réseau ne sont souhaitables.
    static var isRunningInPreviewCanvas: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }

    func snapshot(for configuration: SelectStopIntent, in context: Context) async -> DeparturesEntry {
        // La galerie de widgets doit montrer quelque chose immédiatement.
        guard !context.isPreview, !Self.isRunningInPreviewCanvas else { return placeholder(in: context) }
        return await buildEntries(for: configuration).first ?? placeholder(in: context)
    }

    func timeline(for configuration: SelectStopIntent, in context: Context) async -> Timeline<DeparturesEntry> {
        // Dans le canevas Xcode : pas de position ni de réseau, sinon l'aperçu
        // attend le délai des deux avant d'afficher quoi que ce soit.
        guard !Self.isRunningInPreviewCanvas else {
            return Timeline(entries: [placeholder(in: context)], policy: .never)
        }
        let entries = await buildEntries(for: configuration)
        guard let last = entries.last, entries.count > 1 else {
            // Erreur ou arrêt sans départ : on retente sans insister.
            return Timeline(entries: entries, policy: .after(Date().addingTimeInterval(15 * 60)))
        }
        return Timeline(entries: entries, policy: .after(last.date))
    }

    // MARK: - Construction des entrées

    /// Une seule requête réseau, puis une entrée par minute : le décompte descend tout
    /// seul et les départs passés disparaissent sans consommer le budget de rafraîchissement.
    private func buildEntries(for configuration: SelectStopIntent) async -> [DeparturesEntry] {
        let now = Date()

        let resolution = await resolveStop(for: configuration)
        switch resolution {
        case .failure(let status):
            return [.message(status, at: now)]
        case .success(let target):
            guard let events = await fetchDepartures(for: target.stop) else {
                return [DeparturesEntry(date: now, stop: target.stop, events: [], status: .networkError, distance: target.distance)]
            }
            let sorted = events.sorted { $0.estimatedTime < $1.estimatedTime }
            guard !sorted.isEmpty else {
                return [DeparturesEntry(date: now, stop: target.stop, events: [], status: .noDepartures, distance: target.distance)]
            }

            let requiredRows = min(minimumRowsToKeepGoing, sorted.count)
            var entries: [DeparturesEntry] = []

            for step in 0..<maximumEntries {
                let date = now.addingTimeInterval(Double(step) * entryInterval)
                let upcoming = sorted.filter { !hasDeparted($0, at: date) }
                guard step == 0 || upcoming.count >= requiredRows else { break }
                entries.append(DeparturesEntry(date: date, stop: target.stop, events: upcoming,
                                               status: .ok, distance: target.distance))
            }
            return entries
        }
    }

    /// Un départ reste affiché une demi-minute après son heure, comme dans l'app.
    private func hasDeparted(_ event: StopEvent, at date: Date) -> Bool {
        guard let departure = DateParsing.date(from: event.estimatedTime.isEmpty ? event.timetabledTime : event.estimatedTime) else {
            return false
        }
        return departure.addingTimeInterval(30) < date
    }

    // MARK: - Choix de l'arrêt

    private struct Target {
        let stop: Stop
        let distance: CLLocationDistance?
    }

    private func resolveStop(for configuration: SelectStopIntent) async -> Result<Target, DeparturesEntry.Status> {
        let selection = configuration.selection
        guard SharedStorage.isAvailable else { return .failure(.sharedStorageUnavailable) }
        let reader = StopIndexReader()

        guard selection.isAutomatic else {
            // L'index donne le nom et le type à jour ; l'entité configurée sert de repli.
            let stop = reader?.stop(sloid: selection.id) ?? selection.stop
            guard let stop else { return .failure(.indexMissing) }
            return .success(Target(stop: stop, distance: nil))
        }

        guard let reader else { return .failure(.indexMissing) }
        guard let location = await WidgetLocation.current() else { return .failure(.noLocation) }
        guard let selected = NearbyStopSelector.selectStop(near: location.coordinate,
                                                           using: reader,
                                                           favoriteSloids: NearbyStopSelector.favoriteSloids()) else {
            return .failure(.noStopNearby)
        }
        return .success(Target(stop: selected.stop, distance: selected.distance))
    }

    // MARK: - Réseau

    private func fetchDepartures(for stop: Stop) async -> [StopEvent]? {
        let empty: [StopEvent]? = nil
        return await withTimeout(seconds: 20, fallback: empty) {
            await withCheckedContinuation { (continuation: CheckedContinuation<[StopEvent]?, Never>) in
                fetchTransportDepartures(with: stop.name,
                                         stopSloid: stop.sloid,
                                         stopEventNumber: requestedDepartures,
                                         timeRequest: Date()) { success, response in
                    guard success, let data = response?.data(using: .utf8) else {
                        continuation.resume(returning: nil)
                        return
                    }
                    parseStopEvents(from: data, stopCode: stop.sloid) { events, _, error in
                        continuation.resume(returning: error == nil ? events : [])
                    }
                }
            }
        }
    }
}

// MARK: - Position

/// La position vue depuis l'extension.
///
/// Une extension n'a le droit de demander la position que si l'app a l'autorisation
/// « Toujours » (`isAuthorizedForWidgetUpdates`). Sinon on se rabat sur la dernière
/// position enregistrée par l'app, ce qui garde le mode automatique utilisable.
enum WidgetLocation {
    static func current() async -> CLLocation? {
        let fetcher = LocationFetcher()
        guard await fetcher.isAuthorizedForWidgetUpdates() else {
            return SharedStorage.lastKnownLocation
        }
        guard let location = await fetcher.requestLocation(timeout: 8) else {
            return SharedStorage.lastKnownLocation
        }
        SharedStorage.saveLastKnownLocation(location)
        return location
    }
}

/// `CLLocationManager` livre ses rappels sur la file où il a été créé, et celle-ci
/// doit avoir une boucle d'exécution. Le provider tourne dans un contexte async
/// sur une file de fond : le manager est donc créé et piloté sur la file
/// principale, faute de quoi le délégué ne répond jamais.
private final class LocationFetcher: NSObject, CLLocationManagerDelegate, @unchecked Sendable {
    private var manager: CLLocationManager?
    private let result = SingleResume<CLLocation?>()

    /// Vrai avec « Toujours ». Avec « Pendant l'utilisation », vrai seulement si le
    /// widget est rafraîchi peu après avoir été vu — d'où le repli systématique.
    func isAuthorizedForWidgetUpdates() async -> Bool {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                continuation.resume(returning: CLLocationManager().isAuthorizedForWidgetUpdates)
            }
        }
    }

    /// Rend toujours la main : au point obtenu, à l'erreur, ou à l'échéance.
    func requestLocation(timeout: TimeInterval) async -> CLLocation? {
        await withCheckedContinuation { continuation in
            result.attach(continuation)
            DispatchQueue.main.async { [self] in
                let manager = CLLocationManager()
                self.manager = manager
                manager.delegate = self
                manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
                manager.requestLocation()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + timeout) { [self] in
                result.resolve(nil)
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        result.resolve(locations.last)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Widget location failed: \(error.localizedDescription)")
        result.resolve(nil)
    }
}

// MARK: - Utilitaires

/// Le rendu d'un widget ne doit pas rester suspendu : toute attente est bornée.
/// Borne l'attente **sans dépendre de la coopération de l'opération**.
///
/// `withTaskGroup` ne convient pas ici : il attend toutes ses tâches filles avant
/// de rendre la main, et `cancelAll()` ne peut rien contre une
/// `withCheckedContinuation` jamais reprise — l'annulation est coopérative et une
/// continuation n'est pas un point d'annulation. Une réponse réseau ou un délégué
/// de localisation muet suspendait donc la construction de la timeline pour
/// toujours, et WidgetKit restait sur son placeholder.
///
/// Ici l'opération tourne dans une tâche non structurée : si elle ne répond pas,
/// elle est simplement abandonnée (l'extension est éphémère) et l'appelant reçoit
/// `fallback` à l'échéance.
func withTimeout<T>(seconds: Double,
                    fallback: T,
                    operation: @escaping () async -> T) async -> T {
    let box = SingleResume<T>()
    return await withCheckedContinuation { continuation in
        box.attach(continuation)
        Task { box.resolve(await operation()) }
        DispatchQueue.global().asyncAfter(deadline: .now() + seconds) { box.resolve(fallback) }
    }
}

/// Garantit qu'une continuation est reprise exactement une fois, quel que soit
/// le nombre de candidats en course.
private final class SingleResume<T>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<T, Never>?

    func attach(_ continuation: CheckedContinuation<T, Never>) {
        lock.lock(); defer { lock.unlock() }
        self.continuation = continuation
    }

    func resolve(_ value: T) {
        lock.lock()
        let pending = continuation
        continuation = nil
        lock.unlock()
        pending?.resume(returning: value)
    }
}

enum DateParsing {
    /// Le format des heures renvoyées par OJP, en UTC.
    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter
    }()

    static func date(from string: String) -> Date? {
        formatter.date(from: string)
    }
}
