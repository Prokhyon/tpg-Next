//
//  WelcomeView.swift
//  tpg Next
//
//  Created by Loris Thomas on 16.10.2024.
//

import SwiftUI
import MapKit
import tpgNextFunc

enum welcomePage {
    case page1
    case page2
    case page3
}

struct WelcomeView: View {
    @Binding var viewingWelcome: Bool
    @State private var page: welcomePage = .page1
    var body: some View {
        VStack {
                switch page {
                case .page1: WelcomePage1(page: $page, viewingWelcome: $viewingWelcome).padding().scrollingWhenTooTall().transition(.opacity)
                case .page2: WelcomePage2(page: $page, viewingWelcome: $viewingWelcome).padding().scrollingWhenTooTall().transition(.opacity)
                case .page3: WelcomePage3(page: $page, viewingWelcome: $viewingWelcome).padding().scrollingWhenTooTall().transition(.opacity)
                }
            HStack(spacing: 10) {
                Spacer()
                Circle()
                    .frame(width: page == .page1 ? 10 : 5)
                    .foregroundStyle(.primary)
                Circle()
                    .frame(width: page == .page2 ? 10 : 5)
                    .foregroundStyle(.primary)
                Circle()
                    .frame(width: page == .page3 ? 10 : 5)
                    .foregroundStyle(.primary)
                Spacer()
            }
            .padding(.bottom, 5)
        }
    }
    
    struct WelcomePage1: View {
        @Binding var page: welcomePage
        @Binding var viewingWelcome: Bool
        @State var locationManager = LocationManager()
        let notificationManager = NotificationManager.shared
        @AppStorage(SettingKey.notificationAsked) var notificationAuthorizationAsked = false
        
