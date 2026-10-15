//
//  DepartureActions.swift
//  tpg Next
//
//  Ce que l'appui long sur un départ ouvre par-dessus la page : le choix du délai d'un rappel,
//  et celui de l'autre arrêt d'une course suivie en direct. Des feuilles plutôt que des pages :
//  on reste sur l'arrêt, la ligne ou l'itinéraire d'où l'on vient.
//

import SwiftUI
import tpgNextFunc

/// Les feuilles qu'un menu de départ peut ouvrir. Un menu contextuel se referme aussitôt : il ne
/// peut rien présenter lui-même, la page qui le porte s'en charge (`departureActionSheets()`).
struct DepartureActions {
    /// Choisir combien de minutes avant ce départ être prévenu.
    var remind: (_ event: StopEvent, _ stopID: String) -> Void
    /// Suivre la course en direct ; `departsFromStop` : on monte à cet arrêt, sinon on y descend.
    var track: (_ event: StopEvent, _ stopSloid: String, _ departsFromStop: Bool) -> Void
}

extension EnvironmentValues {
    @Entry var departureActions = DepartureActions(
        remind: { _, _ in Log.notifications.error("Rappel demandé hors d'une page qui sait l'afficher") },
        track: { _, _, _ in Log.notifications.error("Suivi demandé hors d'une page qui sait l'afficher") })
}

extension View {
    /// À poser sur une pile : ses pages savent alors ouvrir le rappel et le suivi d'un départ.
    func departureActionSheets() -> some View {
        modifier(DepartureActionSheets())
    }
}

private struct DepartureActionSheets: ViewModifier {
    struct Reminder: Identifiable {
        let id = UUID()
        let event: StopEvent
        let stopID: String
    }

    struct Tracking: Identifiable {
        let id = UUID()
        let event: StopEvent
        let stopSloid: String
        let departsFromStop: Bool
    }

    @State private var reminder: Reminder?
    @State private var tracking: Tracking?

    func body(content: Content) -> some View {
        content
            .environment(\.departureActions, DepartureActions(
                remind: { reminder = Reminder(event: $0, stopID: $1) },
                track: { tracking = Tracking(event: $0, stopSloid: $1, departsFromStop: $2) }))
            .sheet(item: $reminder) { reminder in
                ReminderSheet(event: reminder.event, stopID: reminder.stopID)
            }
            .sheet(item: $tracking) { tracking in
                TrackJourneySheet(event: tracking.event, stopSloid: tracking.stopSloid,
                                  departsFromStop: tracking.departsFromStop)
            }
    }
}

// MARK: - Rappel

/// Combien de minutes avant le départ, dans une feuille basse : une roue de 0 à 90 minutes,
/// comme celle des heures, et quelques délais d'un toucher au-dessus. Le dernier délai choisi
/// est repris la fois suivante.
struct ReminderSheet: View {
    let event: StopEvent
    let stopID: String
    /// Pour la démo du guide : reçoit le délai au lieu de programmer le rappel.
    var onChoose: ((Int) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.displayTime) private var now
    @AppStorage(SettingKey.lastReminderMinutes) private var storedMinutes = 5
    @State private var minutes = 5

