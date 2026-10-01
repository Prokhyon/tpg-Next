//
//  SettingsView.swift
//  tpg Next
//
//  Created by Loris Thomas on 01.10.2024.
//

import SwiftUI
import MessageUI
import tpgNextFunc
import WidgetKit

/// Les paramètres, en cartes comme le reste de l'app : l'accueil et ses favoris, l'affichage
/// des départs, les notifications des trajets, puis l'aide. Les rappels prévus sont sur
/// l'accueil (cloche) ; le message de démarrage n'a plus d'entrée : le guide reprend tout.
struct SettingsView: View {
    @AppStorage(SettingKey.homeShowsFavorites) var homeFavorites = false
    @AppStorage(SettingKey.groupByLineByDefault) var groupedDefault = false
    @AppStorage(SettingKey.clockTimeByDefault) var timeDefault = false
    @AppStorage(SettingKey.delayIncludedInTime) var delayTimeIntegrated = false
    @AppStorage(SettingKey.regularTripAlertsOnThisDevice) var regularTripAlerts = RegularTripAlerts.defaultOnThisDevice
    @AppStorage(SettingKey.regularTripRemindersOnThisDevice) var regularTripReminders = RegularTripAlerts.defaultOnThisDevice
    @AppStorage(SettingKey.savedTripAutoTrackMinutes) var savedTripAutoTrack = 0
    @AppStorage(SettingKey.savedTripReminderMinutes) var savedTripReminder = SavedTripReminders.off
    @AppStorage(SettingKey.iCloudSync) private var iCloudSync = true
    @Environment(SavedTripsModel.self) private var savedTripsModel
    @Environment(FavoritesViewModel.self) private var favoritesViewModel
    @Environment(FavoritePlacesModel.self) private var favoritePlaces
    @State var showMail: Bool = false
    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                homeSection
                departuresSection
                regularTripsSection
                savedTripsSection
                syncSection
                helpSection
                Text(verbatim: Self.version)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 30)
        }
        .readableScrollContent()
        .navigationTitle("Paramètres")
        .sheet(isPresented: $showMail) {
            MailComposerViewController(recipients: ["tpgnext@protonmail.ch"], subject: "Feedback", messageBody: "Bonjour !")
                .presentationDetents([.fraction(0.9)])
                .presentationCornerRadius(35)
        }
    }

    // MARK: Sections

    private var homeSection: some View {
        CardSection("Accueil") {
            choice("Départs affichés", selection: $homeFavorites, first: "Arrêts proches", second: "Favoris")
            CardDivider(inset: 0)
            CardLink(.homeLayout) {
                SettingsRow("Organiser l'accueil", systemImage: "rectangle.3.group.fill", color: .blue, showsChevron: true)
            }
            CardDivider()
            CardLink(.favoritesOrder) {
                SettingsRow("Arrêts favoris", systemImage: "star.fill", color: .yellow,
                            value: favoritesViewModel.favoriteStops.count, showsChevron: true)
            }
            CardDivider()
            CardLink(.favoritePlacesOrder) {
                SettingsRow("Lieux favoris", systemImage: "mappin", color: .red,
                            value: favoritePlaces.places.count, showsChevron: true)
            }
        }
    }

    private var departuresSection: some View {
        CardSection("Affichage des départs") {
            choice("Tri par défaut", selection: $groupedDefault, first: "Par horaire", second: "Par ligne")
            CardDivider(inset: 0)
            choice("Heure affichée par défaut", selection: $timeDefault, first: "Temps restant, 14'", second: "Heure, 12:34")
            CardDivider(inset: 0)
            choice("Format du retard", selection: $delayTimeIntegrated, first: "12:31 (+3')", second: "12:34")
                // Le widget formate les départs avec ce réglage : il faut le recopier dans le groupe d'app.
                .onChange(of: delayTimeIntegrated) {
                    SharedStorage.mirrorSettings()
                    WidgetCenter.shared.reloadAllTimelines()
                }
        }
    }

    private var regularTripsSection: some View {
        CardSection("Trajets réguliers",
                    footer: "Le délai du rappel se choisit dans chaque trajet. Vos trajets réguliers sont partagés entre vos appareils via iCloud : activez ces notifications sur un seul pour ne pas être prévenu en double.") {
            Toggle(isOn: $regularTripReminders) {
                SettingsRow("Rappels avant le départ", systemImage: "bell.fill", color: .red)
            }
            .onChange(of: regularTripReminders) {
                if regularTripReminders { NotificationManager.shared.requestAuthorization() }
                RegularTripAlerts.scheduleReminders(for: .shared)
                RegularTripsModel.shared.scheduleBackgroundRefresh()
            }
            CardDivider()
            Toggle(isOn: $regularTripAlerts) {
                SettingsRow("Retards et suivi en direct", systemImage: "exclamationmark.triangle.fill", color: .orange)
            }
            .onChange(of: regularTripAlerts) {
                if regularTripAlerts { NotificationManager.shared.requestAuthorization() }
                RegularTripsModel.shared.scheduleBackgroundRefresh()
            }
        }
    }

    private var savedTripsSection: some View {
        CardSection("Itinéraires enregistrés",
                    footer: "Le rappel compte depuis l'heure de partir, marche jusqu'à l'arrêt comprise. L'activité en direct démarre d'elle-même avant le départ ; iOS ne la laisse démarrer que l'app ouverte : une notification vous invite à l'ouvrir au bon moment. Réglages propres à cet appareil.") {
            HStack {
                SettingsRow("Rappel avant le départ", systemImage: "bell.fill", color: .red)
                Picker("Rappel avant le départ", selection: $savedTripReminder) {
                    ForEach(SavedTripReminders.choices, id: \.self) { minutes in
                        Text(SavedTripReminders.label(for: minutes))
                            .tag(minutes)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .fixedSize()
            }
            .onChange(of: savedTripReminder) {
                if savedTripReminder != SavedTripReminders.off {
                    NotificationManager.shared.requestAuthorization()
                }
                savedTripsModel.scheduleNotifications()
            }
            CardDivider()
            HStack {
                SettingsRow("Suivi en direct automatique", systemImage: "inset.filled.circle", color: .green)
                Picker("Suivi en direct automatique", selection: $savedTripAutoTrack) {
                    ForEach(SavedTripAutoTracking.choices, id: \.self) { minutes in
                        Text(minutes == 0 ? "Désactivé" : "\(minutes) min avant")
                            .tag(minutes)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .fixedSize()
            }
            .onChange(of: savedTripAutoTrack) {
                if savedTripAutoTrack > 0 { NotificationManager.shared.requestAuthorization() }
                savedTripsModel.scheduleNotifications()
            }
        }
    }

    private var syncSection: some View {
        CardSection("Vos données",
                    footer: "Vos favoris, lieux, itinéraires enregistrés et trajets réguliers se retrouvent sur tous vos appareils. Désactivée, ils restent sur cet appareil ; ce qui est déjà dans iCloud n'est pas effacé.") {
            Toggle(isOn: $iCloudSync) {
                SettingsRow("Synchronisation iCloud", systemImage: "icloud.fill", color: .cyan)
            }
            .onChange(of: iCloudSync) {
                CloudSync.settingChanged()
            }
        }
    }

    private var helpSection: some View {
        CardSection("Aide") {
            CardLink(.userGuide) {
                SettingsRow("Guide d'utilisation", subtitle: "Tout ce que l'app sait faire, à essayer du doigt.",
                            systemImage: "book.pages.fill", color: .accent, showsChevron: true)
            }
            CardDivider()
            Button {
                // Sans compte configuré dans Mail (fréquent sur iPad), le
                // compositeur plante : on passe alors par l'app de messagerie par défaut.
                if MFMailComposeViewController.canSendMail() {
                    showMail.toggle()
                } else if let url = URL(string: "mailto:tpgnext@protonmail.ch?subject=Feedback") {
                    openURL(url)
                }
            } label: {
                SettingsRow("Un problème, une question, une envie ?", systemImage: "envelope.fill", color: .indigo)
            }
            .buttonStyle(.plain)
        }
    }

    /// Un choix entre deux options, sous son titre : un sélecteur segmenté du système.
    private func choice(_ title: LocalizedStringKey, selection: Binding<Bool>,
                        first: LocalizedStringKey, second: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
            Picker(selection: selection) {
                Text(first).tag(false)
                Text(second).tag(true)
            } label: {
                Text(title)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
        .padding(.vertical, 12)
        .sensoryFeedback(.selection, trigger: selection.wrappedValue)
    }

    /// « tpg Next 3.2 (145) ».
    private static var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? ""
        let build = info?["CFBundleVersion"] as? String ?? ""
        return "tpg Next \(short) (\(build))"
    }
}

struct FavoritesOrderView: View {
    @Environment(StopStore.self) var stopStore
    @Environment(FavoritesViewModel.self) var favoritesViewModel
//    @Binding var orderFavorites: Bool
    
    var body: some View {
                List {
                    ForEach(favoritesViewModel.favoriteStops) { favorite in
                            SmallStopTitleView(stopName: favorite.name)
                                .heightGrowingWithText(30)
                                .padding(.horizontal, 20)
                    }
                    .onMove { indices, newOffset in
                        favoritesViewModel.moveFavorite(fromOffsets: indices, toOffset: newOffset)
                    }
                    .onDelete { indices in
                        favoritesViewModel.removeFavoriteIndex(atOffsets: indices)
                    }
                    .listRowBackground(
                        BasicElement()
                            .padding(.vertical, 5)
                            .padding(.horizontal, 60)
                    )
                    .listRowSeparator(.hidden)
                }
//                .contentMargins(.top, 60.0, for: .automatic)
                .contentMargins(.bottom, 20.0, for: .automatic)
                .contentMargins(.horizontal, 5.0, for: .automatic)
                .listStyle(.plain)
                .environment(\.editMode, .constant(.active))
                .readableList()
//                .mask {
//                    Rectangle()
//                        .overlay(alignment: .leading) {
//                            ScrollMask(leading: true, vertical: false, gradientLength: 20)
//                        }
//                        .padding(.leading, 5)
//                }
    }
}

//struct SettingsMainView: View {
//    @State var orderfavorites: Bool = false
//    @State var manageNotifications: Bool = false
//    @Binding var showSettings: Bool
//    var body: some View {
//        if orderfavorites {
//            FavoritesOrderView()
//                .transition(.move(edge: .trailing))
//        } else if manageNotifications {
//            ScheduledNotifications()
//                .transition(.move(edge: .trailing))
//        } else {
//            SettingsView()
//                .transition(.move(edge: .leading))
//        }
//    }
//}

struct MailComposerViewController: UIViewControllerRepresentable {
    @Environment(\.dismiss) var dismiss
    var recipients: [String]
    var subject: String
    var messageBody: String

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let mailComposer = MFMailComposeViewController()
        mailComposer.mailComposeDelegate = context.coordinator
        mailComposer.setToRecipients(recipients)
        mailComposer.setSubject(subject)
        mailComposer.setMessageBody(messageBody, isHTML: false)
        return mailComposer
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        return Coordinator(self)
    }

    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        var parent: MailComposerViewController

        init(_ parent: MailComposerViewController) {
            self.parent = parent
        }

        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            parent.dismiss()
        }
    }
}


#Preview("Réglages") {
    SettingsView()
        .previewEnvironment()
}

#Preview("Réglages — tout activé") {
    SettingsView()
        .previewSettings([SettingKey.homeShowsFavorites: true, SettingKey.groupByLineByDefault: true,
                          SettingKey.clockTimeByDefault: true, SettingKey.delayIncludedInTime: true])
        .previewEnvironment()
}

#Preview("Arrêts favoris") {
    FavoritesOrderView()
        .navigationTitle("Arrêts favoris" as String)
        .previewEnvironment()
}

#Preview("Rappels prévus") {
    ScheduledNotifications()
        .navigationTitle("Rappels prévus" as String)
        .previewEnvironment()
}

#Preview("Rappels prévus — feuille") {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            ScheduledNotificationsSheet()
        }
        .previewEnvironment(navigation: false)
}
