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

struct SettingsView: View {
    @AppStorage("homeFavorites") var homeFavorites = false
    @AppStorage("translucentUI") var translucentUI = false
    @AppStorage("GoupedDefault") var groupedDefault = false
    @AppStorage("TimeDefault") var timeDefault = false
    @AppStorage("DelayTimeIntegrated") var delayTimeIntegrated = false
    @AppStorage("ShowWelcome") var showWelcome = true
    @Namespace private var animation
    @State private var circleButtonMessage = false
    @State var showMail: Bool = false
        
    var body: some View {
//        NavigationView {
//            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 0) {
                        HStack(spacing: 10) {
                                    NavigationLink {
                                        FavoritesOrderView()
                                            .navigationTitle("Ordre des favoris")
                                    } label: {
                                        BasicElement()
                                            .frame(height: 50)
                                            .padding(.vertical, 5)
                                            .overlay(
                                        HStack {
                                            Text("Ordre des favoris").minimumScaleFactor(0.5)
                                            Spacer()
                                            Image(systemName: "chevron.right")
                                        }
                                        .padding()
                                        )
                                    }
                            NavigationLink {
                                ScheduledNotifications()
                                    .navigationTitle("Rappels prévus")
                            } label: {
                                BasicElement()
                                    .frame(height: 50)
                                    .padding(.vertical, 5)
                                    .overlay(
                                HStack {
                                    Spacer()
                                    Text("Rappels prévus").minimumScaleFactor(0.5).padding(.vertical, 5)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                }
                                .padding(.horizontal)
                                .frame(height: 50)
                                )
                            }
                        }
                        
                        HStack(alignment: .bottom) {
                            Text("Général")
                                .font(.headline)
                                .padding(.leading, 3)
                            Spacer()
                        }
                        .padding(.top, 10)
                        VStack(alignment: .leading, spacing: 10) {
                            VStack(alignment: .leading, spacing: 5) {
                                Text("Départs sur la page d'accueil:")
                                CustomPicker(secondSelected: $homeFavorites, height: 40, firstOption: String(localized:"Proches"), firstIcon: "location.circle", secondOption: String(localized:"Favoris"), secondIcon: "star", name: "homeDeparture", animation: animation)
                            }
                        }
                        .padding()
                        .padding(.vertical, 5)
                        .background (
                            BasicCard(cornerRadius: 30)
                                .padding(.vertical, 5)
                        )
                        
                        
                        HStack(alignment: .bottom) {
                            Text("Affichage des départs")
                                .font(.headline)
                                .padding(.leading, 3)
                            Spacer()
                        }
                        .padding(.top, 10)
                        VStack(alignment: .leading, spacing: 10) {
                            VStack(alignment: .leading, spacing: 5) {
                                Text("Tri par défaut:")
                                CustomPicker(secondSelected: $groupedDefault, height: 40, firstOption: String(localized:"Horaire"), firstIcon: "text.justify" , secondOption: String(localized:"Ligne"), secondIcon: "rectangle.grid.1x2.fill",name: "sort", animation: animation)
                            }
                            VStack(alignment: .leading, spacing: 5) {
                                Text("Heure d'arrivée par défaut:")
                                CustomPicker(secondSelected: $timeDefault, height: 40, firstOption: "14'", firstIcon: "hourglass.circle.fill", secondOption: "12:34", secondIcon: "hourglass.circle", name: "time", animation: animation)
                            }
                            VStack(alignment: .leading, spacing: 5) {
                                Text("Format du retard:")
                                CustomPicker(secondSelected: $delayTimeIntegrated, height: 40, firstOption: "12:31 (+3')", secondOption: "12:34", name: "delay", animation: animation)
                                    // Le widget formate les départs avec ce réglage :
                                    // il faut le recopier dans le groupe d'app.
                                    .onChange(of: delayTimeIntegrated) {
                                        SharedStorage.mirrorSettings()
                                        WidgetCenter.shared.reloadAllTimelines()
                                    }
                            }
                        }
                        .padding(.vertical, 5)
                        .padding()
                        .background(
                            BasicCard(cornerRadius: 30)
                                .padding(.vertical, 5)
                        )
                        Button {
                            showWelcome = true
                        } label: {
                            BasicElement()
                                .frame(height: 50)
                                .overlay(
                                    HStack {
                                        Text("Revoir le message de démarrage")
                                        Spacer()
                                        if #available(iOS 18, *) {
                                            Image(systemName: "text.page.fill")
                                        } else {
                                            Image(systemName: "doc.plaintext.fill")
                                        }
                                    }
                                        .padding(.horizontal)
                                )
                                .padding(.vertical, 5)
                        }
                        
