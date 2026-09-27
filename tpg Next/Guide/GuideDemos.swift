//
//  GuideDemos.swift
//  tpg Next
//
//  Les démonstrations à essayer du doigt : dans la visite guidée (bienvenue) et sous certains
//  points du guide. Elles reprennent les vues de l'app (lignes de départ, cartes par ligne,
//  boutons de la page d'un arrêt) avec des départs factices ; seule l'étoile agit vraiment :
//  elle ajoute l'arrêt aux favoris.
//

import SwiftUI
import MapKit
import tpgNextFunc

enum GuideDemo: CaseIterable {
    case favorite, departureTime, reminder, sortAndFilter, earlierLater, tripActions, liveTracking

    /// Ce qu'il faut faire.
    var instruction: LocalizedStringResource {
        switch self {
        case .favorite: "Touchez l'étoile, puis l'icône à droite"
        case .departureTime: "Touchez le sablier"
        case .reminder: "Appuyez longuement sur le départ"
        case .sortAndFilter: "Touchez le bouton de tri, puis le filtre"
        case .earlierLater: "Touchez les flèches en bas à droite, puis l'horloge"
        case .tripActions: "Touchez le bouton d'itinéraire"
        case .liveTracking: "Répondez à la question"
        }
    }

    /// Ce qui s'est passé, une fois fait.
    var doneMessage: LocalizedStringResource {
        switch self {
        case .favorite: "Parfait : l'arrêt est dans vos favoris, et vous savez où il se trouve."
        case .departureTime: "Touchez encore pour revenir à l'autre affichage."
        case .reminder: "C'est tout ! (Ici, rien n'est vraiment programmé.)"
        case .sortAndFilter: "Voilà l'affichage par ligne. Retouchez les boutons pour revenir."
        case .earlierLater: "Bravo ! Les départs déjà passés s'affichent en gris."
        case .tripActions: "L'onglet Itinéraire s'ouvrirait, prêt à chercher."
        case .liveTracking: "La suite du trajet s'adapte à votre réponse."
        }
    }
}

/// Ce qu'une démonstration dit de l'avancée : une étape franchie (message d'encouragement pour
/// la suivante), ou tout fait.
private struct DemoReport {
    let advance: (LocalizedStringResource) -> Void
    let complete: () -> Void
}

/// Une démonstration dans son cadre, avec la consigne. Elle encourage à chaque étape, puis
/// confirme une fois tout fait.
struct GuideDemoView: View {
    let demo: GuideDemo
    var onDone: () -> Void = {}
    @State private var progress: LocalizedStringResource?
    @State private var isDone = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            stage
            GuideDemoHint(text: isDone ? demo.doneMessage : progress ?? demo.instruction,
                          state: isDone ? .done : progress == nil ? .start : .progress)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 26, style: .continuous).fill(Color(.secondarySystemBackground)))
        .sensoryFeedback(.success, trigger: isDone) { _, done in done }
    }

    private var report: DemoReport {
        DemoReport(advance: { message in
            guard !isDone else { return }
            withAnimation(.snappy) { progress = message }
        }, complete: {
            guard !isDone else { return }
            withAnimation(.snappy) { isDone = true }
            onDone()
        })
    }

    @ViewBuilder private var stage: some View {
        switch demo {
        case .favorite: FavoriteDemo(report: report)
        case .departureTime: DepartureTimeDemo(report: report)
        case .reminder: ReminderDemo(report: report)
        case .sortAndFilter: StopPageDemo(goal: .sortAndFilter, report: report)
        case .earlierLater: StopPageDemo(goal: .earlierLater, report: report)
        case .tripActions: TripActionsDemo(report: report)
        case .liveTracking: LiveTrackingDemo(report: report)
        }
    }
}

private struct GuideDemoHint: View {
    enum Phase {
        case start, progress, done
    }

    let text: LocalizedStringResource
    let state: Phase

    var body: some View {
        Label {
            Text(text)
        } icon: {
            Image(systemName: state == .done ? "checkmark.circle.fill" : state == .progress ? "hand.thumbsup.fill" : "hand.tap.fill")
                .symbolEffect(.pulse, isActive: state != .done)
        }
        .font(.subheadline.weight(.medium))
        .foregroundStyle(state == .done ? Color.green : Color.accentColor)
        .fixedSize(horizontal: false, vertical: true)
        .id(String(localized: text))
        .transition(.opacity)
    }
}

// MARK: Départs factices

