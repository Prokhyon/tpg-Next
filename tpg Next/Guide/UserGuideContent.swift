//
//  UserGuideContent.swift
//  tpg Next
//
//  Le contenu du guide d'utilisation (Paramètres → Guide d'utilisation). Seulement du texte :
//  l'affichage est dans UserGuideView.swift.
//
//  Pour compléter le guide :
//  - un point de plus : ajouter un `GuideEntry` dans la rubrique voulue ;
//  - une rubrique de plus : ajouter un `GuideTopic` (identifiant unique) dans un groupe ;
//  - `link` ajoute sous le point un bouton vers l'écran concerné (`AppRoute`) ;
//  - `demo` y ajoute une démonstration à essayer du doigt (`GuideDemo`).
//  Les titres d'une même rubrique doivent rester différents : ils servent à retrouver un point
//  depuis la recherche du guide.
//

import SwiftUI

struct GuideGroup: Identifiable {
    let title: LocalizedStringResource
    let topics: [GuideTopic]

    var id: String { topics.first?.id ?? "" }
}

struct GuideTopic: Identifiable, Hashable {
    let id: String
    let title: LocalizedStringResource
    let systemImage: String
    let color: Color
    /// Une ligne sous le titre, dans la liste des rubriques.
    let summary: LocalizedStringResource
    let entries: [GuideEntry]

    static func == (lhs: GuideTopic, rhs: GuideTopic) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct GuideEntry: Identifiable {
    let systemImage: String
    let title: LocalizedStringResource
    let text: LocalizedStringResource
    var link: GuideLink? = nil
    /// Une démonstration à essayer sous le texte (GuideDemos.swift).
    var demo: GuideDemo? = nil

    var id: String { String(localized: title) }
}

/// Un bouton sous le point, vers l'écran dont il parle.
struct GuideLink {
    let title: LocalizedStringResource
    let route: AppRoute
}

enum UserGuide {
    static func topic(id: String) -> GuideTopic? {
        groups.lazy.flatMap(\.topics).first { $0.id == id }
    }

    static let groups: [GuideGroup] = [
        GuideGroup(title: "Premiers pas", topics: [gettingStarted]),
        GuideGroup(title: "Consulter les départs", topics: [home, stop, lines, map]),
        GuideGroup(title: "Se déplacer", topics: [tripSearch, explore]),
        GuideGroup(title: "Mes trajets", topics: [savedTrips, regularTrips, liveTracking]),
        GuideGroup(title: "Être prévenu", topics: [notifications]),
        GuideGroup(title: "Au-delà de l'app", topics: [widgets, watch, iCloud, iPad]),
        GuideGroup(title: "Réglages", topics: [settings]),
    ]

    // MARK: Premiers pas

    static let gettingStarted = GuideTopic(
        id: "start",
        title: "Bien démarrer",
        systemImage: "hand.wave.fill",
        color: .orange,
        summary: "Autorisations, onglets et gestes à connaître.",
        entries: [
            GuideEntry(systemImage: "location.fill",
                       title: "Localisation",
                       text: "Elle affiche les arrêts proches sur l'accueil et votre position sur la carte, et permet de partir de là où vous êtes. Pendant un suivi en direct, elle garde l'activité à jour. Vous pouvez la changer à tout moment dans les réglages d'iOS."),
            GuideEntry(systemImage: "bell.badge.fill",
                       title: "Notifications",
                       text: "Elles servent aux rappels de départ, aux alertes de retard des trajets réguliers et aux alertes pendant un suivi en direct : monter, descendre, arriver."),
            GuideEntry(systemImage: "square.grid.2x2.fill",
                       title: "Les onglets",
                       text: "Accueil : prochain trajet, favoris, lieux favoris, départs et carte. Itinéraire : aller d'un point à un autre. Trajets : vos itinéraires enregistrés et trajets réguliers. La loupe (Explorer) : chercher un arrêt, un lieu ou une ligne."),
            GuideEntry(systemImage: "hand.tap.fill",
                       title: "L'appui long",
                       text: "Arrêts, départs et trajets cachent un menu : appuyez longuement pour programmer un rappel, suivre un départ en direct, partir d'un arrêt ou y aller, ou modifier un trajet."),
            GuideEntry(systemImage: "star.fill",
                       title: "Les favoris",
                       text: "Touchez l'étoile d'un résultat de recherche, ou passez par le menu « … » d'une page d'arrêt. Vos favoris apparaissent sur l'accueil et dans l'onglet Itinéraire, dans l'ordre que vous choisissez.",
                       link: GuideLink(title: "Arrêts favoris", route: .favoritesOrder),
                       demo: .favorite),
            GuideEntry(systemImage: "mappin.circle.fill",
                       title: "Les lieux favoris",
                       text: "Une adresse ou un lieu que vous rejoignez souvent : touchez son étoile dans Explorer, ou dans sa fiche. Il apparaît sur l'accueil et dans l'onglet Itinéraire. Donnez-lui un nom (« Maison », « Travail ») d'un appui long.",
                       link: GuideLink(title: "Lieux favoris", route: .favoritePlacesOrder)),
        ]
    )

