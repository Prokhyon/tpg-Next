//
//  RemindersView.swift
//  tpg Next
//
//  Ce qui va prévenir l'utilisateur, ouvert depuis la cloche de l'accueil : le trajet suivi en
//  direct, les rappels posés à la main sur un départ, et ceux que l'app programme d'elle-même
//  pour les trajets réguliers et les itinéraires enregistrés.
//

import SwiftUI
import UserNotifications
import tpgNextFunc

/// Les rappels prévus dans une bulle sur iPad, une feuille sur iPhone, plutôt qu'une page entière.
struct ScheduledNotificationsSheet: View {
    @Environment(\.dismiss) private var dismiss
    var previewAutomatic: [AutomaticReminders.Group]? = nil

    var body: some View {
        NavigationStack {
            ScheduledNotifications(previewAutomatic: previewAutomatic)
                .navigationTitle("Rappels prévus")
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
        .frame(minWidth: 380, idealWidth: 420, minHeight: 360, idealHeight: 520)
        .presentationCompactAdaptation(.sheet)
        .presentationDetents([.medium, .large])
        .presentationCornerRadius(35)
    }
}

struct ScheduledNotifications: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openRoute) private var openRoute
    @Environment(NavigationModel.self) private var navigationModel
    @Environment(SavedTripsModel.self) private var savedTripsModel
    @Environment(RegularTripsModel.self) private var regularTripsModel
    var transportNotificationManager = BusNotificationManager.shared
    private var liveActivities = TripLiveActivities.shared

    @State private var automatic: [AutomaticReminders.Group] = []
    /// Pour les aperçus : ces rappels plutôt que ceux du centre de notifications.
    var previewAutomatic: [AutomaticReminders.Group]? = nil

    var body: some View {
        let manual = transportNotificationManager.scheduledNotificationIdentifiers
        let live = liveActivities.live.sorted { $0.value.state.arrival < $1.value.state.arrival }
        Group {
            if manual.isEmpty && automatic.isEmpty && live.isEmpty {
                ContentUnavailableView("Aucun rappel programmé", systemImage: "bell.slash",
                                       description: Text("Appuyez longuement sur un départ, sur la page d'un arrêt, pour être prévenu avant son passage."))
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        if !live.isEmpty {
                            section("Suivi en cours") {
                                ForEach(live, id: \.key) { entry in
                                    liveRow(key: entry.key, trip: entry.value)
                                }
                            }
                        }
                        if !manual.isEmpty {
                            manualSection(manual)
                        }
                        if !automatic.isEmpty {
                            section("Automatiques",
                                    footer: "Programmés par vos trajets réguliers et vos itinéraires enregistrés : ils se règlent dans chaque trajet régulier et dans les paramètres. Appuyez longuement sur un trajet régulier pour le sauter ce jour-là.") {
                                ForEach(automatic) { group in
                                    automaticRow(group)
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        // La liste ne survit pas à une relance : on la relit auprès du système.
        .onAppear {
            transportNotificationManager.refreshScheduledNotifications()
        }
        .task { await reloadAutomatic() }
    }

    // MARK: Morceaux

    /// Un titre, des capsules l'une sous l'autre, et une explication dessous.
    private func section<Content: View>(_ title: LocalizedStringKey, footer: LocalizedStringKey? = nil,
                                        @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .padding(.leading, 8)
            content()
            if let footer {
                Text(footer)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.top, 2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// Un rappel dans sa capsule, manuel ou automatique : à gauche le symbole du trajet ou la
    /// ligne du départ, le titre et le détail, à droite le chevron d'un rappel qui ouvre son
    /// trajet ou la croix d'un rappel posé à la main. De l'air au-dessus et au-dessous du texte.
    private func capsuleRow<Leading: View, Trailing: View>(title: Text, subtitle: String,
                                                           @ViewBuilder leading: () -> Leading,
                                                           @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack(spacing: 12) {
            leading()
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                title
                    .font(.callout)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(verbatim: subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .multilineTextAlignment(.leading)
            Spacer(minLength: 4)
            trailing()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .basicElementBackground(minHeight: 60)
        .contentShape(.contextMenuPreview, Capsule())
        .contentShape(Capsule())
    }

    /// Le symbole d'un trajet suivi ou programmé, et le chevron qui l'ouvre.
    private func capsuleRow(title: Text, subtitle: String, systemImage: String, color: Color) -> some View {
        capsuleRow(title: title, subtitle: subtitle) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 28)
        } trailing: {
            Image(systemName: "chevron.right")
                .font(.footnote.bold())
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: Suivi en cours

    /// Une seule ligne par trajet suivi : l'activité en direct montre déjà ses étapes.
    private func liveRow(key: String, trip: TripLiveActivities.LiveTrip) -> some View {
        Button {
            close { LiveTripPresentation.shared.open(key) }
        } label: {
            capsuleRow(title: Text(tripTitle: trip.attributes.title),
                       subtitle: String(localized: "Arrivée à \(dateToString(with: trip.state.arrival)) · alertes de montée et de descente"),
                       systemImage: "inset.filled.circle", color: Color.accentColor)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                withAnimation { liveActivities.stop(key) }
            } label: {
                Label("Arrêter le suivi", systemImage: "stop.circle")
            }
        }
    }

    // MARK: Rappels manuels

    /// Comme les automatiques : la ligne du départ, sa destination, puis l'arrêt, l'heure du
    /// départ et le délai. Un toucher ouvre l'arrêt sur ce départ ; la croix annule le rappel.
    private func manualSection(_ manual: [String: StopEvent]) -> some View {
        let reminders = manual.sorted {
            (Self.departure(of: $0.value) ?? .distantFuture) < (Self.departure(of: $1.value) ?? .distantFuture)
        }
        return section("Vos rappels") {
            ForEach(reminders, id: \.key) { key, event in
                manualRow(key: key, event: event)
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .opacity))
            }
        }
    }

    private func manualRow(key: String, event: StopEvent) -> some View {
        let minutes = Int(parseIdentifier(key)?.notificationInterval ?? 0)
        let delay = minutes == 0 ? String(localized: "à l'arrivée") : String(localized: "\(minutes)' avant")
        let departure = Self.departure(of: event).map { String(localized: "départ \(dateToString(with: $0))") }
        let subtitle = [shortStopName(event.stopPointName), departure, delay].compactMap { $0 }.joined(separator: " · ")
        return Button {
            close {
                openRoute(.stop(name: event.stopPointName, sloid: event.stopId,
                                highlight: DepartureHighlight(journeyRef: event.journeyRef, lineName: event.lineName,
                                                              time: event.timetabledTime)))
            }
        } label: {
            capsuleRow(title: Text("→ \(Text(stopName: event.destination))"), subtitle: subtitle) {
                BusLineIcon(lineName: event.lineName, operatorName: event.operatorName)
                    .font(.callout)
                    .fixedSize()
            } trailing: {
                Button {
                    withAnimation(.easeInOut) {
                        transportNotificationManager.cancelScheduledNotifications(timetableIdentifier: "timetable_\(key)",
                                                                                  estimatedIdentifier: "estimated_\(key)",
                                                                                  completeCancel: true)
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .frame(width: 34, height: 34)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Annuler le rappel")
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Ligne \(event.lineName) vers \(event.destination), \(subtitle)"))
    }

    private static func departure(of event: StopEvent) -> Date? {
        OJPDate.date(from: event.estimatedTime) ?? OJPDate.date(from: event.timetabledTime)
    }

    // MARK: Rappels automatiques

    /// Pas de croix : l'app les reprogramme à chaque rafraîchissement. Un toucher ouvre le trajet.
    private func automaticRow(_ group: AutomaticReminders.Group) -> some View {
        Button {
            open(group)
        } label: {
            capsuleRow(title: Text(tripTitle: group.title), subtitle: group.summary,
                       systemImage: group.isRegular ? "repeat" : "point.bottomleft.forward.to.point.topright.scurvepath.fill",
                       color: group.isRegular ? .teal : .orange)
        }
        .buttonStyle(.plain)
        .contextMenu {
            if case .regular(let occurrenceID) = group.source, let occurrence = occurrence(occurrenceID) {
                Button {
                    regularTripsModel.skip(occurrence)
                    // Les rappels sont reposés en arrière-plan : la liste suit un instant après.
                    Task {
                        try? await Task.sleep(for: .milliseconds(600))
                        await reloadAutomatic()
                    }
                } label: {
                    Label("Pas de trajet ce jour-là", systemImage: "calendar.badge.minus")
                }
            }
        }
    }

    private func open(_ group: AutomaticReminders.Group) {
        switch group.source {
        case .saved(let id):
            if let trip = savedTripsModel.savedTrips.first(where: { $0.id == id }) {
                close { openRoute(.trip(savedTripsModel.displayedTrip(for: trip))) }
            } else {
                close { navigationModel.showTrips() }
            }
        case .regular(let occurrenceID):
            if let occurrence = occurrence(occurrenceID), let trip = regularTripsModel.displayedTrip(for: occurrence) {
                close { openRoute(.trip(trip)) }
            } else {
                close { navigationModel.showTrips(.regular) }
            }
        }
    }

    private func occurrence(_ id: String) -> RegularTripOccurrence? {
        regularTripsModel.upcoming(after: Date().addingTimeInterval(-3600)).first { $0.id == id }
    }

    /// La fenêtre se ferme d'abord : l'écran demandé s'ouvre derrière.
    private func close(then action: @escaping () -> Void) {
        dismiss()
        action()
    }

    private func reloadAutomatic() async {
        let groups: [AutomaticReminders.Group]
        if let previewAutomatic { groups = previewAutomatic } else { groups = await AutomaticReminders.load() }
        withAnimation { automatic = groups }
    }
}

/// Les notifications que l'app programme d'elle-même, lues dans le centre de notifications et
/// regroupées par trajet : rappels des trajets réguliers et des itinéraires enregistrés, et
/// invitations au suivi en direct automatique.
enum AutomaticReminders {
    enum Source: Hashable {
        case saved(id: String)
        case regular(occurrenceID: String)
    }

    enum Kind {
        case reminder
        case autoTrack
    }

    struct Notice {
        var kind: Kind
        var date: Date
    }

    struct Group: Identifiable {
        let source: Source
        /// Le titre de la notification : le nom du trajet régulier, ou « Rive → Cornavin ».
        var title: String
        var notices: [Notice]

        var id: Source { source }
        var isRegular: Bool {
            if case .regular = source { return true }
            return false
        }
        var firstDate: Date { notices.map(\.date).min() ?? .distantFuture }

        /// « Demain · rappel à 07:32 · suivi en direct à 07:27 ».
        var summary: String {
            let parts = notices.sorted { $0.date < $1.date }.map { notice in
                let time = dateToString(with: notice.date)
                switch notice.kind {
                case .reminder: return String(localized: "rappel à \(time)")
                case .autoTrack: return String(localized: "suivi en direct à \(time)")
                }
            }
            return ([SavedTripsAgenda.dayTitle(firstDate)] + parts).joined(separator: " · ")
        }
    }

    static func load() async -> [Group] {
        let pending = await UNUserNotificationCenter.current().pendingNotificationRequests()
        var groups: [Source: Group] = [:]
        for request in pending {
            let identifier = request.identifier
            let source: Source
            let kind: Kind
            if identifier.hasPrefix(SavedTripReminders.prefix) {
                source = .saved(id: String(identifier.dropFirst(SavedTripReminders.prefix.count)))
                kind = .reminder
            } else if identifier.hasPrefix(SavedTripAutoTracking.prefix) {
                source = .saved(id: String(identifier.dropFirst(SavedTripAutoTracking.prefix.count)))
                kind = .autoTrack
            } else if identifier.hasPrefix(RegularTripAlerts.reminderPrefix) {
                source = .regular(occurrenceID: String(identifier.dropFirst(RegularTripAlerts.reminderPrefix.count)))
                kind = .reminder
            } else {
                continue
            }
            let date = (request.trigger as? UNTimeIntervalNotificationTrigger)?.nextTriggerDate()
                ?? (request.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate()
            guard let date else { continue }
            groups[source, default: Group(source: source, title: request.content.title, notices: [])]
                .notices.append(Notice(kind: kind, date: date))
        }
        return groups.values.sorted { $0.firstDate < $1.firstDate }
    }
}

extension AutomaticReminders {
    /// Un trajet régulier demain matin et un itinéraire enregistré : pour les aperçus.
    static var preview: [Group] {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date())) ?? Date()
        let at = { (hour: Int, minute: Int) in tomorrow.addingTimeInterval(TimeInterval(hour * 3600 + minute * 60)) }
        return [
            Group(source: .regular(occurrenceID: "preview"), title: "Travail",
                  notices: [Notice(kind: .reminder, date: at(7, 32))]),
            Group(source: .saved(id: "preview"), title: "Genève, Rive → Genève, gare Cornavin",
                  notices: [Notice(kind: .reminder, date: at(17, 40)), Notice(kind: .autoTrack, date: at(17, 35))]),
        ]
    }
}

#Preview("Rappels prévus — automatiques") {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            ScheduledNotificationsSheet(previewAutomatic: AutomaticReminders.preview)
        }
        .previewEnvironment(navigation: false)
}
