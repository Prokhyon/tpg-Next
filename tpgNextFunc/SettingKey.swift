//
//  SettingKey.swift
//  tpgNextFunc
//

import Foundation

/// Les clés des réglages (`@AppStorage`), réunies pour ne plus les recopier à la main.
///
/// Les valeurs sont celles déjà enregistrées sur les appareils des utilisateurs :
/// les corriger ferait perdre les réglages existants.
public enum SettingKey {
    /// Départs de l'accueil : favoris plutôt qu'arrêts proches.
    public static let homeShowsFavorites = "homeFavorites"
    /// Départs regroupés par ligne à l'ouverture d'un arrêt. La faute est d'origine.
    public static let groupByLineByDefault = "GoupedDefault"
    /// Heure de passage plutôt que minutes restantes, par défaut.
    public static let clockTimeByDefault = "TimeDefault"
    /// Retard intégré à l'heure (12:34) plutôt qu'affiché à côté (12:31 (+3')).
    public static let delayIncludedInTime = "DelayTimeIntegrated"
    public static let showWelcome = "ShowWelcome"
    public static let notificationAsked = "NotificationAsked"
    /// Alertes de retard et activités en direct des trajets réguliers sur cet appareil. Propre à
    /// chaque appareil : les trajets sont partagés par iCloud, pas ce réglage.
    public static let regularTripAlertsOnThisDevice = "RegularTripAlertsOnThisDevice"
    /// Rappels avant le départ des trajets réguliers sur cet appareil (le délai se règle par trajet).
    public static let regularTripRemindersOnThisDevice = "RegularTripRemindersOnThisDevice"
    /// Minutes avant l'heure de partir d'un itinéraire enregistré où un rappel est envoyé ; -1 : jamais.
    public static let savedTripReminderMinutes = "SavedTripReminderMinutes"
    /// Les transporteurs dont on veut voir les lignes (identifiants ATLAS séparés par des virgules).
    public static let lineOperators = "LineOperators"
    /// L'ordre des sections de l'accueil (`HomeSection`, séparées par des virgules).
    public static let homeSectionsOrder = "HomeSectionsOrder"
    /// Les sections masquées de l'accueil (`HomeSection`, séparées par des virgules).
    public static let homeHiddenSections = "HomeHiddenSections"
    /// Minutes avant le départ d'un itinéraire enregistré où son suivi en direct démarre ; 0 : jamais.
    public static let savedTripAutoTrackMinutes = "SavedTripAutoTrackMinutes"
    /// Le transporteur affiché dans la liste des lignes.
    public static let selectedLineOperator = "SelectedLineOperator"
}
