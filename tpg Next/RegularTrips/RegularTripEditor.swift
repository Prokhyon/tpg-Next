//
//  RegularTripEditor.swift
//  tpg Next
//
//  Création et modification d'un trajet régulier.
//

import SwiftUI
import tpgNextFunc

struct RegularTripEditor: View {
    @Environment(RegularTripsModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var trip: RegularTrip
    @AppStorage(SettingKey.regularTripAlertsOnThisDevice) private var alertsOnThisDevice = RegularTripAlerts.defaultOnThisDevice
    @AppStorage(SettingKey.regularTripRemindersOnThisDevice) private var remindersOnThisDevice = RegularTripAlerts.defaultOnThisDevice
    private let isNew: Bool
    @State private var choosingAvoidedLine = false
    /// Poussé dans la pile de la création (`NewRegularTripView`) : ni pile propre ni « Annuler »,
    /// et l'enregistrement ferme toute la feuille.
    private var onSaved: (() -> Void)?

    init(trip: RegularTrip) {
        _trip = State(initialValue: trip)
        isNew = false
    }

    /// Un nouveau trajet régulier à partir d'un itinéraire : du lundi au vendredi s'il tombe
    /// un jour de semaine, sinon ce jour-là chaque semaine.
    init(creatingFrom event: TripEvent) {
        let weekday = event.startDate.flatMap { Weekday(calendarWeekday: Calendar.swissTransit.component(.weekday, from: $0)) }
        let days = weekday.map { Weekday.workdays.contains($0) ? Weekday.workdays : [$0] } ?? Weekday.workdays
        _trip = State(initialValue: RegularTrip(trip: event, weekdays: days))
        isNew = true
    }

    /// La dernière étape de la création : jours et heure retenue sont déjà choisis.
    init(creatingFrom event: TripEvent, weekdays: Set<Weekday>, anchor: RegularTrip.Anchor, onSaved: @escaping () -> Void) {
        _trip = State(initialValue: RegularTrip(trip: event, weekdays: weekdays, anchor: anchor))
        isNew = true
        self.onSaved = onSaved
    }

    private static let reminderChoices: [Int?] = [nil, 0, 2, 5, 10, 15, 30]

    var body: some View {
        if onSaved == nil {
            NavigationStack { form }
        } else {
            form
        }
    }

    private var form: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SavedTripView(event: trip.snapshot)
                    .padding(15)
                    .background(BasicCard())

                // Sans nom, le trajet s'affiche « départ → arrivée ».
                CardSection("Nom") {
                    TextField("Nom", text: $trip.name, prompt: Text(verbatim: trip.routeName))
                        .submitLabel(.done)
                        .frame(minHeight: 50)
                }

                RegularTripDaysCard(selection: $trip.weekdays)

                RegularTripTimeCard(anchor: anchorBinding, time: timeBinding,
                                    title: trip.anchor == .departure ? "Montée à bord" : "Arrivée à l'arrêt",
                                    footer: trip.anchor == .departure
                                        ? "Le trajet part à cette heure, ou juste après."
                                        : "Le trajet arrive au plus tard à cette heure.")

                if !trip.legs.isEmpty {
                    CardSection(footer: trip.followsLines
                                ? "Vous êtes prévenu si ces lignes ne sont pas proposées ce jour-là, avec une alternative."
                                : "Le meilleur itinéraire du moment est proposé, quelles que soient les lignes.") {
                        Toggle(isOn: $trip.followsLines) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Toujours ces lignes")
                                RegularTripLines(snapshot: trip.snapshot)
                            }
                            .padding(.vertical, 8)
                            .frame(minHeight: 56)
                        }
                    }
                    avoidedLinesSection
                }

                if trip.snapshot.hasOnDemandLeg {
                    // Ni rappel, ni alertes, ni activité en direct : voir `TripLiveActivities.canTrack`.
                    CardSection("Notifications") {
                        Label {
                            Text("Ce trajet passe par un bus à la demande, sans horaire fixe : pas de rappel ni de suivi en direct. Pensez à le réserver.")
                                .fixedSize(horizontal: false, vertical: true)
                        } icon: {
                            Image(systemName: "phone.fill")
                                .foregroundStyle(.tint)
                        }
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 12)
                    }
                } else {
                    notificationsSection
                }

                CardSection {
                    Toggle(isOn: hasLastDay.animation()) {
                        PlainCardRow("Jusqu'à une date")
                    }
                    if trip.lastDay != nil {
                        CardDivider(inset: 0)
                        HStack {
                            PlainCardRow("Dernier jour")
                            DatePicker("Dernier jour", selection: lastDayBinding, in: Date()..., displayedComponents: .date)
                                .labelsHidden()
                                .environment(\.timeZone, Calendar.swissTransit.timeZone)
                        }
                    }
                }

                if !isNew {
                    Button(role: .destructive) {
                        model.remove(trip)
                        dismiss()
                    } label: {
                        Label("Supprimer le trajet régulier", systemImage: "trash")
                            .font(.headline)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity)
                            .basicElementBackground(minHeight: 50)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 30)
        }
        .readableScrollContent()
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(isNew ? "Trajet régulier" : "Modifier le trajet")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if onSaved == nil {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Enregistrer") { save() }
                    .disabled(trip.weekdays.isEmpty)
            }
        }
    }

    private var avoidedLinesSection: some View {
        CardSection("Lignes à éviter",
                    footer: "Jamais proposées quand le trajet doit être recalculé : alternative du jour, autres horaires, suite d'un trajet suivi.") {
            ForEach(trip.linesToAvoid) { line in
                HStack(spacing: 10) {
                    BusLineIcon(lineName: line.name, operatorName: line.operatorName)
                    Text("Ligne \(line.name)")
                    Spacer()
                    Button {
                        withAnimation { trip.linesToAvoid.removeAll { $0 == line } }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Ne plus éviter la ligne \(line.name)")
                }
                .frame(minHeight: 50)
                CardDivider(inset: 0)
            }
            Button {
                choosingAvoidedLine = true
            } label: {
                Label("Ajouter une ligne…", systemImage: "plus.circle.fill")
                    .frame(maxWidth: .infinity, minHeight: 50, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.tint)
        }
        .sheet(isPresented: $choosingAvoidedLine) {
            AvoidableLinePicker(trip: trip) { line in
                withAnimation { trip.linesToAvoid.append(line) }
            }
        }
    }

    private var notificationsSection: some View {
        CardSection("Notifications",
                    footer: "Le rappel suit l'heure réelle du départ. Les alertes arrivent dans l'heure et demie qui précède, quand l'iPhone laisse l'app vérifier les horaires. L'activité en direct s'affiche sur l'écran verrouillé 20 minutes avant le départ, si l'app est ouverte à ce moment-là.") {
            if let warning = deviceWarning {
                Label {
                    Text(warning)
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "bell.slash")
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.vertical, 10)
                CardDivider(inset: 0)
            }
            HStack {
                PlainCardRow("Rappel")
                Picker("Rappel", selection: $trip.reminderMinutes) {
                    ForEach(Self.reminderChoices, id: \.self) { minutes in
                        Text(reminderLabel(minutes)).tag(minutes)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .fixedSize()
            }
            CardDivider(inset: 0)
            Toggle(isOn: $trip.alertsEnabled) {
                PlainCardRow("Retards et changements")
            }
            CardDivider(inset: 0)
            Toggle(isOn: $trip.showsLiveActivity) {
                PlainCardRow("Activité en direct")
            }
        }
    }

    /// Ce que cet appareil ne fait pas, réglé dans les paramètres.
    private var deviceWarning: LocalizedStringKey? {
        if !alertsOnThisDevice && !remindersOnThisDevice {
            return "Cet appareil ne prévient pas : les rappels, alertes et activités en direct arrivent sur vos autres appareils. Pour changer, allez dans Paramètres."
        } else if !remindersOnThisDevice {
            return "Les rappels sont désactivés sur cet appareil. Pour changer, allez dans Paramètres."
        } else if !alertsOnThisDevice {
            return "Les alertes et activités en direct sont désactivées sur cet appareil. Pour changer, allez dans Paramètres."
        }
        return nil
    }

    private func save() {
        model.save(trip)
        if trip.reminderMinutes != nil || trip.alertsEnabled {
            // Sans effet si l'utilisateur a déjà répondu.
            NotificationManager.shared.requestAuthorization()
        }
        Task { await model.refresh() }
        if let onSaved { onSaved() } else { dismiss() }
    }

    private func reminderLabel(_ minutes: Int?) -> String {
        switch minutes {
        case nil: return String(localized: "Aucun")
        case 0: return String(localized: "À l'heure de partir")
        case let minutes?: return String(localized: "\(minutes) min avant")
        }
    }

    // MARK: Liaisons

    /// Passer du départ à l'arrivée garde le décalage choisi par rapport à l'itinéraire enregistré.
    private var anchorBinding: Binding<RegularTrip.Anchor> {
        Binding {
            trip.anchor
        } set: { anchor in
            guard anchor != trip.anchor,
                  let old = trip.snapshot.anchorDate(trip.anchor, timetabled: true),
                  let new = trip.snapshot.anchorDate(anchor, timetabled: true) else { return }
            let minutes = trip.minuteOfDay + Int(new.timeIntervalSince(old) / 60)
            trip.anchor = anchor
            trip.minuteOfDay = (minutes % 1440 + 1440) % 1440
        }
    }

    private var timeBinding: Binding<Date> {
        let calendar = Calendar.swissTransit
        let today = calendar.startOfDay(for: Date())
        return Binding {
            calendar.date(byAdding: .minute, value: trip.minuteOfDay, to: today) ?? today
        } set: { date in
            let components = calendar.dateComponents([.hour, .minute], from: date)
            trip.minuteOfDay = (components.hour ?? 0) * 60 + (components.minute ?? 0)
        }
    }

    private var hasLastDay: Binding<Bool> {
        Binding {
            trip.lastDay != nil
        } set: { enabled in
            let inAMonth = Calendar.swissTransit.date(byAdding: .month, value: 1, to: Date()) ?? Date()
            trip.lastDay = enabled ? Calendar.swissTransit.dayKey(for: inAMonth) : nil
        }
    }

    private var lastDayBinding: Binding<Date> {
        let calendar = Calendar.swissTransit
        return Binding {
            trip.lastDay.flatMap(Self.date(fromDayKey:)) ?? Date()
        } set: { date in
            trip.lastDay = calendar.dayKey(for: date)
        }
    }

    private static func date(fromDayKey key: String) -> Date? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return Calendar.swissTransit.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: 12))
    }
}