    // MARK: Consulter les départs

    static let home = GuideTopic(
        id: "home",
        title: "Accueil",
        systemImage: "house.fill",
        color: .blue,
        summary: "Prochain trajet, favoris, lieux favoris, départs et carte des environs.",
        entries: [
            GuideEntry(systemImage: "clock.fill",
                       title: "Prochain trajet",
                       text: "Votre prochain trajet régulier ou itinéraire enregistré des 12 prochaines heures : ligne, heure de départ, quai et temps réel. L'heure en grand est toujours celle du véhicule ; s'il faut marcher jusqu'à l'arrêt, une ligne à part dit quand partir, par exemple « Partir dans 3 min · 5 min à pied jusqu'à Rive ». Depuis la carte, suivez le trajet en direct ou choisissez un autre horaire."),
            GuideEntry(systemImage: "star.fill",
                       title: "Favoris",
                       text: "Touchez un favori pour ouvrir ses départs ; appuyez longuement pour partir de là ou y aller. Sans favori, la case en pointillés ouvre Explorer."),
            GuideEntry(systemImage: "mappin.circle.fill",
                       title: "Lieux favoris",
                       text: "Touchez un lieu pour chercher tout de suite l'itinéraire depuis votre position. Appuyez longuement pour en partir, le voir sur la carte, le renommer ou le retirer."),
            GuideEntry(systemImage: "bell.fill",
                       title: "Rappels prévus",
                       text: "La cloche, en haut à droite, liste les rappels de départ programmés : touchez la croix pour en annuler un.",
                       link: GuideLink(title: "Rappels prévus", route: .scheduledNotifications)),
            GuideEntry(systemImage: "list.bullet.rectangle.fill",
                       title: "Départs",
                       text: "Les départs des arrêts proches de vous, ou de vos favoris (au choix dans les paramètres). Sur iPhone, balayez pour passer d'un arrêt à l'autre. Sur iPad, les arrêts sont les uns sous les autres : touchez un nom pour le déplier, puis touchez-le à nouveau pour ouvrir l'arrêt. Le bouton à droite du nom lance un itinéraire depuis cet arrêt."),
            GuideEntry(systemImage: "map.fill",
                       title: "Autour de vous",
                       text: "La carte des arrêts affichés. Celui dont vous voyez les départs y est mis en évidence : touchez-en un autre pour afficher ses départs. Touchez ailleurs sur la carte, ou le bouton d'agrandissement, pour l'ouvrir en plein écran."),
            GuideEntry(systemImage: "rectangle.3.group.fill",
                       title: "Organiser l'accueil",
                       text: "Placez les sections dans l'ordre qui vous convient.",
                       link: GuideLink(title: "Organiser l'accueil", route: .homeLayout)),
        ]
    )

