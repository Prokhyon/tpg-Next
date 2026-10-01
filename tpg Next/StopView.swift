//
//  NewStopViewTest.swift
//  TPG4
//
//  Created by Loris Thomas on 28.06.2024.
//

import SwiftUI
import Combine
import tpgNextFunc

struct StopView: View {
    @Environment(\.displayTime) private var now
    @State private var stopManager = StopManager()
    @Environment(FavoritesViewModel.self) var favoritesViewModel
    @Environment(ItineraryViewModel.self) var tripViewModel
    @Environment(NavigationModel.self) var navigationModel
    @State private var lineManager = LineManager()
    @State private var stopEvents: [StopEvent] = []
    @Environment(StopStore.self) var stopStore
    @Environment(\.layout) private var layout
    /// Sur grand écran, le départ détaillé dans la moitié droite.
    @State private var selectedDeparture: StopEvent?
    /// Incrémenté quand l'utilisateur décale l'heure : relance le rafraîchissement sans revenir à l'heure d'origine.
    @State private var refreshGeneration = 0
    /// Hauteur du titre flottant : la liste commence dessous, même avec un texte agrandi.
    @State private var titleHeight: CGFloat = 0
    /// Bas du titre flottant et haut de la liste, dans le repère de la colonne : la liste
    /// commence sous le titre, quels que soient les décalages de la barre (grand écran).
    @State private var titleBottom: CGFloat = 0
    @State private var listTop: CGFloat = 0
    let stopName: String
    let stopSloid: String
    @State var previousLineRef: String?
    var previousLineName: String?
    var previousLineTime: String?
    @State private var showTime = false
    @State private var timeIntervalNotification = 0
    @State private var viewLineSorted = false //Events are grouped by line
    @State private var viewLineFiltered = false //Filter is active
    @State private var selectedNumber = 5
    @State private var timeRequest = Date() //Time sent to the api for departures
    @State private var requestNumber = 30
    @State private var selectTime = false //display time selection sheet
    /// « Maintenant » : la liste suit de nouveau l'heure actuelle, même ouverte depuis une course.
    @State private var followsNow = false
    @State private var filterLines = false //display filter sheet
    @State private var scrollID = ""
    @State private var scrollNextEvents: Bool = false
    var autoRefresh: Bool = true

    
    var groupedStopEvents: [String: [StopEvent]] {
        stopManager.stopEvents.groupedByLineAndDestination()
    }

    var filteredStopEvents: [String: [StopEvent]] {
        let byLine = selectedFilters.isEmpty ? groupedStopEvents : groupedStopEvents.filter { selectedFilters.contains($0.key) }
        guard !selectedQuays.isEmpty else { return byLine }
        return byLine
            .mapValues { $0.filter { selectedQuays.contains($0.plannedQuay) } }
            .filter { !$0.value.isEmpty }
    }
    var allFilteredStopEvents: [StopEvent] {
        filteredStopEvents.values.flatMap { $0 }.sortedByDeparture()
    }
    
    @State private var selectedFilters: Set<String> = []
    /// Quais filtrés, depuis la moitié droite sur grand écran.
    @State private var selectedQuays: Set<String> = []
        
    @AppStorage(SettingKey.groupByLineByDefault) var groupedDefault = false
    @AppStorage(SettingKey.clockTimeByDefault) var timeDefault = false
    
    @Namespace var topID
    @Namespace var bottomID

    var body: some View {
        chrome(content)
    }

