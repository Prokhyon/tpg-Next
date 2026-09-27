//
//  LinesView.swift
//  tpg Next
//
//  Les lignes d'un transporteur, groupées par genre, pour ouvrir la page de l'une d'elles.
//  En haut, les transporteurs choisis : on passe de l'un à l'autre d'un toucher.
//

import SwiftUI
import tpgNextFunc

struct LinesView: View {
    @Environment(\.openRoute) private var openRoute
    @AppStorage(SettingKey.lineOperators) private var storedOperators = LineOperatorChoice.defaultValue
    @AppStorage(SettingKey.selectedLineOperator) private var selectedID = LineDirectory.tpgID
    @State private var isChoosingOperators = false

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: 64), spacing: 10)]
    }

    private var chosen: [TransitOperator] { LineOperatorChoice.operators(from: storedOperators) }

    /// Retiré de la liste, le transporteur affiché laisse la place au premier.
    private var selected: TransitOperator? {
        chosen.first { $0.id == selectedID } ?? chosen.first
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                operatorBar
                if let selected {
                    let lines = LineDirectory.lines(of: [selected.id])
                    ForEach(TransitLine.Kind.allCases, id: \.self) { kind in
                        section(kind.title, lines: lines.filter { $0.kind == kind }, operator: selected)
                    }
                    .id(selected.id)
                    .transition(.opacity)
                }
                Text("Source : registre national des lignes (ATLAS).")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .animation(.snappy, value: selected?.id)
        }
        .readableScrollContent()
        .navigationTitle("Lignes")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isChoosingOperators = true
                } label: {
                    Label("Transporteurs", systemImage: "slider.horizontal.3")
                }
            }
        }
        .sheet(isPresented: $isChoosingOperators) {
            LineOperatorPicker()
        }
    }

    /// Les transporteurs choisis, puis « Ajouter » : un toucher change la liste.
    private var operatorBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(chosen) { transitOperator in
                        let isSelected = transitOperator.id == selected?.id
                        Button {
                            selectedID = transitOperator.id
                        } label: {
                            Text(verbatim: transitOperator.shortName)
                                .font(.subheadline.bold())
                                .foregroundStyle(isSelected ? Color.white : .primary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Capsule().fill(isSelected ? Color.accentColor : Color.secondary.opacity(0.15)))
                        }
                        .accessibilityLabel(Text(verbatim: transitOperator.name))
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                    }
                    Button {
                        isChoosingOperators = true
                    } label: {
                        Label("Ajouter", systemImage: "plus")
                            .font(.subheadline.bold())
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Capsule().strokeBorder(Color.secondary.opacity(0.4)))
                    }
                    .foregroundStyle(.primary)
                }
            }
            .sensoryFeedback(.selection, trigger: selectedID)
            if let selected {
                Text(verbatim: selected.name)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func section(_ title: LocalizedStringKey, lines: [TransitLine], operator transitOperator: TransitOperator) -> some View {
        if !lines.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(.title2.bold())
                LazyVGrid(columns: columns, spacing: 10) {
                    // Un numéro, un bouton : plusieurs lignes peuvent le porter (les EC des CFF, un
                    // même numéro de bus dans deux régions). On choisit alors le parcours.
                    ForEach(Self.byNumber(lines), id: \.first!.id) { sameNumber in
                        lineButton(sameNumber, operatorName: transitOperator.colorName)
                    }
                }
            }
        }
    }
}

extension LinesView {
    /// Les lignes regroupées par numéro, dans l'ordre de la liste.
    static func byNumber(_ lines: [TransitLine]) -> [[TransitLine]] {
        var groups: [[TransitLine]] = []
        var index: [String: Int] = [:]
        for line in lines {
            if let position = index[line.number] {
                groups[position].append(line)
            } else {
                index[line.number] = groups.count
                groups.append([line])
            }
        }
        return groups
    }

    @ViewBuilder
    fileprivate func lineButton(_ lines: [TransitLine], operatorName: String) -> some View {
        let label = BusLineIcon(lineName: lines[0].number, operatorName: operatorName)
            .font(.body)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(BasicCard(cornerRadius: 18))
        if lines.count == 1 {
            NavigationLink(value: AppRoute.lineInfo(lines[0])) { label }
                .foregroundStyle(.primary)
                .accessibilityLabel(Text("Ligne \(lines[0].number)"))
        } else {
            Menu {
                ForEach(lines) { line in
                    Button(line.termini.map { "\($0.from) ↔ \($0.to)" } ?? line.description) {
                        openRoute(.lineInfo(line))
                    }
                }
            } label: {
                label
            }
            .foregroundStyle(.primary)
            .accessibilityLabel(Text("Ligne \(lines[0].number), \(lines.count) parcours"))
        }
    }
}

#Preview("Lignes") {
    LinesView()
        .previewEnvironment()
}