    static let stop = GuideTopic(
        id: "stop",
        title: "Page d'un arrêt",
        systemImage: "mappin.and.ellipse",
        color: .red,
        summary: "Départs en temps réel, filtres, rappels et courses.",
        entries: [
            GuideEntry(systemImage: "list.bullet",
                       title: "Les départs",
                       text: "Les prochains départs, en temps réel. Un symbole signale un départ perturbé, un horaire exceptionnel ou un parcours modifié."),
            GuideEntry(systemImage: "hourglass",
                       title: "Heure ou minutes",
                       text: "Le sablier, en haut de la page, alterne entre l'heure de départ (12:34) et le temps restant (14'). Le choix par défaut se règle dans les paramètres, comme l'affichage du retard.",
                       demo: .departureTime),
            GuideEntry(systemImage: "rectangle.grid.1x2.fill",
                       title: "Tri par horaire ou par ligne",
                       text: "Rangez les départs dans l'ordre de passage, ou regroupés par ligne et destination.",
                       demo: .sortAndFilter),
            GuideEntry(systemImage: "line.3.horizontal.decrease.circle.fill",
                       title: "Filtrer",
                       text: "Le bouton de filtre, en bas, ouvre les lignes de l'arrêt : touchez-en une pour ne garder qu'elle. Si elle a plusieurs directions, une bulle au-dessus permet de choisir la bonne. La liste se filtre aussitôt ; ↺ remet toutes les lignes, ✓ ou un toucher ailleurs referme les lignes."),
            GuideEntry(systemImage: "clock.arrow.2.circlepath",
                       title: "Plus tôt, plus tard",
                       text: "Les flèches en bas à droite affichent les départs précédents ou suivants. Pour une heure précise, touchez l'horloge entre elles : choisissez le jour, puis l'heure, et validez avec ✓. « Maintenant » revient à l'heure actuelle ; l'horloge reste orange tant que la liste n'y est pas.",
                       demo: .earlierLater),
            GuideEntry(systemImage: "bus.fill",
                       title: "La course d'un départ",
                       text: "Touchez un départ pour voir tous les arrêts de sa course, où se trouve le véhicule et le tracé de la ligne sur la carte."),
            GuideEntry(systemImage: "bell.fill",
                       title: "Rappel d'un départ",
                       text: "Appuyez longuement sur un départ : prévenir à l'arrivée du véhicule, ou 1, 5, 10 ou 30 minutes avant. Le rappel suit le temps réel, et vous êtes prévenu si le véhicule prend de l'avance ou du retard.",
                       demo: .reminder),
            GuideEntry(systemImage: "inset.filled.circle",
                       title: "Suivre un départ en direct",
                       text: "Dans le même menu, « Suivre en direct » : indiquez où vous montez et où vous descendez, puis suivez la course sur l'écran verrouillé."),
            GuideEntry(systemImage: "ellipsis.circle.fill",
                       title: "Le menu « … »",
                       text: "Ajouter l'arrêt aux favoris, afficher la carte des quais, ou lancer un itinéraire : Partir d'ici, Aller ici, ou Trajet rapide (depuis votre position, tout de suite).",
                       demo: .tripActions),
            GuideEntry(systemImage: "signpost.right.and.left.fill",
                       title: "Carte des quais",
                       text: "Les lignes et quais de l'arrêt. Touchez une ligne ou un quai pour filtrer les départs, un départ pour voir son parcours."),
        ]
    )

    static let lines = GuideTopic(
        id: "lines",
        title: "Lignes",
        systemImage: "tram.fill",
        color: .purple,
        summary: "Toutes les lignes, pour les transporteurs de votre choix.",
        entries: [
            GuideEntry(systemImage: "square.grid.3x3.fill",
                       title: "Toutes les lignes",
                       text: "Dans Explorer, « Lignes » les range par genre : tram, bus, train, bateau… Touchez un numéro pour ouvrir la ligne : ses terminus, ses prochains départs et son parcours.",
                       link: GuideLink(title: "Ouvrir les lignes", route: .lines)),
            GuideEntry(systemImage: "building.2.fill",
                       title: "Vos transporteurs",
                       text: "L'app couvre toute la Suisse. Touchez « Ajouter » pour choisir les transporteurs qui vous intéressent, puis passez de l'un à l'autre d'un toucher. La recherche de lignes se limite à vos transporteurs."),
            GuideEntry(systemImage: "arrow.triangle.branch",
                       title: "Un numéro, plusieurs lignes",
                       text: "Quand un même numéro désigne plusieurs parcours, un menu vous laisse choisir le bon."),
        ]
    )