/// Les lignes qu'OJP propose pour ce trajet, au prochain jour où il est fait, sauf celles du
/// trajet habituel et celles déjà évitées. Une seule demande : une ligne qui n'apparaît qu'à
/// d'autres heures n'y est pas.
struct AvoidableLinePicker: View {
    let trip: RegularTrip
    let onPick: (AvoidedLine) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var search = Search.loading

    enum Search {
        case loading
        case lines([AvoidedLine])
        case failed
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    switch search {
                    case .loading:
                        VStack(spacing: 10) {
                            ProgressView()
                            Text("Recherche des lignes proposées…")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 30)
                    case .failed:
                        message("Impossible de charger les lignes proposées.")
                        Button("Réessayer") { Task { await load() } }
                            .frame(maxWidth: .infinity)
                    case .lines(let lines) where lines.isEmpty:
                        message("Aucune autre ligne n'est proposée pour ce trajet.")
                    case .lines(let lines):
                        CardSection(footer: "Les lignes proposées pour ce trajet, au prochain jour où vous le faites.") {
                            ForEach(Array(lines.enumerated()), id: \.element) { index, line in
                                if index > 0 { CardDivider(inset: 0) }
                                Button {
                                    onPick(line)
                                    dismiss()
                                } label: {
                                    HStack(spacing: 10) {
                                        BusLineIcon(lineName: line.name, operatorName: line.operatorName)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Ligne \(line.name)")
                                            if !line.operatorName.isEmpty {
                                                Text(verbatim: line.operatorName)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                        Spacer()
                                    }
                                    .frame(minHeight: 50)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 30)
            }
            .readableScrollContent()
            .navigationTitle("Éviter une ligne")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
            }
            .task { await load() }
        }
    }