private enum DemoData {
    static let stopName = "Genève, Plainpalais"
    static let sloid = "ch:1:sloid:guide-demo"
    static let operatorName = "Transports Publics Genevois"

    /// Un départ dans `minutes` minutes (négatif : déjà passé).
    static func departure(line: String, destination: String, quay: String, inMinutes minutes: Int,
                          transportType: String = "Tram") -> StopEvent {
        let now = Date.now
        let time = OJPDate.string(from: now.addingTimeInterval(TimeInterval(minutes * 60)))
        return StopEvent(stopPointName: stopName, stopId: sloid, plannedQuay: quay,
                         timetabledTime: time, estimatedTime: time,
                         lineName: line, origin: stopName, destination: destination,
                         transportType: transportType, operatorName: operatorName,
                         journeyRef: "guide-demo-\(line)-\(minutes)",
                         operatingDayRef: String(OJPDate.string(from: now).prefix(10)),
                         attributeCodes: ["A__NF"], ptMode: transportType.lowercased())
    }

    private static let lines: [(line: String, destination: String, quay: String, every: Int, first: Int)] = [
        ("12", "Genève, Moillesulaz", "A", 6, 1),
        ("15", "Genève, Nations", "B", 8, 3),
        ("18", "Meyrin, CERN", "B", 10, 5),
    ]

    /// Les départs des trois lignes entre `start` et `start + 25` minutes, dans l'ordre. Un
    /// horaire cadencé : il y a des départs à toute heure choisie.
    static func timetable(from start: Int) -> [StopEvent] {
        lines.flatMap { line in
            // Le premier passage à partir de `start`, arrondi à la cadence de la ligne.
            let first = line.first + Int((Double(start - line.first) / Double(line.every)).rounded(.up)) * line.every
            return stride(from: first, to: start + 25, by: line.every)
                .map { departure(line: line.line, destination: line.destination, quay: line.quay, inMinutes: $0) }
        }
        .sorted { $0.estimatedTime < $1.estimatedTime }
    }
}

// MARK: Favori et aperçu

private struct FavoriteDemo: View {
    @Environment(FavoritesViewModel.self) private var favorites
    let report: DemoReport
    @State private var mapItem: searchResultItem?
    @State private var starred = false
    @State private var sawMap = false

    private static let stop = Stop(name: "Genève, gare Cornavin", sloid: "ch:1:sloid:87057", codedidoc: "8587057",
                                   country: "CH", canton: "Genève", meansOfTransport: "BUS",
                                   wgs84Coordinates: Coordinates(lon: 46.20973474672, lat: 6.14243773412))
    private static let coordinate = CLLocationCoordinate2D(latitude: 46.20973474672, longitude: 6.14243773412)

    var body: some View {
        let isFavorite = favorites.isFavorite(Self.stop)
        HStack(spacing: 12) {
            Button {
                if isFavorite {
                    favorites.removeFavoriteStop(Self.stop)
                } else {
                    favorites.addFavorite(Self.stop)
                    starred = true
                    update()
                }
            } label: {
                Image(systemName: isFavorite ? "star.fill" : "star")
                    .font(.title3)
                    .contentTransition(.symbolEffect(.replace))
                    .symbolEffect(.pulse, isActive: !starred)
            }
            .foregroundStyle(.accent)
            .accessibilityLabel(isFavorite ? "Retirer des favoris" : "Ajouter aux favoris")
            SmallStopTitleView(stopName: Self.stop.name)
            Button {
                mapItem = searchResultItem(title: Self.stop.name, coordinates: Self.coordinate)
                sawMap = true
                update()
            } label: {
                Image(systemName: "figure.wave.circle")
                    .font(.title2)
                    .symbolEffect(.pulse, isActive: starred && !sawMap)
            }
            .foregroundStyle(.accent)
            .accessibilityLabel("Voir sur la carte")
        }
        .padding(.horizontal)
        .basicElementBackground(minHeight: 50)
        .sensoryFeedback(.selection, trigger: isFavorite)
        .sheet(item: $mapItem) { item in
            MapPreview(resultDetail: item,
                       position: .region(MKCoordinateRegion(center: item.coordinates,
                                                            span: MKCoordinateSpan(latitudeDelta: 0.007, longitudeDelta: 0.007))))
                .presentationDetents([.medium, .large])
                .presentationCornerRadius(30)
        }
    }

    private func update() {
        if starred && sawMap {
            report.complete()
        } else if starred {
            report.advance("Bien ! Touchez maintenant l'icône à droite pour voir où se trouve l'arrêt.")
        } else if sawMap {
            report.advance("Bien vu ! Ajoutez-le maintenant à vos favoris avec l'étoile.")
        }
    }
}

