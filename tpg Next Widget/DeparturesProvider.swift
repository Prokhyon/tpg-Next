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
    /// Aperçu du sélecteur de widgets : les départs sont des exemples, ce qui compte est de
    /// reconnaître le réglage (sur la montre, l'arrêt le plus proche ou tel favori).
    var isGalleryPreview = false

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

    /// L'aperçu de la galerie : départs d'exemple, mais au nom de l'arrêt réglé. Sur la montre,
    /// chaque favori y est proposé ; avec le même arrêt d'exemple, ils semblaient tous identiques.
    private func preview(for configuration: SelectStopIntent) -> DeparturesEntry {
        guard let stop = configuration.selection.stop else {
            return DeparturesEntry(date: Date(), stop: PreviewData.stop, events: PreviewData.events, status: .ok, distance: 120,
                                   isGalleryPreview: true)
        }
        return DeparturesEntry(date: Date(), stop: stop, events: PreviewData.events, status: .ok, distance: nil,
                               isGalleryPreview: true)
    }

    /// Vrai quand le code tourne dans l'agent d'aperçu de Xcode, où ni la
    /// localisation ni le réseau ne sont souhaitables.
    static var isRunningInPreviewCanvas: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }

    #if os(watchOS)
    /// La montre ne propose pas de régler un widget : elle offre ces configurations toutes faites,
    /// l'arrêt le plus proche puis les quatre premiers favoris. Chacune apparaît une fois par
    /// format : au-delà, le sélecteur en compte des dizaines. Leur aperçu (`isGalleryPreview`)
    /// montre de quel arrêt il s'agit.
    func recommendations() -> [AppIntentRecommendation<SelectStopIntent>] {
        let stops = [StopEntity.automatic] + FavoritesStorage.load().prefix(4).map { StopEntity(stop: $0.fallbackStop) }
        return stops.map { entity in
            let intent = SelectStopIntent()
            intent.stop = entity
            let description: LocalizedStringResource = entity.isAutomatic ? "Arrêt le plus proche" : "Favori : \(entity.name)"
            return AppIntentRecommendation(intent: intent, description: description)
        }
    }
    #endif

    func snapshot(for configuration: SelectStopIntent, in context: Context) async -> DeparturesEntry {
        // La galerie de widgets doit montrer quelque chose immédiatement.
        guard !context.isPreview, !Self.isRunningInPreviewCanvas else { return preview(for: configuration) }
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
            let sorted = events.sortedByDeparture()
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
        guard let departure = event.departureDate else {
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

    /// `nil` en cas d'échec réseau, vide si l'arrêt n'a pas de départ. La requête a son
    /// propre délai d'attente et se termine toujours : plus besoin de la borner ici.
    private func fetchDepartures(for stop: Stop) async -> [StopEvent]? {
        // Sans la base des arrêts, les noms officiels des destinations viennent de l'index.
        if StopNames.resolve == nil, let reader = StopIndexReader() {
            StopNames.resolve = { reader.stop(sloid: $0)?.name }
        }
        do {
            return try await fetchStopEvents(stopName: stop.name, stopSloid: stop.sloid, count: requestedDepartures).events
        } catch is ParserError {
            return []
        } catch {
            return nil
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
                #if os(watchOS)
                // Pas d'`isAuthorizedForWidgetUpdates` sur la montre : l'extension partage
                // l'autorisation de l'app.
                let status = CLLocationManager().authorizationStatus
                continuation.resume(returning: status == .authorizedWhenInUse || status == .authorizedAlways)
                #else
                continuation.resume(returning: CLLocationManager().isAuthorizedForWidgetUpdates)
                #endif
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
        Log.location.error("Position du widget indisponible : \(error.localizedDescription)")
        result.resolve(nil)
    }
}

// MARK: - Utilitaires

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