    private func message(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 30)
    }

    private func load() async {
        search = .loading
        let request = trip.occurrences(after: Date()).first.map(trip.request(for:)) ?? (time: Date(), isArrivalTime: false)
        do {
            let trips = try await RegularTripResolver.trips(from: trip.origin, to: trip.destination, at: request.time,
                                                            isArrivalTime: request.isArrivalTime, avoiding: trip.linesToAvoid)
            var seen: Set<String> = []
            search = .lines(trips.flatMap(\.avoidableLines).filter { !trip.isUsualLine($0) && seen.insert($0.lineRef).inserted })
        } catch RegularTripResolver.Failure.noTrip {
            search = .lines([])
        } catch {
            search = .failed
        }
    }
}

/// Les jours du trajet : les sept à cocher, et semaine, week-end ou tous les jours d'un toucher.
struct RegularTripDaysCard: View {
    @Binding var selection: Set<Weekday>

    var body: some View {
        CardSection("Jours", footer: Text(selection.isEmpty
                                          ? String(localized: "Choisissez au moins un jour.")
                                          : RegularTrip.daysSummary(selection))) {
            WeekdayPicker(selection: $selection)
                .padding(.vertical, 12)
            CardDivider(inset: 0)
            WeekdayPresets(selection: $selection)
                .padding(.vertical, 12)
        }
    }
}

/// L'heure retenue : départ ou arrivée, puis l'heure, celle de Genève.
struct RegularTripTimeCard: View {
    @Binding var anchor: RegularTrip.Anchor
    @Binding var time: Date
    let title: LocalizedStringKey
    var footer: LocalizedStringKey?