// MARK: Heure ou minutes

private struct DepartureTimeDemo: View {
    let report: DemoReport
    // Comme le bouton, qui se remet au réglage par défaut en apparaissant : sans ça, la
    // démonstration se croirait réussie avant d'avoir été touchée.
    @State private var showTime = UserDefaults.standard.bool(forKey: SettingKey.clockTimeByDefault)
    @State private var departures = Array(DemoData.timetable(from: 0).prefix(3))

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text(verbatim: "Plainpalais").font(.headline)
                Spacer()
                ShowTimeButton(showTime: $showTime)
                    .font(.title3)
            }
            .padding(.horizontal, 8)
            ForEach(departures, id: \.id) { departure in
                StopEventView(event: departure, showTime: showTime)
                    .foregroundStyle(determineColor(for: departure.estimatedTime))
            }
        }
        .onChange(of: showTime) { report.complete() }
    }
}

// MARK: Rappel

private struct ReminderDemo: View {
    let report: DemoReport
    @State private var chosen: Int?
    @State private var departure = DemoData.departure(line: "12", destination: "Genève, Moillesulaz", quay: "C", inMinutes: 34)

    var body: some View {
        VStack(spacing: 12) {
            if let chosen {
                notification(minutes: chosen)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            StopEventView(event: departure, showTime: false)
                .contentShape(.contextMenuPreview, Capsule())
                // Les choix du vrai menu, sans rien programmer.
                .contextMenu {
                    ForEach([0, 1, 5, 10, 30], id: \.self) { minutes in
                        Button {
                            choose(minutes)
                        } label: {
                            Text(label(for: minutes))
                        }
                    }
                }
                .accessibilityAction(named: "Prévenir 5' avant") { choose(5) }
        }
    }

    private func choose(_ minutes: Int) {
        // Après la fermeture du menu : l'animation serait sinon cachée par lui.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            withAnimation(.spring(duration: 0.5, bounce: 0.3)) { chosen = minutes }
            report.complete()
        }
    }

    private func label(for minutes: Int) -> String {
        minutes == 0 ? String(localized: "Prévenir à l'arrivée") : String(localized: "Prévenir \(minutes)' avant")
    }

    /// La notification telle qu'elle arrivera.
    private func notification(minutes: Int) -> some View {
        HStack(alignment: .top, spacing: 10) {
            AppIconView(size: 34)
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(verbatim: "tpg Next").font(.footnote.weight(.semibold))
                    Spacer()
                    Text("maintenant")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(verbatim: "Ligne 12 → Moillesulaz").font(.subheadline.weight(.semibold))
                Text(minutes == 0 ? "Le tram arrive à Plainpalais, quai C." : "Départ dans \(minutes) min de Plainpalais, quai C.")
                    .font(.subheadline)
            }
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
        .accessibilityElement(children: .combine)
    }
}

// MARK: Page d'un arrêt : tri, filtre, plus tôt, plus tard

/// Les départs d'un arrêt et les boutons flottants de sa page, tels quels : tri par ligne,
/// filtre (avec sa feuille) et flèches des départs précédents et suivants.
private struct StopPageDemo: View {
    enum Goal {
        case sortAndFilter, earlierLater
    }

    let goal: Goal
    let report: DemoReport
    @State private var byLine = false
    @State private var showsFilters = false
    @State private var isFiltered = false
    @State private var selection: Set<String> = []
    /// Le début de la liste, en minutes depuis maintenant : dix de plus ou de moins par flèche,
    /// ou l'heure choisie avec l'horloge.
    @State private var start = 0
    @State private var showsTimeSheet = false
    @State private var pickedTime = Date.now
    @State private var usedClock = false
    @State private var showTime: Bool
    @State private var sorted = false
    @State private var filtered = false
    @State private var wentEarlier = false
    @State private var wentLater = false

    init(goal: Goal, report: DemoReport) {
        self.goal = goal
        self.report = report
        // Plus tôt, plus tard : les heures disent mieux le décalage que les minutes restantes.
        _showTime = State(initialValue: goal == .earlierLater)
    }


