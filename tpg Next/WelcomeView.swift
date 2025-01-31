//
//  WelcomeView.swift
//  tpg Next
//
//  Created by Loris Thomas on 16.10.2024.
//

import SwiftUI
import MapKit

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
                case .page1: WelcomePage1(page: $page, viewingWelcome: $viewingWelcome).transition(.opacity).padding()
                case .page2: WelcomePage2(page: $page, viewingWelcome: $viewingWelcome).transition(.opacity).padding()
                case .page3: WelcomePage3(page: $page, viewingWelcome: $viewingWelcome).transition(.opacity).padding()
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
        @StateObject var locationManager = LocationManager()
        let notificationManager = NotificationManager.shared
        @AppStorage("NotificationAsked") var notificationAuthorizationAsked = false
        
        var body: some View {
            VStack(alignment: .leading) {
                Text("Bienvenue").font(.largeTitle).bold()
                Text("merci d'avoir téléchargé tpg Next").font(.headline)
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
                        RoundedRectangle(cornerRadius: 15)
                            .fill(.thinMaterial)
                            .frame(height: 40)
                            .shadow(color: Color.customShadows, radius: 1.5, y: 1)
                            .overlay(HStack(spacing: 10) {
                                Text("Accès autorisé")
                                Image(systemName: "checkmark")
                            }.foregroundStyle(.accent))
                    } else if locationManager.locationStatus == .denied {
                        RoundedRectangle(cornerRadius: 15)
                            .fill(.thinMaterial)
                            .frame(height: 40)
                            .shadow(color: Color.customShadows, radius: 1.5, y: 1)
                            .overlay(HStack(spacing: 10) {
                                Text("Accès refusé")
                                Image(systemName: "xmark")
                            }.foregroundStyle(.red))
                    } else {
                        RoundedRectangle(cornerRadius: 15)
                            .fill(.accent)
                            .frame(height: 40)
                            .shadow(color: Color.customShadows, radius: 1.5, y: 1)
                            .overlay(Text("Choisir").foregroundStyle(.white))
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
                            RoundedRectangle(cornerRadius: 15)
                                .fill(.thinMaterial)
                                .frame(height: 40)
                                .shadow(color: Color.customShadows, radius: 1.5, y: 1)
                                .overlay(HStack(spacing: 10) {
                                    Text("Accès autorisé")
                                    Image(systemName: "checkmark")
                                }.foregroundStyle(.accent))
                        } else if !notificationManager.isNotificationAuthorized {
                            RoundedRectangle(cornerRadius: 15)
                                .fill(.thinMaterial)
                                .frame(height: 40)
                                .shadow(color: Color.customShadows, radius: 1.5, y: 1)
                                .overlay(HStack(spacing: 10) {
                                    Text("Accès refusé")
                                    Image(systemName: "xmark")
                                }.foregroundStyle(.red))
                        }
                    } else {
                        RoundedRectangle(cornerRadius: 15)
                            .fill(.accent)
                            .frame(height: 40)
                            .shadow(color: Color.customShadows, radius: 1.5, y: 1)
                            .overlay(Text("Choisir").foregroundStyle(.white))
                    }
                }
                Spacer()
                if notificationAuthorizationAsked && locationManager.locationStatus != .notDetermined {
                    Button {
                        withAnimation(.easeInOut) {
                            page = .page2
                        }
                    } label: {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(.accent)
                            .frame(height: 50)
                            .shadow(color: Color.customShadows, radius: 1.5, y: 1)
                            .overlay(Text("Suivant").foregroundStyle(.white))
                    }
                    .disabled(notificationAuthorizationAsked && locationManager.locationStatus != .notDetermined ? false : true)
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
        @EnvironmentObject var favoritesViewModel: FavoritesViewModel
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
                Text("Lors d'une recherche d'un arrêt ou lieu, appuyez sur l'icône à la droite d'un résultat afin d'afficher une carte et vérifier la position de celui-ci.")
                Text("\nTestez ici:")
                
                RoundedRectangle(cornerRadius: 20)
                    .fill(.thinMaterial)
                    .frame(height: 45)
                    .shadow(color: Color.customShadows, radius: 1.5, y: 1)
                    .overlay(
                        HStack {
                            Button(action: {
                                if favoritesViewModel.isFavorite(stopCornavin) {
                                    favoritesViewModel.removeFavoriteStop(stopCornavin)
                                } else {
                                    favoritesViewModel.addFavorite(stopCornavin)
                                }
                            }) {
                                Image(systemName: favoritesViewModel.isFavorite(stopCornavin) ? "star.fill" : "star")
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
                Text("Depuis n'importe quel événement de véhicule, appuyez longuement pour afficher le menu de programmation de rappel. Vous pourrez voir les rappels programmés depuis les paramètres")
                Text("Ces rappels vérifieront l'heure réelle d'arrivée d'un véhicule avant celle-ci et s'y adaptent.")
                Text("\nTestez ici:")
                notificationTestView()
                Spacer()
                Button {
                    withAnimation(.easeInOut) {
                        page = .page3
                    }
                } label: {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.accent)
                        .frame(height: 50)
                        .shadow(color: Color.customShadows, radius: 1.5, y: 1)
                        .overlay(Text("Suivant").foregroundStyle(.white))
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
        @State var showTime: Bool = false
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
                Spacer()
                HStack {
                    VStack(spacing: 10) {
                        Button(action: {
                            showTime.toggle()
                        }) {
                            Image(systemName: showTime ? "hourglass.circle" : "hourglass.circle.fill").font(.largeTitle)
                        }
                        .padding(.horizontal)
                        Text(showTime ? "12:34" : "14'")
                    }
                    
                    Text("Utilisez ce bouton pour changer l'affichage de l'heure d'arrivée d'un véhicule entre son horaire et le temps restant")
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
                        } label: {
                        Image(systemName: "point.bottomleft.forward.to.point.topright.filled.scurvepath")
                            .font(.largeTitle)
                    }
                        .padding()
                    Text("Utilisez ce bouton pour lancer une recherche d'itinéraire avec l'arrêt correspondant")
                }
                Spacer()
                HStack {
                    Menu {
                        Menu {
                                Button(action: {
                                }) {
                                    Label("18" + " ➔ " + "Meyrin, CERN", systemImage: "circle")
                                }
                                .menuActionDismissBehavior(.disabled)
                            Button(action: {
                            }) {
                                Label("18" + " ➔ " + "Grand-Lancy, Palettes", systemImage: "circle")
                            }
                            .menuActionDismissBehavior(.disabled)
                            Button(action: {
                            }) {
                                Label("14" + " ➔ " + "Meyrin, Gravière", systemImage: "circle")
                            }
                            .menuActionDismissBehavior(.disabled)
                            Button(action: {
                            }) {
                                Label("14" + " ➔ " + "Bernex, Vailly", systemImage: "circle")
                                
                            }
                            .menuActionDismissBehavior(.disabled)
                        } label: {
                            Label("Filtrer par ligne", systemImage:  "line.3.horizontal.decrease.circle")
                        }
                        
                        Button(action: {
                        }) {
                            Label("Trier par horaire", systemImage: "list.bullet")
                        }
                        Button(action: {

                        }) {
                            Label("Trier par ligne", systemImage: "rectangle.grid.1x2.fill")
                        }
                        Button(action: {
                        }) {
                            Label("Aller ici", systemImage: "point.bottomleft.filled.forward.to.point.topright.scurvepath")
                        }
                        
                        Button(action: {
                        }) {
                            Label("Partir d'ici", systemImage: "point.bottomleft.forward.to.point.topright.filled.scurvepath")
                        }
                        Divider()
                        
                        Button(action: {
                        }) {
                            Label("Carte des quais", systemImage: "map")
                        }
                        Button(action: {
                        }) {
                            Label("Ajouter aux favoris", systemImage: "star")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle").font(.largeTitle)
                    }
                    .padding()
                    Text("Utilisez ce bouton depuis un arrêt pour accéder au menu. Vous pourrez l'ajouter aux favoris, choisir comment trier les départs, filtrer certaines lignes, afficher la cartes de ses quais ou lancer un itinéraire avec celui-ci")
                }
                Spacer()
                Button {
                    withAnimation(.easeInOut) {
                        viewingWelcome = false
                    }
                } label: {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.accent)
                        .frame(height: 50)
                        .shadow(color: Color.customShadows, radius: 3, y: 2)
                        .overlay(Text("Terminer").foregroundStyle(.white))                }
            }
        }
    }
}

struct notificationTestView: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 20)
                    .fill(.thinMaterial)
            .frame(height: 50)
                    .shadow(color: Color.customShadows, radius: 2, y: 1.5)
            .overlay(
                HStack {
                    BusLineIcon(lineName: "12", operatorName: "Transports Publics Genevois")
                    Image(systemName: "arrow.right")
                    SmallStopTitleView(stopName: "Lancy-Bachet, gare")
                    Spacer()
                            Text("12:34").frame(width: 50)
                        Image(systemName: "c.square.fill".lowercased())
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