    var body: some View {
        CardSection("Heure", footer: footer) {
            Picker("Heure retenue", selection: $anchor.animation()) {
                Text("Départ").tag(RegularTrip.Anchor.departure)
                Text("Arrivée").tag(RegularTrip.Anchor.arrival)
            }
            .pickerStyle(.segmented)
            .padding(.vertical, 12)
            CardDivider(inset: 0)
            HStack {
                PlainCardRow(title)
                DatePicker(title, selection: $time, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    // Les horaires sont ceux de Genève, même depuis l'étranger.
                    .environment(\.timeZone, Calendar.swissTransit.timeZone)
            }
        }
    }
}

/// Une ligne de carte sans icône : les pages d'un trajet régulier n'en ont pas.
struct PlainCardRow: View {
    let title: LocalizedStringKey

    init(_ title: LocalizedStringKey) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .frame(maxWidth: .infinity, minHeight: 50, alignment: .leading)
            .contentShape(Rectangle())
    }
}

/// Les sept jours, à cocher : des capsules de l'app, pleines quand le jour est retenu.
struct WeekdayPicker: View {
    @Binding var selection: Set<Weekday>

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Weekday.allCases) { day in
                let selected = selection.contains(day)
                Button {
                    withAnimation(.snappy) {
                        if selected { selection.remove(day) } else { selection.insert(day) }
                    }
                } label: {
                    Text(day.veryShortName)
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity, minHeight: 38)
                        .foregroundStyle(selected ? Color.white : Color.primary)
                        .background(BasicElement(button: selected))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(day.name)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }
}

/// Semaine, week-end, tous les jours : en un toucher. Le choix en cours est cerclé.
struct WeekdayPresets: View {
    @Binding var selection: Set<Weekday>

    var body: some View {
        HStack(spacing: 8) {
            preset("Semaine", days: Weekday.workdays)
            preset("Week-end", days: Weekday.weekend)
            preset("Tous les jours", days: Set(Weekday.allCases))
        }
    }

    private func preset(_ title: LocalizedStringKey, days: Set<Weekday>) -> some View {
        Button {
            withAnimation(.snappy) { selection = days }
        } label: {
            Text(title)
                .font(.subheadline.weight(.medium))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, 8)
                .frame(maxWidth: .infinity)
                .basicElementBackground(minHeight: 36, selected: selection == days)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selection == days ? .isSelected : [])
    }
}

/// Les lignes du trajet habituel, dans l'ordre.
struct RegularTripLines: View {
    let snapshot: TripEvent

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(snapshot.vehicleLegs.enumerated()), id: \.offset) { index, leg in
                if index > 0 {
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                BusLineIcon(lineName: leg.publishedLineName, operatorName: leg.legOperator)
                    .font(.footnote.bold())
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Lignes \(snapshot.vehicleLegs.map(\.publishedLineName).formatted(.list(type: .and)))"))
    }
}

// MARK: - Textes

extension Weekday {
    var name: String {
        Calendar.current.standaloneWeekdaySymbols[calendarWeekday - 1].capitalized
    }

    var shortName: String {
        Calendar.current.shortStandaloneWeekdaySymbols[calendarWeekday - 1].capitalized
    }

    var veryShortName: String {
        Calendar.current.veryShortStandaloneWeekdaySymbols[calendarWeekday - 1]
    }
}

extension RegularTrip {
    /// « Du lundi au vendredi », « Le week-end », « Lun., mer., ven. ».
    var daysSummary: String { Self.daysSummary(weekdays) }

    static func daysSummary(_ weekdays: Set<Weekday>) -> String {
        switch weekdays {
        case Set(Weekday.allCases): return String(localized: "Tous les jours")
        case Weekday.workdays: return String(localized: "Du lundi au vendredi")
        case Weekday.weekend: return String(localized: "Le week-end")
        default: return weekdays.sorted().map(\.shortName).joined(separator: ", ")
        }
    }

    /// « 07:42 », heure de Genève.
    var timeText: String {
        String(format: "%02d:%02d", minuteOfDay / 60, minuteOfDay % 60)
    }

    /// « Genève, Rive → Genève, gare Cornavin ».
    var routeName: String { "\(origin.name) → \(destination.name)" }

    /// Le nom choisi, sinon le départ et l'arrivée.
    var displayName: String { name.isEmpty ? routeName : name }

    /// Le nom choisi, en gras ; sinon « Genève **Rive** → Genève **gare Cornavin** ».
    var displayTitle: Text {
        name.isEmpty ? Text(route: origin.name, to: destination.name) : Text(verbatim: name).bold()
    }
}

#Preview("Nouveau trajet régulier") {
    RegularTripEditor(creatingFrom: PreviewData.tripWithTransfer)
        .environment(RegularTripsModel(previewTrips: []))
        .previewEnvironment(navigation: false)
}

#Preview("Modifier un trajet régulier") {
    RegularTripEditor(trip: RegularTrip(trip: PreviewData.tripWithTransfer, weekdays: Weekday.workdays))
        .environment(RegularTripsModel(previewTrips: []))
        .previewEnvironment(navigation: false)
}