                        Button {
                            showMail.toggle()
                        } label: {
                            BasicElement()
                                .frame(height: 50)
                                .overlay(
                                    HStack {
                                        Text("Un problème, une question, une envie ?")
                                        Spacer()
                                        if #available(iOS 18, *) {
                                            Image(systemName: "bubble.and.pencil")
                                        } else {
                                            Image(systemName: "exclamationmark.bubble")
                                        }
                                    }
                                        .padding(.horizontal)
                                )
                                .padding(.vertical, 5)
                        }
//                        Spacer()
                    }
                    .padding(.horizontal, 10)
                }
//                .scrollDisabled(UIScreen.main.bounds.height > 820)

//            }
            .navigationTitle("Paramètres")
//        }
        .sheet(isPresented: $showMail) {
                    MailComposerViewController(recipients: ["tpgnext@protonmail.ch"], subject: "Feedback", messageBody: "Bonjour !")
                    .presentationDetents([.fraction(0.9)])
                    .presentationCornerRadius(35)
                }
    }
}

struct FavoritesOrderView: View {
    @EnvironmentObject var stopStore: StopStore
    @EnvironmentObject var favoritesViewModel: FavoritesViewModel
//    @Binding var orderFavorites: Bool
    
    var body: some View {
                List {
                    ForEach(favoritesViewModel.favoriteStops) { favorite in
                            SmallStopTitleView(stopName: favorite.name)
                                .frame(height: 30)
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
//                .mask {
//                    Rectangle()
//                        .overlay(alignment: .leading) {
//                            ScrollMask(leading: true, vertical: false, gradientLength: 20)
//                        }
//                        .padding(.leading, 5)
//                }
    }
}

struct ScheduledNotifications: View {
    @ObservedObject var transportNotificationManager = BusNotificationManager.shared
    
    let notificationManager = NotificationManager.shared
    
//    @Binding var manageNotifications: Bool
    
    var body: some View {
            VStack {
                if transportNotificationManager.scheduledNotificationIdentifiers.isEmpty {
                    Text("Aucun rappel programmé")
                        .frame(height: 50)
                } else {
                    ScrollView {
                        ForEach(Array(transportNotificationManager.scheduledNotificationIdentifiers.keys), id: \.self) { key in
                            let stopEvent = transportNotificationManager.scheduledNotificationIdentifiers[key]!
                            
                            BasicCard()
                                .frame(height: 120)
                                .overlay(
                                    HStack {
                                        VStack(spacing: 0) {
                                            HStack {
                                                SmallStopTitleView(stopName: stopEvent.stopPointName)
                                                Spacer()
                                                let notificationInterval = Int(parseIdentifier(key)?.notificationInterval ?? 0)
                                                Text(notificationInterval == 0 ? "Rappel à l'arrivée" : "Rappel \(notificationInterval)' avant")
                                            }
                                            .padding(5)
                                            StopEventView(event: stopEvent, showTime: true)
                                        }
                                        
                                        Button(action: {
                                                let timeId = "timetable_\(key)"
                                                let estId = "estimated_\(key)"
                                            withAnimation(.easeInOut) {
                                                transportNotificationManager.cancelScheduledNotifications(timetableIdentifier: timeId, estimatedIdentifier: estId, completeCancel: true)
                                            }
                                        }) {
                                            Image(systemName: "xmark.circle.fill").font(.title2)
                                        }
                                        .padding(5)
                                    }
                                        .padding(.horizontal, 15)
                                )
                                .padding(.vertical, 5)
                                .padding(.horizontal, 10)
                                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .opacity))
                        }
                            
                    }
//                    .contentMargins(.top, 60.0, for: .automatic)
                }
        }
        // La liste ne survit pas à une relance : on la relit auprès du système.
        .onAppear {
            transportNotificationManager.refreshScheduledNotifications()
        }
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


struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        let stopStore = StopStore()
        let favoritesViewModel = FavoritesViewModel()
        
        return SettingsView()
            .environmentObject(stopStore)
            .environmentObject(favoritesViewModel)
    }
}