        var body: some View {
            VStack(alignment: .leading) {
                Text("Bienvenue").font(.largeTitle).bold()
                Text("Merci d'avoir téléchargé tpg Next").font(.headline)
                Spacer()
                Text("Voici quelques astuces pour vous aider à démarrer.\nRevoyez les à tout moment depuis les paramètres.")
                Spacer()
                Text("Dans un premier temps, quelques autorisations afin d'améliorer votre expérience:")
                Spacer()
                Text("Accès à votre géolocalisation:").font(.callout).bold()
                Text("Permet d'afficher les arrêts à proximité ainsi que votre position sur la carte.")
                Button {
                    if locationManager.locationStatus == .notDetermined {
                        locationManager.requestLocationAuthorization()
                    } else {
                        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {

                           UIApplication.shared.open(settingsUrl)

                         }
                    }
                } label: {
                    if locationManager.locationStatus == .authorizedWhenInUse || locationManager.locationStatus == .authorizedAlways {
                        HStack(spacing: 10) {
                            Text("Accès autorisé")
                            Image(systemName: "checkmark")
                        }
                        .foregroundStyle(.accent)
                        .frame(maxWidth: .infinity)
                        .basicElementBackground(minHeight: 40)
                    } else if locationManager.locationStatus == .denied {
                        HStack(spacing: 10) {
                            Text("Accès refusé")
                            Image(systemName: "xmark")
                        }
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity)
                        .basicElementBackground(minHeight: 40)
                    } else {
                    Text("Choisir")
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .basicElementBackground(minHeight: 40, button: true)
                    }
                }
                Spacer()
                Text("Notifications").font(.callout).bold()
                Text("Permet de programmer et recevoir des rappels de départ d'un véhicule")
                Button {
                    if notificationAuthorizationAsked {
                        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                            
                            UIApplication.shared.open(settingsUrl)
                            
                        }
                    } else {
                        notificationManager.requestAuthorization()
                        notificationAuthorizationAsked = true
                    }
                } label: {
                    if notificationAuthorizationAsked {
                        if notificationManager.isNotificationAuthorized {
                            HStack(spacing: 10) {
                                Text("Accès autorisé")
                                Image(systemName: "checkmark")
                            }
                            .foregroundStyle(.accent)
                            .frame(maxWidth: .infinity)
                            .basicElementBackground(minHeight: 40)
                        } else if !notificationManager.isNotificationAuthorized {
                            HStack(spacing: 10) {
                                Text("Accès refusé")
                                Image(systemName: "xmark")
                            }
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity)
                            .basicElementBackground(minHeight: 40)
                        }
                    } else {
                        Text("Choisir")
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .basicElementBackground(minHeight: 40, button: true)
                    }
                }
                Spacer()
                if notificationAuthorizationAsked && locationManager.locationStatus != .notDetermined {
                    if #available (iOS 26, *) {
                        Button {
                            withAnimation(.easeInOut) {
                                page = .page2
                            }
                        } label: {
                            Text("Suivant").foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(minHeight: 30)
                        }
                        .buttonStyle(.glassProminent)
                        .disabled(notificationAuthorizationAsked && locationManager.locationStatus != .notDetermined ? false : true)
                    } else {
                        Button {
                            withAnimation(.easeInOut) {
                                page = .page2
                            }
                        } label: {
                            Text("Suivant").foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(minHeight: 30)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(notificationAuthorizationAsked && locationManager.locationStatus != .notDetermined ? false : true)
                    }
                } else {
                    Rectangle()
                        .frame(height:50)
                        .foregroundStyle(.clear)
                }
            }
            .onAppear {
                notificationManager.checkAuthorizationStatus()
            }
        }
    }
    struct WelcomePage2: View {
        @Environment(FavoritesViewModel.self) var favoritesViewModel
        @Binding var page: welcomePage
        @Binding var viewingWelcome: Bool
        @State var favorite = false
        @State var stopCornavin = Stop(name: "Genève, gare Cornavin", sloid: "ch:1:sloid:87057", codedidoc: "8587057", country: "CH", canton: "Genève", meansOfTransport: "BUS", wgs84Coordinates: Coordinates(lon: 46.20973474672, lat: 6.14243773412))
        @State private var resultDetail: searchResultItem?
        
        var body: some View {
            VStack(alignment: .leading) {
                HStack {
                    Button(action: {
                        withAnimation(.easeInOut) {
                            page = .page1
                        }
                    }) {
                        HStack {
                            Image(systemName: "chevron.backward")
                            Text("Retour")
                        }
                    }
                    Spacer()
                    Button {
                        withAnimation(.easeInOut) {
                            viewingWelcome = false
                        }
                    } label: {
                       Image(systemName: "xmark").font(.title2)
                    }
                }
                .padding(.bottom, 5)
                
                Text("Itinéraires").font(.title2).bold()
                Text("Lors d'une recherche d'un arrêt ou d'un lieu, appuyez sur l'icône à la droite d'un résultat afin d'obtenir un aperçu de sa position sur une carte.\n\nAjoutez aussi facilement des arrêts à vos favoris avec l'étoile.")
                Text("\nTestez ici:").font(.footnote)
                
                BasicElement()
                    .frame(height: 45)
                    .overlay(
                        HStack {
                            Button(action: {
                                if favoritesViewModel.isFavorite(stopCornavin) {
                                    favoritesViewModel.removeFavoriteStop(stopCornavin)
                                } else {
                                    favoritesViewModel.addFavorite(stopCornavin)
                                }
                            }) {
                                Image(systemName: favoritesViewModel.isFavorite(stopCornavin) ? "star.fill" : "star").foregroundStyle(.accent)
                            }
                            SmallStopTitleView(stopName: "Genève, gare Cornavin")
                            Spacer()
                            Button(action: {
                                    resultDetail = searchResultItem(title: "Genève, gare Cornavin", coordinates: CLLocationCoordinate2D(latitude: 46.20973474672, longitude: 6.14243773412))
                            }) {
                                Image(systemName: "figure.wave.circle").font(.title2).foregroundStyle(.accent)
                            }
                        }
                                .padding(.horizontal)
                        
                    )
                Spacer()
                Text("Notifications").font(.title2).bold()
                Text("Appuyez longuement sur un horaire pour programmer un rappel. Vous pourrez voir les rappels prévus depuis les paramètres.")
                Text("De plus, vous serez prévenu en cas d'avance ou retard du véhicule. ")
                Text("\nTestez ici: (Le rappel ne sera pas programmé)").font(.footnote)
                notificationTestView()
                Spacer()
                if #available (iOS 26, *) {
                    Button {
                        withAnimation(.easeInOut) {
                            page = .page3
                        }
                    } label: {
                        Text("Suivant").foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 30)
                    }
                    .buttonStyle(.glassProminent)
                } else {
                    Button {
                        withAnimation(.easeInOut) {
                            page = .page3
                        }
                    } label: {
                        Text("Suivant").foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 30)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .sheet(item: $resultDetail) { detail in
                MapPreview(resultDetail: detail, position: .region(MKCoordinateRegion(center: detail.coordinates, span: MKCoordinateSpan(latitudeDelta: 0.007, longitudeDelta: 0.007))))
                    .presentationDetents([.medium, .fraction(0.9)])
                    .presentationCornerRadius(30)
            }
        }
    }
    struct WelcomePage3: View {
        @Binding var page: welcomePage
        @Binding var viewingWelcome: Bool
        @State var showTime: Bool = true
        @State var favorite = false
        @State var viewLineSorted = false
        @State var filterLines = false
        @State var earlier = false
        @State var later = false
        var body: some View {
            VStack(alignment: .leading) {
                HStack {
                    Button(action: {
                        withAnimation(.easeInOut) {
                            page = .page2
                        }
                    }) {
                        HStack {
                            Image(systemName: "chevron.backward")
                            Text("Retour")
                        }
                    }
                    Spacer()
                    Button {
                        withAnimation(.easeInOut) {
                            viewingWelcome = false
                        }
                    } label: {
                        Image(systemName: "xmark").font(.title2)
                    }
                }
                .padding(.bottom, 5)
//                Spacer()
                Text("Quelques boutons utiles:").font(.title3)
                Text("Testez-les !").font(.subheadline)
                Spacer()
                HStack {
                    VStack(spacing: 10) {
                        ShowTimeButton(showTime: $showTime)
//                        Button(action: {
//                            showTime.toggle()
//                        }) {
//                            Image(systemName: showTime ? "hourglass.circle" : "hourglass.circle.fill").font(.largeTitle)
//                        }
//                        .padding(.horizontal)
                        Text(showTime ? "12:34" : "14'")
                    }
                    .padding()
                    
                    Text("Changez l'affichage de l'heure d'arrivée d'un véhicule entre son horaire et le temps restant")
                }
                Spacer()
                HStack {
                        Menu {
                            Button(action: {
                            }) {
                                Label("Partir d'ici", systemImage: "point.bottomleft.forward.to.point.topright.filled.scurvepath")
                            }
                            Button(action: {
                            }) {
                                Label("Aller ici", systemImage: "point.bottomleft.filled.forward.to.point.topright.scurvepath")
                            }
                            Button(action: {
                            }) {
                                Label("Trajet rapide", systemImage: "point.bottomleft.forward.to.arrow.triangle.scurvepath")
                            }
                        } label: {
                        Image(systemName: "point.bottomleft.forward.to.point.topright.filled.scurvepath")
                            .font(.title)
                            .foregroundStyle(.foreground)
                    }
                        .padding()
                    Text("Lancez rapidement une recherche d'itinéraire depuis un arrêt")
                }
                Spacer()
                HStack {
                        Button(action: {
                            viewLineSorted.toggle()
                        }) {
                            Image(systemName: viewLineSorted ? "text.justify" : "rectangle.grid.1x2.fill")
                                .contentTransition(.symbolEffect(.replace.upUp.byLayer))
                                .padding()
                                .foregroundStyle(.foreground)
                        }
                    Text("Alternez entre le tri par horaire et par ligne")
                }
                Spacer()
                HStack {
                    Filterbutton(filterLines: $filterLines, viewLineFiltered: $filterLines)
                    Text("Filtrez les départs affichés par ligne")
                    }

                    Spacer()
                HStack {
                    HStack {
                        Button(action: {
                            earlier.toggle()
                        }) {
                            Image(systemName: "text.line.first.and.arrowtriangle.forward")
                                .symbolEffect(.bounce.down.byLayer, value: earlier)
                                .padding()
                                .foregroundStyle(.foreground)
                        }
                        Button(action: {
                            later.toggle()
                        }) {
                            Image(systemName: "text.line.last.and.arrowtriangle.forward")
                                .symbolEffect(.bounce.down.byLayer, value: later)
                                .padding()
                                .foregroundStyle(.foreground)
                        }
                    }
                    Text("Affichez les départs précédents ou suivants")
                }
                
                HStack {
                    
                }
                Spacer()
                if #available (iOS 26, *) {
                    Button {
                        withAnimation(.easeInOut) {
                            viewingWelcome = false
                        }
                    } label: {
                        Text("Terminer").foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 30)
                    }
                    .buttonStyle(.glassProminent)
                } else {
                    Button {
                        withAnimation(.easeInOut) {
                            viewingWelcome = false
                        }
                    } label: {
                        Text("Terminer").foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 30)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }
}