    /// Depuis iOS 26, les boutons sont ceux des barres du système (`StopToolbar`, `StopBottomBar`).
    /// Avant, une capsule en haut et des boutons posés sur la liste. Le titre flottant reste.
    @ViewBuilder private func chrome(_ content: some View) -> some View {
        if #available(iOS 26, *) {
            content
                .toolbar {
                    StopToolbar(showTime: $showTime, stopName: stopName, stopSloid: stopSloid, quays: stopManager.quays)
                }
                // Le titre reste le titre flottant de la page : celui de la barre ne sert qu'au
                // bouton retour des pages ouvertes d'ici.
                .navigationTitle(stopName)
                .navigationBarTitleDisplayMode(.inline)
                // Un titre vide plutôt que `.toolbar(removing: .title)` : le décalage vers le haut
                // d'`AdaptiveSplit` (`topGapReduction`) est réglé sur cette barre. Sans titre, elle
                // compte moins haut sur iPad, et le titre flottant et la carte passaient sous les onglets.
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Text("")
                    }
                }
        } else {
            content
                .toolbar {
                    TrailingBarButtons {
                        ShowTimeButton(showTime: $showTime)

                        Button {
                            selectTime.toggle()
                        } label: {
                            Label("Selectionner l'heure", systemImage: "clock")
                                .symbolEffect(.bounce.down.byLayer, value: selectTime)
                        }

                        StopActionsMenu(stopName: stopName, stopSloid: stopSloid, quays: stopManager.quays)
                    }
                }
                .navigationTitle(stopName)
                .navigationBarTitleDisplayMode(.inline)
                // Un titre vide plutôt que `.toolbar(removing: .title)` : le décalage vers le haut
                // d'`AdaptiveSplit` (`topGapReduction`) est réglé sur cette barre. Sans titre, elle
                // compte moins haut sur iPad, et le titre flottant et la carte passaient sous les onglets.
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Text("")
                    }
                }
        }
    }

    private var content: some View {
        AdaptiveSplit(topGapReduction: 48) {
            ZStack {
                    ScrollViewReader { scroll in
                        ScrollView {
                            if !stopManager.stopError {
                                LazyVStack(spacing: 0) {
                                    
                                    if viewLineSorted {
                                        ForEach(filteredStopEvents.keys.sorted(by: lineGroupPrecedes), id: \.self) { key in
                                            SortedStopEventsView(key: key, filteredStopEvents: filteredStopEvents, groupedStopEvents: groupedStopEvents, showTime: $showTime, previousLineRef: .constant(previousLineRef), selectedJourneyRef: selectedJourneyRef, stopName: stopName, stopSloid: stopSloid,
                                                                 onSelect: layout.showsSecondaryPane ? select : nil)
                                        }
                                    } else {
                                        ForEach(allFilteredStopEvents, id: \.id) { event in
                                            departureLink(event) {
                                                StopEventView(event: event, showTime: showTime, previousLineRef: previousLineRef,
                                                              isSelected: selectedJourneyRef != nil && event.journeyRef == selectedJourneyRef)
                                                    .foregroundStyle(determineColor(for: event.estimatedTime, now: now))
                                            }
                                            .contentShape(.contextMenuPreview, Capsule())
                                            .padding(.horizontal, 15)
                                            .if(!event.cancelled && !hasPassed(event.departureDate, includingCurrentMinute: false, now: now)) { view in
                                                view.contextMenu {
                                                    NotificationContextMenu(event: event, stopID: stopSloid)
                                                }
                                            }
                                        }
                                    }
                                }
                            } else {
                                VStack {
                                    Spacer()
                                    DeparturesUnavailableText(errorMessage: stopManager.stopErrorMessage)
                                        .padding()
                                    Spacer()
                                }
                            }
                        }
                        // Sous le titre flottant ; avant iOS 26, au-dessus des boutons posés sur la liste.
                        .contentMargins(.top, max(90.0, titleBottom - listTop + 14), for: .automatic)
                        .onGeometryChange(for: CGFloat.self) { $0.frame(in: .named(Self.columnSpace)).minY + $0.safeAreaInsets.top } action: { listTop = $0 }
                        .contentMargins(.bottom, TPGSurface.isGlass ? 0 : 125, for: .automatic)
                        // Sous la barre du bas, iOS 26 assombrit le bord de la liste, sur toute la
                        // hauteur de la barre, et plus encore avec le filtre ouvert.
                        .modifier(HiddenBottomScrollEdge())
                        .readableScrollContent()
                        
                        .refreshable {
                            timeRequest = Date()
                            getStopEvents()
                        }
                        .onChange(of: allFilteredStopEvents) {
                            if !viewLineSorted {
                                scroll.scrollTo(scrollID, anchor: scrollNextEvents ? UnitPoint(x: 0, y: 0.87) : UnitPoint(x: 0, y: 0.13))
                                scrollID = ""
                            }
                        }
                    }
                VStack {
                    VStack(alignment: .center) {
                        //Stop title element
                        HStack {
                            Spacer()
                            HStack {
                                StopTitleView(stopName: stopName)
                                    .glassForegroundStyle(Color.text)
                                // La partie cachée de la capsule (hors de l'écran, ou sous la carte).
                                Rectangle()
                                    .fill(.clear)
                                    .frame(width: titleIsDetached ? 0 : 100, height: 0)
                            }
                            .padding(.horizontal)
                            .padding(.vertical, TPGSurface.isGlass ? 5 : 0)
                            .tpgSurface(interactive: true)
                            .offset(x: titleOverhang)
                            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { titleHeight = $0 }
                            .onGeometryChange(for: CGFloat.self) { $0.frame(in: .named(Self.columnSpace)).maxY } action: { titleBottom = $0 }
                        }
                        // Sur grand écran, le haut de la capsule s'aligne sur celui de la carte.
                        .padding(.top, layout.showsSecondaryPane ? PaneMetrics.topInset : 0)
                        // Détachée de la carte : aussi loin du bord que les départs.
                        .padding(.trailing, titleIsDetached ? 20 : 0)
                        Spacer()

                        // Depuis iOS 26, la barre du bas de la liste (`StopBottomBarModifier`).
                        if !TPGSurface.isGlass {
                            StopFloatingControls(isGroupedByLine: viewLineSorted,
                                                 toggleGrouping: toggleGrouping,
                                                 showsFilters: $filterLines,
                                                 isFiltered: $viewLineFiltered,
                                                 moveTime: moveTime)
                        }
                    }
                    .padding(.bottom, TPGSurface.isGlass ? 0 : 50)
                }
            }
                .coordinateSpace(.named(Self.columnSpace))
                // Depuis iOS 26, les capsules du filtre et de l'heure restent ouvertes jusqu'à un
                // toucher ailleurs (qui annule l'heure non validée).
                .overlay {
                    if TPGSurface.isGlass && (filterLines || selectTime) {
                        Color.clear
                            .contentShape(.rect)
                            .onTapGesture {
                                withAnimation(.snappy) {
                                    filterLines = false
                                    selectTime = false
                                }
                            }
                    }
                }
                .modifier(StopBottomBarModifier(isGroupedByLine: Binding(get: { viewLineSorted },
                                                                          set: { if $0 != viewLineSorted { toggleGrouping() } }),
                                                 isFiltered: viewLineFiltered, showsFilters: $filterLines,
                                                 groups: groupedStopEvents, selection: $selectedFilters,
                                                 moveTime: moveTime,
                                                 showsTime: $selectTime, time: timeRequest, isShifted: isShifted,
                                                 applyTime: applyTime, returnToNow: returnToNow))
                .onAppear {
                    viewLineSorted = groupedDefault
                }
                .periodicRefresh(id: refreshGeneration, repeats: autoRefresh) { trigger in
                    // Sans heure choisie par l'utilisateur, chaque rafraîchissement repart de
                    // maintenant : les bus déjà partis quittent la liste. Ouvert depuis une course,
                    // l'arrêt part de son heure de passage, gardée tant qu'elle est à venir.
                    if refreshGeneration == 0 {
                        let origin = followsNow ? Date() : timeRequest(for: previousLineTime)
                        timeRequest = trigger == .start ? origin : max(Date(), origin)
                    }
                    getStopEvents()
                }
        } secondary: {
            StopDetailPane(stopName: stopName, stopSloid: stopSloid, quays: stopManager.quays,
                           departures: stopManager.stopEvents, selected: selectedDeparture, showTime: showTime,
                           lineFilters: $selectedFilters, quayFilters: $selectedQuays, select: select) {
                withAnimation { selectedDeparture = nil }
            }
        }
        // Le bouton de filtre s'allume dès qu'un filtre est posé, depuis la feuille ou la moitié droite.
        .onChange(of: selectedFilters) { updateFilterState() }
        .onChange(of: selectedQuays) { updateFilterState() }
        .onChange(of: viewLineFiltered) {
            // « Supprimer les filtres » de la feuille retire aussi les quais.
            if !viewLineFiltered { selectedQuays = [] }
        }
        .onChange(of: layout.showsSecondaryPane) {
            // Sans la moitié droite, un filtre de quai ne pourrait plus être retiré.
            if !layout.showsSecondaryPane { selectedQuays = [] }
        }
        .onChange(of: stopManager.stopEvents) {
            // La sélection suit les rafraîchissements ; ouverte depuis une course, la page la présélectionne.
            if let selectedDeparture {
                self.selectedDeparture = stopManager.stopEvents.first { $0.id == selectedDeparture.id } ?? selectedDeparture
            } else if let previousLineRef, !previousLineRef.isEmpty {
                selectedDeparture = stopManager.stopEvents.first { $0.journeyRef == previousLineRef }
            }
        }
        // Depuis iOS 26, la capsule de `DepartureTimeBar` remplace la feuille.
        .sheet(isPresented: TPGSurface.isGlass ? .constant(false) : $selectTime) {
            DepartureTimeSheet(time: $timeRequest) {
                refreshGeneration += 1
                selectTime.toggle()
            }
        }
        // Depuis iOS 26, la capsule de `LineFilterBar` remplace la feuille.
        .sheet(isPresented: TPGSurface.isGlass ? .constant(false) : $filterLines) {
            LineFilterSheet(groups: groupedStopEvents, selection: $selectedFilters, isFiltered: $viewLineFiltered) {
                filterLines = false
            }
        }
    }
    
    /// De combien la capsule du titre dépasse à droite de la liste. Sur iPhone, hors de l'écran.
    /// Sur grand écran, sous la carte : assez loin pour que son bout arrondi passe derrière le
    /// coin de la carte, et que la capsule semble sortir de son bord.
    private var titleOverhang: CGFloat {
        guard layout.showsSecondaryPane else { return 50 }
        guard !titleIsDetached else { return 0 }
        return PaneMetrics.sideInset + PaneMetrics.corner + titleHeight / 2 + 6
    }

    /// Essai : sur grand écran, la capsule du titre reste entière dans la moitié gauche, séparée
    /// de la carte. `false` revient à la capsule qui sort de sous la carte.
    private static let detachesTitleOnWideScreens = true

    private var titleIsDetached: Bool {
        layout.showsSecondaryPane && Self.detachesTitleOnWideScreens
    }

    /// Le repère de la colonne de gauche : titre et liste s'y mesurent.
    private static let columnSpace = "stopColumn"

    /// Le départ détaillé à droite, sur grand écran : sa rangée prend la bordure orange. La
    /// course d'où l'on vient (`previousLineRef`) a, elle, un anneau autour de sa ligne.
    private var selectedJourneyRef: String? {
        layout.showsSecondaryPane ? selectedDeparture?.journeyRef : nil
    }

    /// La liste n'est plus à l'heure actuelle : l'horloge du bas s'allume.
    private var isShifted: Bool {
        refreshGeneration > 0 && abs(timeRequest.timeIntervalSinceNow) > 120
    }

    /// L'heure choisie dans la capsule, validée.
    private func applyTime(_ date: Date) {
        timeRequest = date
        withAnimation(.snappy) { selectTime = false }
        refreshGeneration += 1
    }

    /// « Maintenant » : la liste repart de l'heure actuelle et la suit de nouveau.
    private func returnToNow() {
        followsNow = true
        withAnimation(.snappy) { selectTime = false }
        timeRequest = Date()
        if refreshGeneration == 0 {
            getStopEvents()
        } else {
            refreshGeneration = 0
        }
    }

    private func updateFilterState() {
        viewLineFiltered = !selectedFilters.isEmpty || !selectedQuays.isEmpty
    }

    /// Retoucher le départ détaillé le désélectionne.
    private func select(_ event: StopEvent) {
        withAnimation { selectedDeparture = selectedDeparture?.id == event.id ? nil : event }
    }

    /// Sur iPhone, un départ ouvre sa course ; sur grand écran, il se détaille dans la moitié droite.
    @ViewBuilder private func departureLink<Label: View>(_ event: StopEvent, @ViewBuilder label: () -> Label) -> some View {
        if layout.showsSecondaryPane {
            Button(action: { select(event) }, label: label)
        } else {
            NavigationLink(value: AppRoute.line(event: event, currentStop: ShortStop(name: stopName, sloid: sloidHarmonizer(code: stopSloid))), label: label)
        }
    }

    private func toggleGrouping() {
        withAnimation(TPGSurface.isGlass ? nil : .default) {
            viewLineSorted.toggle()
        }
        requestNumber = max(viewLineSorted ? groupedStopEvents.keys.count * 5 : 30, 30)
    }
    
    private func getStopEvents() {
        stopManager.selectStop(stopName: stopName, stopSloid: stopSloid, stopEventNumber: requestNumber, timeRequest: timeRequest) {
                    stopEvents = self.stopManager.stopEvents
        }
    }
    private func adjustTime(byAdding minutes: Int) {
        if let newTimeRequest = Calendar.current.date(byAdding: .minute, value: minutes, to: timeRequest) {
            timeRequest = newTimeRequest
        } else {
            Log.ui.error("Décalage de l'heure impossible")
        }
    }
    func timeRequest(for time: String?) -> Date {
        // Une heure absente ou illisible (ouverture depuis le widget, par exemple)
        // veut simplement dire « les départs à partir de maintenant ».
        guard let time, let date = stringToDate(with: time) else { return Date() }
        return date
    }
    private func estimatedTypicalTimeInterval(from events: [StopEvent]) -> Int { //calcul d'interval pour décalement d'heure
        let dates = events.compactMap(\.departureDate).sorted()

        guard dates.count > 2 else {
            return 10 // Valeur par défaut minimale
        }

        // Prendre le 80e percentile (ou autre)
        let index = Int(Double(dates.count - 1) * 0.8)
        let typicalEnd = dates[index]
        let start = dates.first!

        let timeInterval = typicalEnd.timeIntervalSince(start) / 60.0
        return max(5, Int(timeInterval)) // minimum 5 minutes
    }
    
    private func moveTime(previous: Bool) { //Move departures time earlier or later (with top and bottom buttons)
        let interval = estimatedTypicalTimeInterval(from: stopEvents)
        adjustTime(byAdding: previous ? -interval : interval)
        scrollNextEvents = !previous
        // Liste vide (arrêt sans départ, erreur) : on décale l'heure sans cible de défilement.
        scrollID = (previous ? allFilteredStopEvents.first?.id : allFilteredStopEvents.last?.id) ?? ""
        // Recharge à la nouvelle heure et repousse le prochain rafraîchissement de 30 s.
        refreshGeneration += 1
    }
}