    static let map = GuideTopic(
        id: "map",
        title: "Carte",
        systemImage: "map.fill",
        color: .green,
        summary: "Les arrêts autour de vous, leurs quais et leurs départs.",
        entries: [
            GuideEntry(systemImage: "arrow.up.left.and.arrow.down.right",
                       title: "En plein écran",
                       text: "Ouvrez la carte depuis la section « Autour de vous » de l'accueil. Touchez un arrêt : ses quais apparaissent, avec leurs départs."),
            GuideEntry(systemImage: "point.bottomleft.forward.to.point.topright.scurvepath.fill",
                       title: "Un itinéraire depuis la carte",
                       text: "Lancez un itinéraire depuis un arrêt de la carte : elle se ferme et l'onglet Itinéraire prend le relais."),
        ]
    )

    // MARK: Se déplacer

    static let tripSearch = GuideTopic(
        id: "trip",
        title: "Chercher un itinéraire",
        systemImage: "point.bottomleft.forward.to.point.topright.scurvepath.fill",
        color: .teal,
        summary: "D'un arrêt, d'une adresse ou de votre position, à l'heure voulue.",
        entries: [
            GuideEntry(systemImage: "mappin.circle.fill",
                       title: "Départ et arrivée",
                       text: "Dans l'onglet Itinéraire, touchez un champ et cherchez un arrêt, une adresse ou un lieu. Vos arrêts et lieux favoris sont proposés d'un toucher, et « Utiliser la position actuelle » part de là où vous êtes. Le bouton ⇅ échange départ et arrivée."),
            GuideEntry(systemImage: "calendar",
                       title: "Date et heure",
                       text: "Choisissez de partir à une heure, ou d'arriver avant une heure, puis lancez la recherche."),
            GuideEntry(systemImage: "bolt.fill",
                       title: "Depuis n'importe où",
                       text: "Partir d'ici, Aller ici et Trajet rapide sont proposés sur les arrêts : menu « … » d'un arrêt, appui long sur un favori, fiche d'un lieu. Trajet rapide cherche tout de suite depuis votre position."),
            GuideEntry(systemImage: "timeline.selection",
                       title: "Les résultats",
                       text: "Chaque itinéraire montre sur une frise ses lignes, changements, marches et attentes, avec les heures de départ et d'arrivée et les retards. Touchez-en un pour le détail."),
            GuideEntry(systemImage: "list.number",
                       title: "Le détail",
                       text: "Les étapes, arrêts de montée et de descente, quais et correspondances, avec la carte du trajet. Une correspondance serrée est signalée."),
            GuideEntry(systemImage: "bookmark.fill",
                       title: "Garder un itinéraire",
                       text: "Depuis le détail, ou d'un appui long sur un résultat : Enregistrer l'itinéraire (il rejoint l'onglet Trajets), Répéter chaque semaine pour en faire un trajet régulier, ou Suivre en direct."),
        ]
    )

    static let explore = GuideTopic(
        id: "explore",
        title: "Explorer",
        systemImage: "magnifyingglass",
        color: .indigo,
        summary: "Un seul champ pour les arrêts, les lieux, les lignes et vos trajets.",
        entries: [
            GuideEntry(systemImage: "text.magnifyingglass",
                       title: "Un seul champ",
                       text: "Tapez un nom d'arrêt, une adresse, un commerce ou un numéro de ligne."),
            GuideEntry(systemImage: "clock.arrow.circlepath",
                       title: "Sans rien taper",
                       text: "Vos recherches récentes, vos trajets réguliers et enregistrés, les arrêts proches et la liste des lignes."),
            GuideEntry(systemImage: "map.circle.fill",
                       title: "Aperçu d'un lieu",
                       text: "Touchez l'icône à droite d'un résultat pour voir sa position sur une carte, puis Y aller ou Partir d'ici. L'étoile ajoute un arrêt à vos favoris, ou un lieu à vos lieux favoris.",
                       demo: .favorite),
            GuideEntry(systemImage: "arrow.uturn.left.circle.fill",
                       title: "Aller et retour",
                       text: "Appuyez longuement sur un trajet régulier : Chercher maintenant, ou Retour maintenant pour le trajet inverse."),
        ]
    )

    // MARK: Mes trajets

