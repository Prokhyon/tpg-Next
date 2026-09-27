//
//  LineInfoView.swift
//  tpg Next
//
//  Une ligne du réseau, sans course choisie : ses terminus, les prochains départs dans chaque
//  sens (qui ouvrent la course et tous ses arrêts), et son parcours.
//

import SwiftUI
import tpgNextFunc

struct LineInfoView: View {
    @Environment(StopStore.self) private var stopStore
    @Environment(\.displayTime) private var now
    let line: TransitLine

    /// Les prochains départs de chaque terminus, par sloid.
    @State private var departures: [String: [StopEvent]] = [:]
    @State private var isLoading = true

    /// Les exploitants de `LineColors` sont désignés par leur nom.
    private var operatorName: String { line.operatorColorName }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                if line.isOnDemand {
                    Text(line.description)
                        .foregroundStyle(.secondary)
                } else {
                    departuresSection
                    routeSection
                }
            }
            .padding()
        }
        .readableScrollContent()
        .navigationTitle(Text("Ligne \(line.number)"))
        .navigationBarTitleDisplayMode(.inline)
        .task(id: stopStore.isLoaded) { await loadDepartures() }
    }

    private var header: some View {
        HStack(spacing: 14) {
            BusLineIcon(lineName: line.number, operatorName: operatorName)
                .font(.title.bold())
            VStack(alignment: .leading, spacing: 2) {
                Group {
                    if let transitOperator = line.transitOperator {
                        Text("\(Text(line.kind.title)) · \(transitOperator.shortName)")
                    } else {
                        Text(line.kind.title)
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                if let termini = line.termini {
                    Text(verbatim: "\(termini.from) ↔ \(termini.to)")
                        .font(.headline)
                }
            }
        }
    }

    // MARK: Départs

    /// Les terminus trouvés dans la base des arrêts.
    private var terminusStops: [Stop] {
        guard let termini = line.termini else { return [] }
        return [termini.from, termini.to].compactMap { stopStore.stop(named: $0) }
    }

    @ViewBuilder private var departuresSection: some View {
        let stops = terminusStops
        if !stops.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Prochains départs")
                    .font(.title2.bold())
                ForEach(stops) { stop in
                    terminusCard(stop)
                }
            }
        }
    }

    private func terminusCard(_ stop: Stop) -> some View {
        let events = departures[stop.sloid] ?? []
        return VStack(alignment: .leading, spacing: 8) {
            Text("Depuis \(stop.name)")
                .font(.headline)
            if events.isEmpty {
                Text(isLoading ? "Chargement…" as LocalizedStringKey : "Aucun départ dans l'heure.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            ForEach(events) { event in
                NavigationLink(value: AppRoute.line(event: event, currentStop: ShortStop(name: stop.name, sloid: sloidHarmonizer(code: stop.sloid)))) {
                    HStack {
                        DepartureTimeView(departureDisplay(for: event, showTime: false, at: now),
                                          transportType: event.transportType, iconWidth: 40)
                            .frame(width: 60, alignment: .leading)
                        Text(verbatim: "→ \(event.destination)")
                            .lineLimit(1)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.footnote.bold())
                            .foregroundStyle(.tertiary)
                    }
                    .contentShape(Rectangle())
                }
                .foregroundStyle(.primary)
            }
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BasicCard(cornerRadius: 25))
    }

    /// Les prochains départs de la ligne à chaque terminus. Un arrêt très desservi mêle
    /// beaucoup de lignes : on en demande assez pour trouver les siens.
    private func loadDepartures() async {
        guard stopStore.isLoaded else { return }
        isLoading = true
        await withTaskGroup(of: (String, [StopEvent]).self) { group in
            for stop in terminusStops {
                group.addTask {
                    let events = (try? await fetchStopEvents(stopName: stop.name, stopSloid: stop.sloid, count: 40).events) ?? []
                    let sameNumber = events.filter { $0.lineName == line.number }
                    // Un même numéro peut appartenir à plusieurs transporteurs (le 1 d'une ville et
                    // le S1) : ceux de la ligne d'abord, s'ils sont reconnus.
                    let sameOperator = sameNumber.filter { $0.operatorName == operatorName }
                    return (stop.sloid, Array((sameOperator.isEmpty ? sameNumber : sameOperator).prefix(3)))
                }
            }
            for await (sloid, events) in group {
                departures[sloid] = events
            }
        }
        isLoading = false
    }

    // MARK: Parcours

    private var routeSection: some View {
        let color = LineColors.lineColor(for: line.number, operatorName: operatorName)
        let stops = line.mainStops
        return VStack(alignment: .leading, spacing: 0) {
            Text("Parcours")
                .font(.title2.bold())
                .padding(.bottom, 10)
            ForEach(Array(stops.enumerated()), id: \.offset) { index, name in
                HStack(spacing: 14) {
                    ZStack {
                        Rectangle()
                            .fill(color)
                            .frame(width: 6)
                            .padding(.top, index == 0 ? 22 : 0)
                            .padding(.bottom, index == stops.count - 1 ? 22 : 0)
                        StopIcon(color: color, size: 16)
                    }
                    .frame(width: 20)
                    routeStop(name)
                    Spacer()
                }
                .frame(minHeight: 44)
            }
            Text("Arrêts principaux. Touchez un départ pour voir tous les arrêts de la course.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.top, 8)
        }
    }

    /// Un arrêt trouvé dans la base ouvre ses départs ; sinon, son nom seul.
    @ViewBuilder
    private func routeStop(_ name: String) -> some View {
        if let stop = stopStore.stop(named: name) {
            NavigationLink(value: AppRoute.stop(stop)) {
                StopNameView(stop.name, style: .row)
            }
            .foregroundStyle(.primary)
        } else {
            Text(name)
                .font(.headline)
        }
    }
}

#Preview("Ligne 12 (API)") {
    LineInfoView(line: LineDirectory.lines(of: [LineDirectory.tpgID]).first { $0.number == "12" }
                 ?? TransitLine(slnid: "", number: "12", category: "T",
                                description: "Lancy-Bachet gare - Carouge GE Rondeau - Genève-Eaux-Vives gare - Thônex Moillesulaz",
                                operator: LineDirectory.tpgID))
        .previewEnvironment()
}