#Preview("Arrêt") {
    StopView(stopName: PreviewData.rive.name, stopSloid: PreviewData.rive.sloid, autoRefresh: false)
        .previewEnvironment()
}

#Preview("Arrêt — iPad", traits: .iPadLandscape) {
    StopView(stopName: PreviewData.rive.name, stopSloid: PreviewData.rive.sloid, autoRefresh: false)
        .previewEnvironment()
}

#Preview("Arrêt — iPad portrait", traits: .iPadPortrait) {
    StopView(stopName: PreviewData.rive.name, stopSloid: PreviewData.rive.sloid, autoRefresh: false)
        .previewEnvironment()
}

#Preview("Arrêt — ouvert depuis une course") {
    // Course mise en avant et liste qui part de son heure de passage.
    LiveDeparturePreview { departures in
        StopView(stopName: PreviewData.rive.name, stopSloid: PreviewData.rive.sloid,
                 previousLineRef: departures.event.journeyRef,
                 previousLineName: departures.event.lineName,
                 previousLineTime: departures.event.timetabledTime,
                 autoRefresh: false)
    }
    .previewEnvironment()
}

/// La barre du bas de la liste, depuis iOS 26 (`StopBottomBar`) ; avant, les boutons flottants
/// sont posés sur la liste par `StopView` lui-même.
private struct StopBottomBarModifier: ViewModifier {
    @Binding var isGroupedByLine: Bool
    let isFiltered: Bool
    @Binding var showsFilters: Bool
    let groups: [String: [StopEvent]]
    @Binding var selection: Set<String>
    let moveTime: (_ earlier: Bool) -> Void
    @Binding var showsTime: Bool
    let time: Date
    let isShifted: Bool
    let applyTime: (Date) -> Void
    let returnToNow: () -> Void

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.safeAreaBar(edge: .bottom) {
                // Un seul conteneur pour tout le verre de la barre : la capsule du filtre y apparaît
                // et disparaît par la transition du verre, sans passer par un rendu sombre.
                GlassEffectContainer(spacing: 8) {
                    VStack(alignment: .leading, spacing: 8) {
                        if showsFilters {
                            LineFilterBar(groups: groups, selection: $selection) {
                                withAnimation(.snappy) { showsFilters = false }
                            }
                            .padding(.horizontal)
                        }
                        if showsTime {
                            DepartureTimeBar(time: time, apply: applyTime, returnToNow: returnToNow)
                                .padding(.horizontal)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                        // Un seul des deux ouvert à la fois.
                        StopBottomBar(isGroupedByLine: $isGroupedByLine, isFiltered: isFiltered,
                                      isFilterOpen: showsFilters,
                                      showFilters: {
                                          withAnimation(.snappy) {
                                              showsTime = false
                                              showsFilters.toggle()
                                          }
                                      },
                                      moveTime: moveTime,
                                      isShifted: isShifted, isTimeOpen: showsTime,
                                      chooseTime: {
                                          withAnimation(.snappy) {
                                              showsFilters = false
                                              showsTime.toggle()
                                          }
                                      })
                    }
                }
            }
        } else {
            content
        }
    }
}