    static let savedTrips = GuideTopic(
        id: "saved",
        title: "Itinéraires enregistrés",
        systemImage: "bookmark.fill",
        color: .orange,
        summary: "Un trajet précis, gardé sous la main et suivi en temps réel.",
        entries: [
            GuideEntry(systemImage: "plus.circle.fill",
                       title: "Enregistrer",
                       text: "Depuis le détail d'un itinéraire, ou d'un appui long sur un résultat. Il rejoint l'onglet Trajets, rangé par jour. Filtrez en haut : Tous, Enregistrés, Réguliers."),
            GuideEntry(systemImage: "antenna.radiowaves.left.and.right",
                       title: "Temps réel",
                       text: "À l'approche du départ, l'app relit l'itinéraire : un retard, un horaire modifié ou une course supprimée s'affichent sur le trajet."),
            GuideEntry(systemImage: "clock.badge.questionmark.fill",
                       title: "Autres horaires",
                       text: "Appui long → Autres horaires… pour le remplacer par un itinéraire proche de la même heure."),
            GuideEntry(systemImage: "calendar.badge.plus",
                       title: "Répéter chaque semaine",
                       text: "Appui long → Répéter chaque semaine… pour en faire un trajet régulier."),
            GuideEntry(systemImage: "trash.fill",
                       title: "Itinéraires passés",
                       text: "Ils restent consultables, puis sont supprimés 30 jours après leur arrivée."),
            GuideEntry(systemImage: "bell.fill",
                       title: "Rappel et suivi automatiques",
                       text: "Dans les paramètres, choisissez un rappel avant l'heure de partir, et le suivi en direct lancé de lui-même avant le départ."),
        ]
    )

    static let regularTrips = GuideTopic(
        id: "regular",
        title: "Trajets réguliers",
        systemImage: "repeat",
        color: .mint,
        summary: "Vos trajets de chaque semaine, reconnus chaque jour.",
        entries: [
            GuideEntry(systemImage: "calendar.badge.plus",
                       title: "Créer un trajet",
                       text: "Onglet Trajets → Nouveau trajet régulier : départ, arrivée, jours et heure. Ou depuis un itinéraire : Répéter chaque semaine…"),
            GuideEntry(systemImage: "clock.fill",
                       title: "Heure de départ ou d'arrivée",
                       text: "Retenez l'heure de montée à bord, ou l'heure où vous voulez être arrivé."),
            GuideEntry(systemImage: "arrow.triangle.swap",
                       title: "Toujours ces lignes",
                       text: "Activé, l'app retrouve chaque jour vos lignes et vous prévient si elles ne sont pas proposées, avec une alternative. Désactivé, elle propose le meilleur itinéraire du moment."),
            GuideEntry(systemImage: "calendar.badge.clock",
                       title: "Jusqu'à une date",
                       text: "Pour un trajet temporaire, choisissez un dernier jour."),
            GuideEntry(systemImage: "bell.badge.fill",
                       title: "Notifications",
                       text: "Pour chaque trajet : un rappel avant le départ, qui suit l'heure réelle ; les alertes de retard et de changement, dans l'heure et demie qui précède ; et l'activité en direct, 20 minutes avant le départ si l'app est ouverte."),
            GuideEntry(systemImage: "arrow.left.arrow.right",
                       title: "Un jour pas comme les autres",
                       text: "Appuyez longuement sur le trajet du jour : Choisir un autre trajet… pour ce jour-là seulement, puis Revenir au trajet habituel si besoin."),
            GuideEntry(systemImage: "iphone.and.arrow.forward",
                       title: "Plusieurs appareils",
                       text: "Vos trajets réguliers arrivent sur tous vos appareils par iCloud, mais les notifications se règlent sur chacun : activez-les sur un seul pour ne pas être prévenu en double."),
        ]
    )

