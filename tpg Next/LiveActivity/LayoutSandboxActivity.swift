//
//  LayoutSandboxActivity.swift
//  tpg Next
//
//  Bac à sable pour essayer des mises en page d'activité en direct, à l'écart du reste de
//  l'app. Debug seulement, et absent du `WidgetBundle` : elle ne se lance jamais, elle ne sert
//  qu'aux aperçus. Compilé aussi pour le widget (exception dans le projet, comme
//  `TripLiveActivity.swift`).
//
//  Chaque zone est un emplacement coloré et nommé : on voit où le système la place et quelle
//  taille il lui donne. Les marges sont celles du système.
//

#if DEBUG
import SwiftUI
import WidgetKit
import ActivityKit

/// Les données de l'essai, sans rapport avec le trajet suivi : à remplacer à volonté.
struct SandboxActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var label: String
        var date: Date
    }

    var title: String
}

struct SandboxLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SandboxActivityAttributes.self) { context in
            // Écran verrouillé (et bannière des appareils sans Dynamic Island).
            SandboxRegion(name: "écran verrouillé", color: .blue) {
                VStack(spacing: 2) {
                    Text(verbatim: context.attributes.title)
                    Text(verbatim: context.state.label)
                    Text(context.state.date, style: .time)
                }
            }
            .frame(minHeight: 120)
        } dynamicIsland: { context in
            DynamicIsland {
                // Dépliée : à gauche et à droite de la caméra, dessous au centre, puis tout en bas.
                DynamicIslandExpandedRegion(.leading) {
                    SandboxRegion(name: "leading", color: .red, fills: false)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    SandboxRegion(name: "trailing", color: .green, fills: false)
                }
                DynamicIslandExpandedRegion(.center) {
                    SandboxRegion(name: "center", color: .yellow, fills: false)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    SandboxRegion(name: "bottom", color: .purple)
                }
            } compactLeading: {
                SandboxRegion(name: "CL", color: .red, fills: false)
            } compactTrailing: {
                SandboxRegion(name: "CT", color: .green, fills: false)
            } minimal: {
                SandboxRegion(name: "M", color: .orange, fills: false)
            }
        }
        .contentMarginsDisabled()
    }
}

/// Un emplacement : fond translucide, bord et nom de la zone, et ce qu'on y pose.
private struct SandboxRegion<Content: View>: View {
    let name: String
    let color: Color
    /// Vrai : occupe toute la place que la zone lui donne, pour en montrer le cadre. Faux pour
    /// la Dynamic Island compacte et minimale, qui s'élargiraient sinon.
    var fills = true
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 2) {
            Text(verbatim: name)
                .font(.caption2.monospaced())
            content
                .font(.caption)
        }
        .foregroundStyle(.white)
        .padding(4)
        .frame(maxWidth: fills ? .infinity : nil, maxHeight: fills ? .infinity : nil)
        .background(color.opacity(0.35))
        .border(color, width: 1)
    }
}

private extension SandboxRegion where Content == EmptyView {
    init(name: String, color: Color, fills: Bool = true) {
        self.init(name: name, color: color, fills: fills) { EmptyView() }
    }
}

// MARK: - Aperçus

private let sandboxAttributes = SandboxActivityAttributes(title: "Essai")

private extension SandboxActivityAttributes.ContentState {
    static var sample: Self { Self(label: "Exemple", date: .now) }
}

#Preview("Bac à sable : écran verrouillé", as: .content, using: sandboxAttributes) {
    SandboxLiveActivity()
} contentStates: {
    SandboxActivityAttributes.ContentState.sample
}

#Preview("Bac à sable : Dynamic Island dépliée", as: .dynamicIsland(.expanded), using: sandboxAttributes) {
    SandboxLiveActivity()
} contentStates: {
    SandboxActivityAttributes.ContentState.sample
}

#Preview("Bac à sable : Dynamic Island compacte", as: .dynamicIsland(.compact), using: sandboxAttributes) {
    SandboxLiveActivity()
} contentStates: {
    SandboxActivityAttributes.ContentState.sample
}

#Preview("Bac à sable : Dynamic Island minimale", as: .dynamicIsland(.minimal), using: sandboxAttributes) {
    SandboxLiveActivity()
} contentStates: {
    SandboxActivityAttributes.ContentState.sample
}
#endif
