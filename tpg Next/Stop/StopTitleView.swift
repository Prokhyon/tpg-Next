//
//  StopTitleView.swift
//  tpg Next
//
//  Titre flottant d'une page arrêt.
//

import SwiftUI
import tpgNextFunc

struct StopTitleView : View {
    var stopName: String

    var body: some View {
        StopNameView(stopName, style: .title)
            .frame(height: 70)
            .padding(.horizontal, 25)
    }
}

#Preview("Titre d'arrêt", traits: .sizeThatFitsLayout) {
    VStack(alignment: .leading) {
        StopTitleView(stopName: "Genève, Rive")
        StopTitleView(stopName: "Genève, gare Cornavin")
        StopTitleView(stopName: "Chancy, Douane")
        StopTitleView(stopName: "Genève-Aéroport")
        StopTitleView(stopName: "Plan-les-Ouates, ZIPLO-Pré-Fleuri Nord")
    }
}