    static let liveTracking = GuideTopic(
        id: "live",
        title: "Suivi en direct",
        systemImage: "inset.filled.circle",
        color: .green,
        summary: "Votre trajet sur l'écran verrouillé, étape par étape.",
        entries: [
            GuideEntry(systemImage: "play.circle.fill",
                       title: "Lancer le suivi",
                       text: "« Suivre en direct » depuis un itinéraire, le prochain trajet de l'accueil, un itinéraire enregistré ou un départ (appui long, puis choix de la montée et de la descente)."),
            GuideEntry(systemImage: "lock.iphone",
                       title: "Sur l'écran verrouillé",
                       text: "L'activité montre l'étape en cours, les comptes à rebours et l'heure d'arrivée. Touchez-la pour ouvrir le trajet en entier."),
            GuideEntry(systemImage: "bell.and.waves.left.and.right.fill",
                       title: "Les alertes",
                       text: "Une minute avant l'arrivée du véhicule, deux minutes avant l'arrêt où descendre, et à l'arrivée. Elles suivent les retards."),
            GuideEntry(systemImage: "questionmark.bubble.fill",
                       title: "Je suis monté, je l'ai manqué",
                       text: "Quand une correspondance est serrée, l'activité vous demande si vous êtes monté. Répondez depuis l'écran verrouillé : la suite du trajet s'adapte.",
                       demo: .liveTracking),
            GuideEntry(systemImage: "location.fill",
                       title: "Avec votre position",
                       text: "Si la localisation est autorisée, l'app reste active pendant le suivi (indicateur bleu) et ajuste l'heure du véhicule où vous êtes. Cela consomme un peu de batterie."),
            GuideEntry(systemImage: "stop.circle.fill",
                       title: "Arrêter",
                       text: "« Arrêter le suivi » depuis le trajet ; le suivi se termine aussi de lui-même à l'arrivée."),
            GuideEntry(systemImage: "wand.and.stars",
                       title: "Suivi automatique",
                       text: "Trajets réguliers : activé dans chaque trajet. Itinéraires enregistrés : dans les paramètres. iOS ne laisse démarrer une activité que l'app ouverte : une notification vous invite à l'ouvrir au bon moment."),
        ]
    )

    // MARK: Être prévenu

    static let notifications = GuideTopic(
        id: "notifications",
        title: "Rappels et notifications",
        systemImage: "bell.fill",
        color: .red,
        summary: "Ne plus rater un départ, sans être prévenu deux fois.",
        entries: [
            GuideEntry(systemImage: "hand.tap.fill",
                       title: "Le rappel d'un départ",
                       text: "Appuyez longuement sur un départ, sur la page d'un arrêt, puis choisissez quand être prévenu. Retrouvez et annulez vos rappels depuis la cloche, en haut de l'accueil.",
                       link: GuideLink(title: "Rappels prévus", route: .scheduledNotifications)),
            GuideEntry(systemImage: "repeat",
                       title: "Trajets réguliers",
                       text: "Le délai du rappel se choisit dans chaque trajet ; les rappels, et les alertes de retard, s'activent pour cet appareil dans les paramètres."),
            GuideEntry(systemImage: "bookmark.fill",
                       title: "Itinéraires enregistrés",
                       text: "Un seul réglage pour tous : à l'heure de partir, ou 5, 10, 15 ou 30 minutes avant (Paramètres → Itinéraires enregistrés)."),
            GuideEntry(systemImage: "figure.walk",
                       title: "Quand partir",
                       text: "S'il faut marcher jusqu'à l'arrêt, le rappel dit « Partir dans 10 min · 5 min à pied ». Sans marche : « Départ dans 10 min ». Le temps de marche n'est jamais caché dans l'heure du départ."),
            GuideEntry(systemImage: "ipad.and.iphone",
                       title: "Propres à chaque appareil",
                       text: "Vos trajets sont partagés par iCloud, pas vos réglages de notifications. Pour les trajets réguliers, l'iPhone prévient par défaut, l'iPad non."),
        ]
    )

    // MARK: Au-delà de l'app

    static let widgets = GuideTopic(
        id: "widgets",
        title: "Widgets",
        systemImage: "widget.medium",
        color: .blue,
        summary: "Les départs et votre prochain trajet, sans ouvrir l'app.",
        entries: [
            GuideEntry(systemImage: "list.bullet.rectangle.portrait.fill",
                       title: "Prochains départs",
                       text: "En trois tailles : les départs d'un arrêt choisi, ou de l'arrêt le plus proche de vous. Appuyez longuement sur le widget → Modifier le widget pour choisir l'arrêt."),
            GuideEntry(systemImage: "clock.fill",
                       title: "Prochain trajet",
                       text: "Quand partir pour votre prochain trajet régulier ou itinéraire enregistré, jusqu'à 36 heures à l'avance. Il existe aussi pour l'écran verrouillé."),
            GuideEntry(systemImage: "plus.square.on.square",
                       title: "Ajouter un widget",
                       text: "Appuyez longuement sur l'écran d'accueil → Modifier → Ajouter un widget, puis cherchez tpg Next."),
        ]
    )

