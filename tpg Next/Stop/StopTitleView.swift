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
