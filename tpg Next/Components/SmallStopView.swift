//
//  SmallStopView.swift
//  tpg Next
//
//  Carte compacte d'un arrêt et de ses prochains départs (accueil, carte).
//

import SwiftUI
import tpgNextFunc

struct SmallStopView: View {
    @Environment(ItineraryViewModel.self) var tripViewModel
    @Environment(NavigationModel.self) var navigationModel
    @State var stopManager = StopManager()
    @State private var lineManager = LineManager()
    @State private var isShowingPopover = false
    
    var stop: Stop
    var quay = ""
    var isQuay: Bool = false
    /// Le style de l'accueil (carte opaque) plutôt que celui de la carte des arrêts (verre, dont
    /// l'ombre déborde). Décide aussi du bouton d'itinéraire, sauf `tripMenu`.
    var isHome: Bool = false
    /// Le bouton d'itinéraire ouvre le menu (partir d'ici, y aller…) plutôt que de lancer un
    /// itinéraire depuis l'arrêt. Par défaut : hors de l'accueil.
    var tripMenu: Bool? = nil
    var stopEventNumber: Int = 3
    /// Départs affichés, parmi ceux demandés.
    var departureCount: Int = 3
    //    var autoRefresh = true
    var testing: Bool = false
    /// Replié : le nom et le bouton d'itinéraire seulement. Les départs restent chargés, pour
    /// s'afficher aussitôt dépliés.
    var isExpanded: Bool = true
    /// Toucher le nom d'un arrêt replié le déplie (au lieu d'ouvrir sa page).
    var onExpand: (() -> Void)? = nil
    @Namespace private var namespace
    
    
    var body: some View {
        
        //main view
        VStack {
            if #available(iOS 26, *), !isHome {
                GlassEffectContainer() {
                    VStack {
                        HeaderView()
                        // Replié, le verre des départs se fond dans celui du titre (même conteneur).
                        if isExpanded {
                            DeparturesList()
                                .padding(.horizontal, 10)
                                .padding(.vertical, 15)
                                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 40))
                                .glassEffectID("departures", in: namespace)
                                .transition(Self.foldIntoTitle)
                        }
                    }
                }
            } else {
                VStack {
                    HeaderView()
                    if isExpanded {
                        Group {
                            if !testing {
                                DeparturesList()
                            } else {
                                DeparturesTestList()
                            }
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 5)
                        .background {
                            BasicCard(cornerRadius: 35)
                        }
                        .transition(Self.foldIntoTitle)
                    }
                }
                .padding(.horizontal)
                
                //                VStack {
                //                     HeaderView()
                //                        .padding(.horizontal)
                //                     DeparturesList()
                //                 }
                //                    .padding(.vertical, 15)
                //                    .background {
                //                        RoundedRectangle(cornerRadius: 35)
                //                            .foregroundStyle(.thinMaterial)
                //                            .shadow(color: Color.customShadows, radius: 2, y: 1.5)
                //                    }
            }
        }
        .periodicRefresh(id: stop, repeats: !testing) { _ in
            refreshDepartures()
        }
    }
    
    /// Les départs se replient dans le titre, et en sortent au dépliage : ils rétrécissent vers
    /// le nom de l'arrêt, en haut à gauche, en s'effaçant.
    private static let foldIntoTitle: AnyTransition = .scale(scale: 0.1, anchor: UnitPoint(x: 0.2, y: 0))
        .combined(with: .opacity)

    private func HeaderView() -> some View {
        HStack {
            if #available(iOS 26, *), !isHome {
                HStack {
                    if isQuay {
                        Text("Quai \(quay)").font(.title3).bold()
                    } else {
                        StopTitleView()
                    }
                }
                .frame(height: 45)
                .padding(.horizontal)
                .padding(.vertical, 10)
                .padding(.trailing, 50)
                .glassEffect(.regular.interactive())
                .glassEffectID("title", in: namespace)
                .foregroundStyle(.primary)
                Spacer()
                TripButton()
                    .frame(width: 45, height: 45)
                    .padding(10)
                    .foregroundStyle(.primary)
                    .glassEffect(.regular.interactive())
                    .glassEffectID("trip", in: namespace)
            } else {
                HStack {
                    if isQuay {
                        Text("Quai \(quay)").font(.title3).bold()
                    } else {
                        StopTitleView()
                    }
                }
                .frame(height: 45)
                .padding(.horizontal)
                .padding(.vertical, 5)
                .padding(.trailing, 40)
                .foregroundStyle(.primary)
                .background {
                    BasicElement()
                }
                Spacer()
                TripButton()
                    .frame(width: 45, height: 45)
                    .padding(5)
                    .foregroundStyle(.primary)
                    .background {
                        BasicElement()
                    }
            }
        }
    }
    
    @ViewBuilder private func StopTitleView() -> some View {
        if !isExpanded, let onExpand {
            Button(action: onExpand) {
                StopTitleLabel()
            }
            .accessibilityHint("Affiche les prochains départs")
        } else {
            NavigationLink(value: AppRoute.stop(stop)) {
                StopTitleLabel()
            }
        }
    }

    private func StopTitleLabel() -> some View {
        HStack {
            //                StopIcon(color: .color1)
            StopNameView(stop.name, style: .card, transportType: stop.meansOfTransport)
            if splitString(stop.name, separator: ",").1.isEmpty {
                Spacer() // Un nom sur une ligne occupe toute la largeur de la carte.
            }
        }
    }
    
    private func TripButton() -> some View {
        HStack {
            let menu = Group {
                TripActionsMenu(stop: stop)
            }
            if !(tripMenu ?? !isHome) {
                Button(action: {
                    tripViewModel.outerTrip(tab: navigationModel, isDeparture: true, stop: stop, isQuickTrip: false)
                }) {
                    Image(systemName: "point.bottomleft.forward.to.point.topright.filled.scurvepath")
                        .font(.title2)
                }
                .buttonStyle(.borderless)
            } else {
                Menu {
                    menu
                } label: {
                    Image(systemName: "point.bottomleft.forward.to.point.topright.scurvepath")
                        .font(.title2)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.primary)
            }
        }
    }
    
    private func DeparturesList() -> some View {
        VStack(spacing: 0) {
            if !stopManager.stopEvents.isEmpty {
                ForEach((isQuay ? filteredEvents : stopManager.stopEvents).sortedByDeparture().prefix(departureCount), id: \.id) { event in
                    NavigationLink(value: AppRoute.line(event: event, currentStop: ShortStop(name: stop.name, sloid: sloidHarmonizer(code: stop.sloid)))) {
                        StopEventView(event: event, showTime: false, mapVersion: !isHome)
                    }
                    .contentShape(.contextMenuPreview, Capsule())
                    .foregroundStyle(.primary)
                    .if(!event.cancelled) { view in
                        view.contextMenu {
                            NotificationContextMenu(event: event, stopID: stop.sloid)
                        }
                    }
                }
            } else if stopManager.stopError {
                HStack {
                    Spacer()
                    DeparturesUnavailableText(errorMessage: stopManager.stopErrorMessage)
                    Spacer()
                }
            } else {
                HStack {
                    Spacer()
                    Text("Recherche des départs...")
                    Spacer()
                }
            }
        }
        // La hauteur de trois départs, pour des pages égales ; au-delà, la hauteur naturelle.
        .if(departureCount <= 3) { $0.heightGrowingWithText(170) }
    }
    
    private func DeparturesTestList() -> some View {
        VStack(spacing: 0) {
            StopEventView(event: StopEvent(stopPointName: "1", stopId: "1", plannedQuay: "k", timetabledTime: "2025/09/24T17:48:00Z", estimatedTime: "", lineName: "25", origin: "1", destination: "Thônex, Vallard", transportType: "", operatorName: "Transports Publics Genevois", journeyRef: "1", operatingDayRef: ""), showTime: false, mapVersion: !isHome)
            StopEventView(event: StopEvent(stopPointName: "", stopId: "2", plannedQuay: "b", timetabledTime: "2025/09/24T17:49:00Z", estimatedTime: "", lineName: "12", origin: "", destination: "Thônex, Moillesulaz", transportType: "", operatorName: "Transports Publics Genevois", journeyRef: "1", operatingDayRef: ""), showTime: false, mapVersion: !isHome)
            StopEventView(event: StopEvent(stopPointName: "", stopId: "3", plannedQuay: "c", timetabledTime: "2025/09/24T17:50:00Z", estimatedTime: "", lineName: "17", origin: "", destination: "Lancy-Bachet, gare", transportType: "", operatorName: "Transports Publics Genevois", journeyRef: "1", operatingDayRef: ""), showTime: false, mapVersion: !isHome)
        }
        .heightGrowingWithText(170)
    }
    
    private func refreshDepartures() {
        guard !testing else { return }
        stopManager.selectStop(stopName: stop.name, stopSloid: stop.sloid, stopEventNumber: stopEventNumber, timeRequest: Date())
    }
    private var filteredEvents: [StopEvent] {
        stopManager.stopEvents.filter { $0.plannedQuay == quay }
       }
}

#Preview("Carte d'arrêt — accueil") {
    SmallStopView(stop: PreviewData.rive, isHome: true)
        .previewEnvironment()
}

#Preview("Carte d'arrêt — sur la carte") {
    // Version de la carte (onglet Carte) : verre sur iOS 26.
    VStack {
        Spacer()
        SmallStopView(stop: PreviewData.cornavin)
    }
    .background { Image("tpgMap").resizable().scaledToFill().ignoresSafeArea() }
    .previewEnvironment(background: false)
}

#Preview("Carte d'arrêt — un quai") {
    SmallStopView(stop: PreviewData.rive, quay: "B", isQuay: true, isHome: true, stopEventNumber: 10)
        .previewEnvironment()
}

#Preview("Carte d'arrêt — hors ligne") {
    SmallStopView(stop: PreviewData.rive, isHome: true, testing: true)
        .previewEnvironment()
}