    static let watch = GuideTopic(
        id: "watch",
        title: "Apple Watch",
        systemImage: "applewatch",
        color: .gray,
        summary: "Les départs proches et vos favoris au poignet.",
        entries: [
            GuideEntry(systemImage: "location.fill",
                       title: "Arrêts proches",
                       text: "L'app de la montre affiche les départs de l'arrêt le plus proche, et vous laisse choisir parmi les autres arrêts proches."),
            GuideEntry(systemImage: "star.fill",
                       title: "Favoris",
                       text: "Vos favoris arrivent de l'iPhone : modifiez-les sur l'iPhone, la montre suit."),
        ]
    )

    static let iCloud = GuideTopic(
        id: "icloud",
        title: "iCloud et appareils",
        systemImage: "icloud.fill",
        color: .cyan,
        summary: "Ce qui suit d'un appareil à l'autre, et ce qui reste sur chacun.",
        entries: [
            GuideEntry(systemImage: "arrow.triangle.2.circlepath.icloud.fill",
                       title: "Synchronisé",
                       text: "Favoris, lieux favoris, itinéraires enregistrés et trajets réguliers, sur tous vos appareils connectés au même compte iCloud."),
            GuideEntry(systemImage: "icloud.slash.fill",
                       title: "Activer ou couper",
                       text: "La synchronisation se choisit au premier lancement, puis dans les paramètres (Vos données). Coupée, vos favoris et trajets restent sur cet appareil ; ce qui est déjà dans iCloud n'est pas effacé.",
                       link: GuideLink(title: "Paramètres", route: .settings)),
            GuideEntry(systemImage: "gearshape.fill",
                       title: "Propre à chaque appareil",
                       text: "Les réglages : affichage des départs, organisation de l'accueil, notifications, transporteurs choisis."),
        ]
    )

    static let iPad = GuideTopic(
        id: "ipad",
        title: "Sur iPad",
        systemImage: "ipad.landscape",
        color: .gray,
        summary: "Tout à l'écran, en deux colonnes.",
        entries: [
            GuideEntry(systemImage: "rectangle.split.2x1.fill",
                       title: "Accueil sans défilement",
                       text: "Le prochain trajet, les favoris, les lieux favoris et la carte à gauche, les départs à droite. Les rappels prévus et les paramètres sont en haut à droite."),
            GuideEntry(systemImage: "sidebar.right",
                       title: "Pages en deux moitiés",
                       text: "Arrêts, lignes et itinéraires s'ouvrent en deux : la liste à gauche, le détail et sa carte à droite. Toucher un départ ou une étape l'affiche à droite sans quitter la liste."),
        ]
    )

    // MARK: Réglages

    static let settings = GuideTopic(
        id: "settings",
        title: "Paramètres",
        systemImage: "gearshape.fill",
        color: .gray,
        summary: "Ce que chaque réglage change.",
        entries: [
            GuideEntry(systemImage: "house.fill",
                       title: "Départs affichés sur l'accueil",
                       text: "Ceux des arrêts proches, ou ceux de vos favoris."),
            GuideEntry(systemImage: "rectangle.3.group.fill",
                       title: "Organiser l'accueil",
                       text: "L'ordre des sections de l'accueil, et celles à masquer.",
                       link: GuideLink(title: "Organiser l'accueil", route: .homeLayout)),
            GuideEntry(systemImage: "star.fill",
                       title: "Arrêts et lieux favoris",
                       text: "Leur ordre, glissé du doigt ; balayez pour en retirer un. Le crayon renomme un lieu.",
                       link: GuideLink(title: "Lieux favoris", route: .favoritePlacesOrder)),
            GuideEntry(systemImage: "text.justify",
                       title: "Affichage des départs",
                       text: "Le tri par défaut (horaire ou ligne), l'heure affichée par défaut (temps restant ou heure), et le format du retard : « 12:31 (+3') » ou l'heure réelle seule, « 12:34 »."),
            GuideEntry(systemImage: "bell.fill",
                       title: "Trajets réguliers et itinéraires enregistrés",
                       text: "Rappels, alertes de retard et suivi en direct automatique, pour cet appareil."),
        ]
    )
}
