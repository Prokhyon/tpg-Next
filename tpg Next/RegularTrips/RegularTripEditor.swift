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
        Form {
            Section {
                SavedTripView(event: trip.snapshot)
                    .padding(.vertical, 6)
                // Sans nom, le trajet s'affiche « départ → arrivée ».
                TextField("Nom", text: $trip.name, prompt: Text(verbatim: trip.routeName))
            }

            Section {
                WeekdayPicker(selection: $trip.weekdays)
                    .listRowInsets(EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12))
                WeekdayPresets(selection: $trip.weekdays)
            } header: {
                Text("Jours")
            } footer: {
                Text(trip.weekdays.isEmpty ? String(localized: "Choisissez au moins un jour.") : trip.daysSummary)
            }

            Section {
                Picker("Heure retenue", selection: anchorBinding) {
                    Text("Départ").tag(RegularTrip.Anchor.departure)
                    Text("Arrivée").tag(RegularTrip.Anchor.arrival)
                }
                .pickerStyle(.segmented)
                DatePicker(trip.anchor == .departure ? "Montée à bord" as LocalizedStringKey : "Arrivée à l'arrêt",
                           selection: timeBinding, displayedComponents: .hourAndMinute)
                    // Les horaires sont ceux de Genève, même depuis l'étranger.
                    .environment(\.timeZone, Calendar.swissTransit.timeZone)
            } header: {
                Text("Heure")
            } footer: {
                Text(trip.anchor == .departure
                     ? "Le trajet part à cette heure, ou juste après." as LocalizedStringKey
                     : "Le trajet arrive au plus tard à cette heure.")
            }

            if !trip.legs.isEmpty {
                Section {
                    Toggle(isOn: $trip.followsLines) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Toujours ces lignes")
                            RegularTripLines(snapshot: trip.snapshot)
                        }
                    }
                } footer: {
                    Text(trip.followsLines
                         ? "Vous êtes prévenu si ces lignes ne sont pas proposées ce jour-là, avec une alternative." as LocalizedStringKey
                         : "Le meilleur itinéraire du moment est proposé, quelles que soient les lignes.")
                }
            }

            Section {
                Picker("Rappel", selection: $trip.reminderMinutes) {
                    ForEach(Self.reminderChoices, id: \.self) { minutes in
                        Text(reminderLabel(minutes)).tag(minutes)
                    }
                }
                Toggle("Retards et changements", isOn: $trip.alertsEnabled)
                Toggle("Activité en direct", isOn: $trip.showsLiveActivity)
            } header: {
                Text("Notifications")
            } footer: {
                VStack(alignment: .leading, spacing: 6) {
                    if !alertsOnThisDevice && !remindersOnThisDevice {
                        Label("Cet appareil ne prévient pas : les rappels, alertes et activités en direct arrivent sur vos autres appareils. Pour changer, allez dans Paramètres.",
                              systemImage: "bell.slash")
                    } else if !remindersOnThisDevice {
                        Label("Les rappels sont désactivés sur cet appareil. Pour changer, allez dans Paramètres.",
                              systemImage: "bell.slash")
                    } else if !alertsOnThisDevice {
                        Label("Les alertes et activités en direct sont désactivées sur cet appareil. Pour changer, allez dans Paramètres.",
                              systemImage: "bell.slash")
                    }
                    Text("Le rappel suit l'heure réelle du départ. Les alertes arrivent dans l'heure et demie qui précède, quand l'iPhone laisse l'app vérifier les horaires. L'activité en direct s'affiche sur l'écran verrouillé 20 minutes avant le départ, si l'app est ouverte à ce moment-là.")
                }
            }

            Section {
                Toggle("Jusqu'à une date", isOn: hasLastDay)
                if trip.lastDay != nil {
                    DatePicker("Dernier jour", selection: lastDayBinding, in: Date()..., displayedComponents: .date)
                        .environment(\.timeZone, Calendar.swissTransit.timeZone)
                }
            }

            if !isNew {
                Section {
                    Button("Supprimer le trajet régulier", role: .destructive) {
                        model.remove(trip)
                        dismiss()
                    }
                }
            }
        }
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

/// Les sept jours, à cocher.
struct WeekdayPicker: View {
    @Binding var selection: Set<Weekday>

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Weekday.allCases) { day in
                let selected = selection.contains(day)
                Button {
                    if selected { selection.remove(day) } else { selection.insert(day) }
                } label: {
                    Text(day.veryShortName)
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .foregroundStyle(selected ? Color.white : Color.primary)
                        .background(Circle().fill(selected ? Color.accentColor : Color.secondary.opacity(0.15)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(day.name)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }
}

/// Semaine, week-end, tous les jours : en un toucher.
struct WeekdayPresets: View {
    @Binding var selection: Set<Weekday>

    var body: some View {
        HStack {
            preset("Semaine", days: Weekday.workdays)
            preset("Week-end", days: Weekday.weekend)
            preset("Tous les jours", days: Set(Weekday.allCases))
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    private func preset(_ title: LocalizedStringKey, days: Set<Weekday>) -> some View {
        Button(title) { selection = days }
            .tint(selection == days ? .accentColor : .secondary)
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
    var daysSummary: String {
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
}

#Preview("Nouveau trajet régulier") {
    RegularTripEditor(creatingFrom: PreviewData.tripWithTransfer)
        .environment(RegularTripsModel(previewTrips: []))
        .previewEnvironment(navigation: false)
}