    var body: some View {
        let events = DemoData.timetable(from: start)
        let groups = events.groupedByLineAndDestination()
        let shownGroups = selection.isEmpty ? groups : groups.filter { selection.contains($0.key) }
        let list = events.filter { selection.isEmpty || selection.contains("\($0.lineName);\($0.destination)") }
        VStack(spacing: 4) {
            HStack {
                Text(verbatim: "Plainpalais").font(.headline)
                Spacer()
                if goal == .earlierLater {
                    Text("Dès \(startText)")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                    // Le bouton de la barre du haut de la page d'un arrêt.
                    Button {
                        pickedTime = Date.now.addingTimeInterval(TimeInterval(start * 60))
                        showsTimeSheet = true
                    } label: {
                        Image(systemName: "clock")
                            .font(.title3)
                            .symbolEffect(.pulse, isActive: wentEarlier && wentLater && !usedClock)
                            .padding(6)
                    }
                    .accessibilityLabel("Sélectionner l'heure")
                }
            }
            .padding(.horizontal, 8)
            // Comme sur la page d'un arrêt : la liste défile sous les boutons flottants.
            ScrollView {
                VStack(spacing: 0) {
                    if byLine {
                        ForEach(shownGroups.keys.sorted(by: lineGroupPrecedes), id: \.self) { key in
                            SortedStopEventsView(key: key, filteredStopEvents: shownGroups, groupedStopEvents: groups,
                                                 showTime: $showTime, previousLineRef: .constant(nil),
                                                 stopName: DemoData.stopName, stopSloid: DemoData.sloid,
                                                 onSelect: { _ in }, allowsReminders: false)
                                .padding(.horizontal, -15)
                        }
                    } else {
                        ForEach(list, id: \.id) { event in
                            StopEventView(event: event, showTime: showTime)
                                .foregroundStyle(determineColor(for: event.estimatedTime))
                        }
                    }
                }
                .padding(.bottom, 76)
            }
            .scrollBounceBehavior(.basedOnSize)
            .frame(height: 300)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(alignment: .bottom) {
                StopFloatingControls(isGroupedByLine: byLine,
                                     toggleGrouping: {
                                         withAnimation(.snappy) { byLine.toggle() }
                                         sorted = true
                                         update()
                                     },
                                     showsFilters: $showsFilters, isFiltered: $isFiltered,
                                     moveTime: { earlier in
                                         withAnimation(.snappy) { start += earlier ? -10 : 10 }
                                         if earlier { wentEarlier = true } else { wentLater = true }
                                         update()
                                     })
                    .padding(-10)
            }
        }
        .sheet(isPresented: $showsTimeSheet) {
            DepartureTimeSheet(time: $pickedTime) {
                withAnimation(.snappy) { start = Int((pickedTime.timeIntervalSinceNow / 60).rounded()) }
                showsTimeSheet = false
                usedClock = true
                update()
            }
        }
        .sheet(isPresented: $showsFilters) {
            LineFilterSheet(groups: groups, selection: $selection, isFiltered: $isFiltered) {
                showsFilters = false
            }
            .presentationDetents([.medium])
            .presentationCornerRadius(30)
        }
        .onChange(of: selection) {
            isFiltered = !selection.isEmpty
            if !selection.isEmpty { filtered = true }
            update()
        }
    }

    /// « 13:32 », ou « mer. 14:30 » un autre jour.
    private var startText: String {
        let date = Date.now.addingTimeInterval(TimeInterval(start * 60))
        return Calendar.current.isDateInToday(date)
            ? date.formatted(date: .omitted, time: .shortened)
            : date.formatted(.dateTime.weekday(.abbreviated).hour().minute())
    }

    private func update() {
        switch goal {
        case .sortAndFilter:
            if sorted && filtered {
                report.complete()
            } else if sorted {
                report.advance("Bien ! Touchez maintenant le filtre et choisissez une ligne.")
            } else if filtered {
                report.advance("Bien ! Changez maintenant le tri avec le bouton de gauche.")
            }
        case .earlierLater:
            let arrows = wentEarlier && wentLater
            if arrows && usedClock {
                report.complete()
            } else if arrows {
                report.advance("Bien ! Pour une heure précise, touchez maintenant l'horloge en haut.")
            } else if wentEarlier || wentLater {
                report.advance("Bien ! Essayez maintenant l'autre flèche.")
            } else if usedClock {
                report.advance("Bien ! Essayez aussi les flèches en bas à droite.")
            }
        }
    }
}

// MARK: Itinéraire depuis un arrêt

private struct TripActionsDemo: View {
    let report: DemoReport
    @State private var choice: Choice?

