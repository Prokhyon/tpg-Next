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
                // Comme les lignes de la capsule du filtre des départs : une pastille teintée.
                .background(
                    Capsule()
                        .fill(isOn ? Color.accentColor.opacity(0.35) : Color.primary.opacity(0.04))
                )
        }
        .foregroundStyle(.primary)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

#Preview("Filtre par ligne", traits: .sizeThatFitsLayout) {
    @Previewable @State var selection: Set<String> = ["12"]
    let lines = Dictionary(grouping: PreviewData.departures, by: \.lineName).keys
        .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        .map { LineFilterChips.Line(name: $0, operatorName: "Transports Publics Genevois") }
    VStack(alignment: .leading) {
        LineFilterChips(lines: lines, selection: $selection)
        Text(verbatim: selection.isEmpty ? "Toutes les lignes" : selection.sorted().joined(separator: ", "))
            .font(.caption)
    }
    .padding()
}