/// Sans l'effet de bord de défilement d'iOS 26 en bas de la liste : les boutons flottent sur les
/// départs, comme avant.
private struct HiddenBottomScrollEdge: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.scrollEdgeEffectHidden(true, for: .bottom)
        } else {
            content
        }
    }
}

// MARK: - Aperçus de la barre du bas (iOS 26)

#Preview("Barre du bas") {
    if #available(iOS 26, *) {
        StopBottomBarPreview()
            .previewEnvironment()
    }
}

#Preview("Barre du bas — filtre ouvert") {
    if #available(iOS 26, *) {
        StopBottomBarPreview(panel: .filter, selection: [PreviewData.departures[0].lineName + ";" + PreviewData.departures[0].destination])
            .previewEnvironment()
    }
}

#Preview("Barre du bas — choix de l'heure") {
    if #available(iOS 26, *) {
        StopBottomBarPreview(panel: .time)
            .previewEnvironment()
    }
}

#Preview("Barre du bas — heure décalée, filtre posé") {
    if #available(iOS 26, *) {
        StopBottomBarPreview(selection: [PreviewData.departures[0].lineName + ";" + PreviewData.departures[0].destination],
                             isShifted: true)
            .previewEnvironment()
    }
}

/// La barre du bas de l'arrêt sur des départs figés (`PreviewData`), sans API : tri, filtre,
/// heure et flèches se touchent comme dans l'app ; la liste suit le tri et le filtre.
@available(iOS 26, *)
private struct StopBottomBarPreview: View {
    enum Panel { case none, filter, time }

