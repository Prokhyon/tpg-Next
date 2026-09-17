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
}