struct notificationTestView: View {
    var body: some View {
        BasicElement()
            .frame(height: 50)
            .overlay(
                HStack {
                    BusLineIcon(lineName: "12", operatorName: "Transports Publics Genevois")
                    Image(systemName: "arrow.right")
                    SmallStopTitleView(stopName: "Lancy-Bachet, gare")
                    Spacer()
                            Text("12:34").frame(width: 50)
                        QuayIcon(quay: "C")
                    }
                    .padding(.horizontal)
            )
            .padding(5)
            .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: 20))
            .contextMenu {
                ForEach([0.0, 1.0, 5.0, 10.0, 30.0], id: \.self) { timeDelay in
                    Button(action: {
                    }) {
                        Text(notificationLabel(for: timeDelay))
                    }
                }
            }
    }
        private func notificationLabel(for timeDelay: Double) -> String {
            switch timeDelay {
            case 0.0:
                return "Prévenir à l'arrivée"
            case 1.0:
                return "Prévenir 1' avant"
            case 5.0:
                return "Prévenir 5' avant"
            case 10.0:
                return "Prévenir 10' avant"
            case 30.0:
                return "Prévenir 30' avant"
            default:
                return ""
            }
        }
}

#Preview("Bienvenue") {
    @Previewable @State var welcome = true
    WelcomeView(viewingWelcome: $welcome)
        .previewEnvironment(navigation: false, favorites: [])
}

#Preview("Bienvenue — page 1") {
    @Previewable @State var page = welcomePage.page1
    WelcomeView.WelcomePage1(page: $page, viewingWelcome: .constant(true))
        .padding()
        .previewEnvironment(navigation: false, favorites: [])
}

#Preview("Bienvenue — page 2") {
    @Previewable @State var page = welcomePage.page2
    WelcomeView.WelcomePage2(page: $page, viewingWelcome: .constant(true))
        .padding()
        .previewEnvironment(navigation: false, favorites: [])
}

#Preview("Bienvenue — page 3") {
    @Previewable @State var page = welcomePage.page3
    WelcomeView.WelcomePage3(page: $page, viewingWelcome: .constant(true))
        .padding()
        .previewEnvironment(navigation: false, favorites: [])
}