    @State private var isGroupedByLine = false
    @State private var showsFilters: Bool
    @State private var showsTime: Bool
    @State private var selection: Set<String>
    @State private var time = Date()
    @State private var isShifted: Bool
    @State private var shift = 0

    init(panel: Panel = .none, selection: Set<String> = [], isShifted: Bool = false) {
        _showsFilters = State(initialValue: panel == .filter)
        _showsTime = State(initialValue: panel == .time)
        _selection = State(initialValue: selection)
        _isShifted = State(initialValue: isShifted)
    }

    private var groups: [String: [StopEvent]] { PreviewData.departures.groupedByLineAndDestination() }

    private var departures: [StopEvent] {
        selection.isEmpty ? PreviewData.departures
            : PreviewData.departures.filter { selection.contains($0.lineName + ";" + $0.destination) }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                Text(verbatim: "Décalage : \(shift) · \(time.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if isGroupedByLine {
                    let filtered = groups.filter { selection.isEmpty || selection.contains($0.key) }
                    ForEach(filtered.keys.sorted(by: lineGroupPrecedes), id: \.self) { key in
                        SortedStopEventsView(key: key, filteredStopEvents: filtered, groupedStopEvents: groups,
                                             showTime: .constant(false), previousLineRef: .constant(nil),
                                             stopName: PreviewData.rive.name, stopSloid: PreviewData.rive.sloid)
                    }
                } else {
                    ForEach(departures, id: \.id) { event in
                        StopEventView(event: event, showTime: false, previousLineRef: nil)
                            .padding(.horizontal, 15)
                    }
                }
            }
        }
        .modifier(HiddenBottomScrollEdge())
        .overlay {
            if showsFilters || showsTime {
                Color.clear
                    .contentShape(.rect)
                    .onTapGesture {
                        withAnimation(.snappy) {
                            showsFilters = false
                            showsTime = false
                        }
                    }
            }
        }
        .modifier(StopBottomBarModifier(isGroupedByLine: $isGroupedByLine,
                                        isFiltered: !selection.isEmpty, showsFilters: $showsFilters,
                                        groups: groups, selection: $selection,
                                        moveTime: { earlier in shift += earlier ? -1 : 1 },
                                        showsTime: $showsTime, time: time, isShifted: isShifted,
                                        applyTime: { date in
                                            time = date
                                            isShifted = abs(date.timeIntervalSinceNow) > 120
                                            withAnimation(.snappy) { showsTime = false }
                                        },
                                        returnToNow: {
                                            time = Date()
                                            isShifted = false
                                            withAnimation(.snappy) { showsTime = false }
                                        }))
        .navigationTitle(PreviewData.rive.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