    enum Choice {
        case from, to, quick
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 0) {
                    Text(verbatim: "Genève").font(.caption).foregroundStyle(.secondary)
                    Text(verbatim: "Rive").font(.title3.bold())
                }
                Spacer()
                Menu {
                    Button { pick(.from) } label: {
                        Label("Partir d'ici", systemImage: "point.bottomleft.forward.to.point.topright.filled.scurvepath")
                    }
                    Button { pick(.to) } label: {
                        Label("Aller ici", systemImage: "point.bottomleft.filled.forward.to.point.topright.scurvepath")
                    }
                    Button { pick(.quick) } label: {
                        Label("Trajet rapide", systemImage: "point.bottomleft.forward.to.arrow.triangle.scurvepath")
                    }
                } label: {
                    Image(systemName: "point.bottomleft.forward.to.point.topright.scurvepath")
                        .font(.title3)
                        .foregroundStyle(.primary)
                        .frame(width: 46, height: 46)
                        .background(Circle().fill(Color(.systemBackground)))
                }
                .accessibilityLabel("Itinéraire")
            }
            .padding(.horizontal)
            .basicElementBackground(minHeight: 60)
            if let choice {
                form(for: choice)
                    .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))
            }
        }
    }

    private func pick(_ choice: Choice) {
        withAnimation(.snappy) { self.choice = choice }
        report.complete()
    }

    /// Les champs de l'onglet Itinéraire, tels qu'ils seraient remplis.
    private func form(for choice: Choice) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            field("Départ", value: choice == .from ? "Rive" : choice == .quick ? String(localized: "Ma position") : nil)
            field("Arrivée", value: choice == .from ? nil : "Rive")
            Text(choice == .quick
                 ? "Trajet rapide lance la recherche aussitôt, pour partir maintenant."
                 : "Il ne reste qu'à choisir l'autre extrémité.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.top, 2)
        }
        .id(choice)
    }

    private func field(_ title: LocalizedStringKey, value: String?) -> some View {
        HStack {
            Text(title).foregroundStyle(.secondary).frame(width: 70, alignment: .leading)
            Text(value ?? String(localized: "À choisir"))
                .foregroundStyle(value == nil ? .tertiary : .primary)
                .fontWeight(value == nil ? .regular : .semibold)
            Spacer()
        }
        .padding(.horizontal, 12)
        .basicElementBackground(minHeight: 40)
    }
}

// MARK: Suivi en direct

private struct LiveTrackingDemo: View {
    let report: DemoReport
    @State private var boarded: Bool?

    private var arrival: Date { .now.addingTimeInterval(TimeInterval((boarded == false ? 26 : 18) * 60)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                BusLineIcon(lineName: "12", operatorName: DemoData.operatorName)
                Text(verbatim: "→ Moillesulaz").font(.headline)
                Spacer()
                Text("Arrivée \(arrival.formatted(date: .omitted, time: .shortened))")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(boarded == false ? .orange : .green)
                    .contentTransition(.numericText())
            }
            switch boarded {
            case nil:
                Text("Le 12 partait au moment où vous descendiez à Rive. Êtes-vous monté dedans ?")
                    .font(.subheadline)
                HStack(spacing: 10) {
                    answer("Je suis monté", boarded: true, color: .green)
                    answer("Je l'ai manqué", boarded: false, color: .gray)
                }
            case true?:
                Text("Dans le 12 · descendez à Moillesulaz dans 14 min")
                    .font(.subheadline)
                ProgressView(value: 0.35)
                    .tint(.green)
            case false?:
                Text("Prochain 12 dans 8 min · quai A · arrivée retardée de 8 min")
                    .font(.subheadline)
                ProgressView(value: 0.1)
                    .tint(.orange)
            }
            if boarded != nil {
                Button {
                    withAnimation(.snappy) { boarded = nil }
                } label: {
                    Label("Recommencer", systemImage: "arrow.counterclockwise")
                        .font(.footnote)
                }
                .foregroundStyle(.white.opacity(0.7))
            }
        }
        .foregroundStyle(.white)
        .padding(16)
        .background(Color.black.opacity(0.88), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .environment(\.colorScheme, .dark)
    }

    private func answer(_ title: LocalizedStringKey, boarded: Bool, color: Color) -> some View {
        Button {
            withAnimation(.snappy) { self.boarded = boarded }
            report.complete()
        } label: {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(color.opacity(0.35), in: Capsule())
        }
        .foregroundStyle(.white)
    }
}

#Preview("Démonstrations") {
    ScrollView {
        VStack(spacing: 20) {
            ForEach(GuideDemo.allCases, id: \.self) { demo in
                GuideDemoView(demo: demo)
            }
        }
        .padding()
    }
    .previewEnvironment(navigation: false, favorites: [])
}
