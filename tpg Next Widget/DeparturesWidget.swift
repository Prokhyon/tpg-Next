//
//  DeparturesWidget.swift
//  tpg Next Widget
//
//  Created by Loris Thomas on 26.08.2026.
//

import WidgetKit
import SwiftUI

struct DeparturesWidget: Widget {
    let kind = "tpgNextDepartures"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: SelectStopIntent.self, provider: DeparturesProvider()) { entry in
            DeparturesWidgetView(entry: entry)
        }
        .configurationDisplayName("Prochains départs")
        .description("Les prochains départs d'un arrêt, ou de l'arrêt le plus proche de vous.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        // Rend la main sur les marges : voir `contentInsets` dans DeparturesWidgetView.
        .contentMarginsDisabled()
    }
}

@main
struct tpgNextWidgetBundle: WidgetBundle {
    var body: some Widget {
        DeparturesWidget()
    }
}
