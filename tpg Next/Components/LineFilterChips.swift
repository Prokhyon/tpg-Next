//
//  LineFilterChips.swift
//  tpg Next
//
//  Rangée de lignes à toucher pour filtrer des départs. Aucune ligne choisie : tout s'affiche.
//

import SwiftUI
import tpgNextFunc

struct LineFilterChips: View {
    struct Line: Hashable {
        let name: String
        let operatorName: String
    }

    let lines: [Line]
    /// Noms des lignes gardées ; vide = toutes.
    @Binding var selection: Set<String>

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(isOn: selection.isEmpty, accessibilityLabel: "Toutes les lignes") {
                    selection = []
                } label: {
                    Text("Toutes").font(.subheadline.bold())
                }
                ForEach(lines, id: \.self) { line in
                    chip(isOn: selection.contains(line.name), accessibilityLabel: "Ligne \(line.name)") {
                        if selection.contains(line.name) {
                            selection.remove(line.name)
                        } else {
                            selection.insert(line.name)
                        }
                    } label: {
                        BusLineIcon(lineName: line.name, operatorName: line.operatorName)
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func chip<Label: View>(isOn: Bool, accessibilityLabel: LocalizedStringKey, action: @escaping () -> Void,
                                   @ViewBuilder label: () -> Label) -> some View {
        Button {
            withAnimation { action() }
        } label: {
            label()
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(isOn ? Color.accent.opacity(0.15) : Color.primary.opacity(0.04))
                        .strokeBorder(isOn ? Color.accent : .clear, lineWidth: 1.5)
                )
        }
        .foregroundStyle(.primary)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}
