//
//  LineOperatorChoice.swift
//  tpg Next
//
//  Les transporteurs dont l'utilisateur veut voir les lignes : l'app sert toute la Suisse, et
//  tout le monde n'est pas à Genève.
//

import SwiftUI
import tpgNextFunc

enum LineOperatorChoice {
    /// Enregistré sous `SettingKey.lineOperators` ; les tpg tant que rien n'est choisi.
    static let defaultValue = LineDirectory.tpgID

    /// Les transporteurs choisis, dans l'ordre du choix. Jamais vide.
    static func operators(from stored: String) -> [TransitOperator] {
        let chosen = stored.split(separator: ",").compactMap { LineDirectory.operator(id: String($0)) }
        return chosen.isEmpty ? [LineDirectory.operator(id: LineDirectory.tpgID)].compactMap { $0 } : chosen
    }

    static func stored(_ operators: [TransitOperator]) -> String {
        operators.map(\.id).joined(separator: ",")
    }

    /// Les lignes de tous les transporteurs choisis (recherche).
    static func lines(from stored: String) -> [TransitLine] {
        LineDirectory.lines(of: Set(operators(from: stored).map(\.id)))
    }
}

extension TransitLine.Kind {
    var title: LocalizedStringKey {
        switch self {
        case .tram: "Tram"
        case .metro: "Métro"
        case .bus: "Bus"
        case .nightBus: "Bus de nuit"
        case .onDemand: "Bus à la demande"
        case .train: "Train"
        case .boat: "Bateau"
        case .cableway: "Funiculaires et remontées"
        }
    }
}

/// Ajouter ou retirer des transporteurs. Au moins un reste choisi.
struct LineOperatorPicker: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(SettingKey.lineOperators) private var stored = LineOperatorChoice.defaultValue
    @AppStorage(SettingKey.selectedLineOperator) private var selectedID = LineDirectory.tpgID
    @State private var query = ""

    private var chosen: [TransitOperator] { LineOperatorChoice.operators(from: stored) }

    private var matching: [TransitOperator] {
        let wanted = query.trimmingCharacters(in: .whitespaces)
        guard !wanted.isEmpty else { return LineDirectory.operators }
        return LineDirectory.operators.filter {
            $0.name.localizedStandardContains(wanted) || $0.shortName.localizedStandardContains(wanted)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    if query.isEmpty {
                        header("Mes transporteurs")
                        ForEach(chosen) { row($0) }
                    }
                    header(query.isEmpty ? "Tous les transporteurs" : "Résultats")
                    ForEach(matching) { row($0) }
                    if matching.isEmpty {
                        Text("Aucun transporteur ne correspond.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 20)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 30)
            }
            .readableScrollContent()
            .scrollDismissesKeyboard(.interactively)
            .searchable(text: $query, prompt: "Nom ou abréviation")
            .navigationTitle("Transporteurs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") { dismiss() }
                }
            }
        }
    }

    private func header(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .font(.headline)
            .padding(.leading, 8)
            .padding(.top, 14)
    }

    /// Une capsule de l'app, cerclée d'orange quand le transporteur est choisi.
    private func row(_ transitOperator: TransitOperator) -> some View {
        let isChosen = chosen.contains(transitOperator)
        // Le dernier ne se retire pas : la liste des lignes resterait vide.
        let isLocked = isChosen && chosen.count == 1
        return Button {
            withAnimation(.snappy) { toggle(transitOperator) }
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: transitOperator.name)
                        .font(.callout.weight(.semibold))
                        .lineLimit(2)
                    Text("\(transitOperator.shortName) · ^[\(LineDirectory.lineCount(of: transitOperator.id)) ligne](inflect: true)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .multilineTextAlignment(.leading)
                Spacer(minLength: 4)
                Image(systemName: isChosen ? "checkmark.circle.fill" : "plus.circle")
                    .font(.title3)
                    .foregroundStyle(isChosen ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .basicElementBackground(minHeight: 56, selected: isChosen)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 4)
        .disabled(isLocked)
        .opacity(isLocked ? 0.6 : 1)
        .accessibilityAddTraits(isChosen ? .isSelected : [])
        .accessibilityHint(isLocked ? Text("Au moins un transporteur reste choisi.") : Text(""))
    }

    private func toggle(_ transitOperator: TransitOperator) {
        var operators = chosen
        if let index = operators.firstIndex(of: transitOperator) {
            operators.remove(at: index)
        } else {
            operators.append(transitOperator)
            // Ajouté pour voir ses lignes : on les montre.
            selectedID = transitOperator.id
        }
        stored = LineOperatorChoice.stored(operators)
    }
}

#Preview("Transporteurs") {
    LineOperatorPicker()
        .previewEnvironment(navigation: false)
}
