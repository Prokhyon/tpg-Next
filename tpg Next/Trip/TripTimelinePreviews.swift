//
//  TripTimelinePreviews.swift
//  tpg Next
//
//  Les aperçus de la frise, à part : `TripTimeline.swift` est aussi compilé pour le widget,
//  qui n'a pas `PreviewData`.
//

import SwiftUI
import tpgNextFunc

#Preview("Frise des itinéraires") {
    @Previewable @State var width = 340.0
    VStack(spacing: 18) {
        ForEach(PreviewData.trips) { trip in
            TripTimeline(event: trip)
                .frame(width: width)
        }
        Slider(value: $width, in: 120...600) {
            Text(verbatim: "Largeur")
        }
        Text(verbatim: "Largeur : \(Int(width)) pt")
            .font(.caption)
    }
    .padding()
    .previewEnvironment(navigation: false)
}

#Preview("Frise — texte très grand") {
    VStack(spacing: 18) {
        ForEach(PreviewData.trips) { trip in
            TripTimeline(event: trip)
        }
    }
    .padding()
    .dynamicTypeSize(.accessibility3)
    .previewEnvironment(navigation: false)
}

#Preview("Frise — sans défilement (widget)") {
    VStack(alignment: .leading, spacing: 18) {
        ForEach(PreviewData.trips) { trip in
            TripTimeline(event: trip)
                .frame(width: 130)
        }
    }
    .padding()
    .environment(\.tripTimelineScrolls, false)
    .previewEnvironment(navigation: false)
}
