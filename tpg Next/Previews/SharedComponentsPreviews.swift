//
//  SharedComponentsPreviews.swift
//  tpg Next
//
//  Aperçus des vues de tpgNextFunc (icônes de ligne, quais, heures, noms d'arrêts), partagées
//  par l'app, la montre et le widget. Rangés ici : le framework n'a pas de données d'exemple.
//

import SwiftUI
import tpgNextFunc

#Preview("Icônes de ligne", traits: .sizeThatFitsLayout) {
    let tpg = "Transports Publics Genevois"
    let lines = ["1", "2", "3", "5", "6", "7", "8", "9", "10", "11", "12", "14", "15", "17", "18",
                 "19", "21", "22", "23", "25", "28", "29", "33", "34", "35", "A", "E", "G", "NA", "NE"]
    VStack(alignment: .leading, spacing: 12) {
        LazyVGrid(columns: Array(repeating: GridItem(.fixed(40)), count: 6)) {
            ForEach(lines, id: \.self) { BusLineIcon(lineName: $0, operatorName: tpg) }
        }
        HStack {
            BusLineIcon(lineName: "L1", operatorName: "SBB")
            BusLineIcon(lineName: "IR90", operatorName: "SBB")
            BusLineIcon(lineName: "M4", operatorName: "Mouettes Genevoises Navigation")
            BusLineIcon(lineName: "271", operatorName: "TPN")
            BusLineIcon(lineName: "X", operatorName: "Exploitant inconnu")
        }
        HStack {
            BusLineIcon(lineName: "12", operatorName: tpg, width: 50, height: 35)
            BusLineIcon(lineName: "12", operatorName: tpg, width: 25, height: 18)
        }
    }
    .padding()
}

#Preview("Quais", traits: .sizeThatFitsLayout) {
    HStack {
        ForEach(["A", "B", "K", "12", "3a", ""], id: \.self) { QuayIcon(quay: $0) }
        QuayIcon(quay: "", dimsUnknown: true)
    }
    .padding()
}

#Preview("Heures de départ", traits: .sizeThatFitsLayout) {
    let cases: [(String, DepartureDisplay)] = [
        ("À l'arrêt", .atStop),
        ("Moins d'une minute", .lessThanAMinute(delayed: false)),
        ("Moins d'une minute, retard", .lessThanAMinute(delayed: true)),
        ("Minutes", .minutes(6, delayed: false)),
        ("Minutes, retard", .minutes(12, delayed: true)),
        ("Heure", .clock("14:05", delayed: false)),
        ("Heure, retard", .clock("14:08", delayed: true)),
        ("Heure et retard séparés", .plannedWithDelay(planned: "14:05", delay: "+3'")),
        ("Supprimé", .cancelled),
        ("Illisible", .unknown),
    ]
    Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 10) {
        ForEach(cases, id: \.0) { name, display in
            GridRow {
                Text(verbatim: name).font(.caption)
                DepartureTimeView(display, transportType: "Tram", iconWidth: 10)
                DepartureTimeView(display, transportType: "Bus", layout: .inline(spacing: 2), iconWidth: 15)
                DepartureTimeView(display, transportType: "Bus", showsIcon: false)
            }
        }
    }
    .padding()
}

#Preview("Noms d'arrêts", traits: .sizeThatFitsLayout) {
    let styles: [(String, StopNameView.Style)] = [
        ("title", .title), ("header", .header), ("card", .card), ("row", .row), ("compact", .compact), ("widget", .widget),
    ]
    VStack(alignment: .leading, spacing: 14) {
        ForEach(styles, id: \.0) { name, style in
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: name).font(.caption).foregroundStyle(.secondary)
                StopNameView("Genève, Place des Eaux-Vives", style: style)
                StopNameView("Genève-Aéroport", style: style, transportType: "TRAIN")
                StopNameView("Plan-les-Ouates, ZIPLO-Pré-Fleuri Nord", style: style)
            }
        }
    }
    .frame(width: 320)
    .padding()
}