    static let presets = [5, 10, 15, 30]
    static let range = 0...90

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                presets
                // Coupée au dernier délai possible : la roue ne propose pas un rappel déjà passé.
                Picker("Minutes avant", selection: $minutes) {
                    ForEach(0...maxMinutes, id: \.self) { value in
                        Text(Self.label(for: value)).tag(value)
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 170)
                Spacer(minLength: 0)
                confirmButton
            }
            .padding(.horizontal)
            .padding(.top, 4)
            .padding(.bottom, 8)
            .navigationTitle("Programmer un rappel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Label("Fermer", systemImage: "xmark")
                    }
                }
            }
        }
        // Feuille basse : la roue, les raccourcis et le bouton, sans plus.
        .presentationDetents([.height(400), .large])
        .presentationCornerRadius(35)
        .onAppear { minutes = min(max(storedMinutes, 0), maxMinutes) }
        // Le départ approche : le délai choisi suit la fin de la roue.
        .onChange(of: maxMinutes) {
            if minutes > maxMinutes { withAnimation { minutes = maxMinutes } }
        }
    }

    // MARK: Morceaux

    /// Les délais courants : ils font tourner la roue.
    private var presets: some View {
        HStack(spacing: 8) {
            ForEach(Self.presets, id: \.self) { preset in
                Button {
                    withAnimation(.snappy) { minutes = preset }
                } label: {
                    Text(verbatim: "\(preset) min")
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .padding(.horizontal, 6)
                        .frame(maxWidth: .infinity)
                        .basicElementBackground(minHeight: 38, selected: minutes == preset)
                }
                .buttonStyle(.plain)
                .disabled(!isPossible(preset))
                .opacity(isPossible(preset) ? 1 : 0.4)
                .accessibilityLabel(Self.label(for: preset))
                .accessibilityAddTraits(minutes == preset ? .isSelected : [])
            }
        }
    }

    private var confirmButton: some View {
        Button {
            storedMinutes = minutes
            if let onChoose {
                onChoose(minutes)
            } else {
                BusNotificationManager.shared.scheduleReminder(for: event, stopID: stopID, minutes: minutes)
            }
            dismiss()
        } label: {
            VStack(spacing: 2) {
                Text("Programmer le rappel")
                    .font(.headline)
                if let reminderDate {
                    Text(isPossible(minutes)
                         ? String(localized: "Notification à \(dateToString(with: reminderDate))")
                         : String(localized: "Trop tard : le départ est trop proche"))
                        .font(.caption)
                        .opacity(0.85)
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 46)
        }
        .prominentButtonStyle()
        .disabled(!isPossible(minutes))
    }

    // MARK: Heures

    private var departure: Date? {
        OJPDate.date(from: event.estimatedTime) ?? OJPDate.date(from: event.timetabledTime)
    }

    private var reminderDate: Date? {
        departure?.addingTimeInterval(-Double(minutes) * 60)
    }

    /// Le plus long délai encore possible : 8 si le départ est dans 8 min 30.
    private var maxMinutes: Int {
        guard let departure else { return 0 }
        let seconds = departure.timeIntervalSince(now)
        return min(max(Int((seconds / 60).rounded(.up)) - 1, 0), Self.range.upperBound)
    }

    /// Un rappel dont l'heure est passée ne partirait jamais.
    private func isPossible(_ minutes: Int) -> Bool {
        guard let departure else { return false }
        return departure.addingTimeInterval(-Double(minutes) * 60) > now
    }

    static func label(for minutes: Int) -> String {
        minutes == 0 ? String(localized: "À l'arrivée") : String(localized: "\(minutes) min avant")
    }
}

extension BusNotificationManager {
    /// Pose le rappel et dit s'il est prévu.
    func scheduleReminder(for event: StopEvent, stopID: String, minutes: Int) {
        let confirmation = NotificationConfirmationViewModel.shared
        guard notificationManager.isNotificationAuthorized else {
            confirmation.show(message: String(localized: "Les notifications n'ont pas été autorisées pour tpg Next.\nChangez-le dans les réglages du téléphone"), error: true)
            return
        }
        scheduleNotifications(for: event, lineEvent: nil, stopID: stopID, notificationInterval: Double(minutes)) { success in
            if !success {
                confirmation.show(message: String(localized: "Erreur : le rappel n'a pas pu être programmé"), error: true)
            } else if minutes == 0 {
                confirmation.show(message: String(localized: "Rappel programmé à l'arrivée"), error: false)
            } else {
                confirmation.show(message: String(localized: "Rappel programmé \(minutes)' avant"), error: false)
            }
        }
    }
}

// MARK: - Suivi

/// Le choix de l'autre arrêt de la course, dans une feuille.
struct TrackJourneySheet: View {
    let event: StopEvent
    let stopSloid: String
    let departsFromStop: Bool
    /// Pour les aperçus : la course, sans la demander à l'API.
    var previewEvents: [LineEvent]?
    var previewSelection: LineEvent.ID?
    @Environment(\.dismiss) private var dismiss
    @State private var detent = PresentationDetent.large

    var body: some View {
        NavigationStack {
            TrackJourneyView(event: event, stopSloid: stopSloid, departsFromStop: departsFromStop,
                             previewEvents: previewEvents, previewSelection: previewSelection)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            dismiss()
                        } label: {
                            Label("Fermer", systemImage: "xmark")
                        }
                    }
                }
        }
        // En grand : la course entière se parcourt d'un coup d'œil ; vers le bas, la moitié.
        .presentationDetents([.medium, .large], selection: $detent)
        .presentationCornerRadius(35)
    }
}

#Preview("Programmer un rappel") {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            ReminderSheet(event: PreviewData.departure(inMinutes: 12), stopID: PreviewData.rive.sloid)
        }
        .previewEnvironment()
}

#Preview("Programmer un rappel — départ proche") {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            ReminderSheet(event: PreviewData.departure(inMinutes: 4), stopID: PreviewData.rive.sloid)
        }
        .previewEnvironment()
}
