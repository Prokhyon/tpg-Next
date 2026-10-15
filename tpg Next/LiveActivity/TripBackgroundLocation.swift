//
//  TripBackgroundLocation.swift
//  tpg Next
//
//  Garder l'app en vie pendant un trajet suivi, pour que l'activité en direct suive.
//

import Foundation
import CoreLocation
import Observation
import tpgNextFunc

/// Sans serveur de notifications push, seule l'app peut mettre une activité en direct à jour —
/// et iOS la suspend dès qu'on la quitte. Une session d'activité d'arrière-plan
/// (`CLBackgroundActivitySession`) la laisse tourner tant qu'un trajet est suivi : les positions
/// arrivent, l'app relit les horaires, l'activité reste juste.
///
/// Ce que ça coûte : l'indicateur bleu de localisation pendant tout le suivi, et de la batterie.
/// La session ne s'ouvre donc que pour un trajet suivi, et se referme au dernier terminé. Sans
/// autorisation de localisation, rien ne s'ouvre : l'app retombe sur les réveils d'iOS.
@MainActor
@Observable
final class TripBackgroundLocation {
    static let shared = TripBackgroundLocation()

    /// La dernière position reçue, pour corriger l'heure du véhicule occupé.
    private(set) var lastLocation: CLLocation?
    /// Vrai tant que l'app est tenue éveillée.
    private(set) var isRunning = false

    /// Le flux de positions sert aussi d'horloge : une relecture des horaires au plus par minute.
    @ObservationIgnored private var lastRefresh = Date.distantPast
    @ObservationIgnored private var refreshing = false
    @ObservationIgnored private var session: CLBackgroundActivitySession?
    @ObservationIgnored private var updates: Task<Void, Never>?

    private init() {}

    /// Ouvre la session, si la localisation est déjà autorisée. L'autorisation vient de
    /// l'appelant (`TripLiveActivities.hasLocation`, tirée d'un délégué) : celle d'un
    /// `CLLocationManager()` neuf attend le service de localisation sur le fil principal, et
    /// l'app restait figée quand il ne répondait pas.
    func start(locationAuthorized: Bool) {
        guard !isRunning, locationAuthorized else { return }
        isRunning = true
        session = CLBackgroundActivitySession()
        Log.location.info("Suivi de trajet : session d'arrière-plan ouverte")
        updates = Task { [weak self] in
            do {
                for try await update in CLLocationUpdate.liveUpdates() {
                    if Task.isCancelled { break }
                    await self?.received(update.location)
                }
            } catch {
                Log.location.error("Positions du suivi interrompues : \(error.localizedDescription)")
            }
            await self?.stop()
        }
    }

    /// Referme la session : l'indicateur bleu disparaît, et iOS peut suspendre l'app.
    func stop() {
        guard isRunning else { return }
        isRunning = false
        updates?.cancel()
        updates = nil
        session?.invalidate()
        session = nil
        lastLocation = nil
        Log.location.info("Suivi de trajet : session d'arrière-plan fermée")
    }

    private func received(_ location: CLLocation?) async {
        if let location, location.horizontalAccuracy >= 0 { lastLocation = location }
        // L'app est réveillée : autant relire les horaires et redessiner les activités.
        let now = Date()
        guard !refreshing, now.timeIntervalSince(lastRefresh) >= 60 else { return }
        lastRefresh = now
        refreshing = true
        await RegularTripsModel.shared.refresh(now: now)
        refreshing = false
    }
}
