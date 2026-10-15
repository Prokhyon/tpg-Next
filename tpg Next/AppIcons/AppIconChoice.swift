//
//  AppIconChoice.swift
//  tpg Next
//

import SwiftUI
import tpgNextFunc

/// Les icônes proposées dans les réglages, chacune avec sa couleur d'accent.
///
/// La valeur brute est enregistrée (`SettingKey.appIcon`) : ne pas la changer. Chaque icône
/// autre que la classique est un fichier `AppIcon-<valeur>.icon`, déclaré dans le réglage
/// « Alternate App Icon Sets » de la cible ; son aperçu (`Icon<valeur>`) et sa couleur
/// (`Accent<valeur>`) sont dans `AppIconPreviews.xcassets`.
enum AppIconChoice: String, CaseIterable, Identifiable {
    case classique = "Classique"
    case grenadine = "Grenadine"
    case orchidee = "Orchidee"
    case fuchsia = "Fuchsia"
    case neon = "Neon"
    case saphir = "Saphir"
    case crepuscule = "Crepuscule"
    case tropique = "Tropique"
    case foret = "Foret"
    case flamme = "Flamme"
    case braise = "Braise"
    case barbeAPapa = "BarbeAPapa"
    case noirBlanc = "NoirBlanc"
    case lagon = "Lagon"
    case menthe = "Menthe"
    case aurore = "Aurore"
    case minuit = "Minuit"
    case ambre = "Ambre"
    case terracotta = "Terracotta"
    case ardoise = "Ardoise"

    var id: String { rawValue }

    /// Un réglage inconnu (icône retirée depuis) revient à l'icône classique.
    init(stored: String) {
        self = AppIconChoice(rawValue: stored) ?? .classique
    }

    /// Le nom donné à `setAlternateIconName` ; `nil` pour l'icône principale.
    var iconName: String? {
        self == .classique ? nil : "AppIcon-\(rawValue)"
    }

    var title: LocalizedStringResource {
        switch self {
        case .classique: "Classique"
        case .grenadine: "Grenadine"
        case .orchidee: "Orchidée"
        case .fuchsia: "Fuchsia"
        case .neon: "Néon"
        case .saphir: "Saphir"
        case .crepuscule: "Crépuscule"
        case .tropique: "Tropique"
        case .foret: "Forêt"
        case .flamme: "Flamme"
        case .braise: "Braise"
        case .barbeAPapa: "Barbe à papa"
        case .noirBlanc: "Noir et blanc"
        case .lagon: "Lagon"
        case .menthe: "Menthe"
        case .aurore: "Aurore"
        case .minuit: "Minuit"
        case .ambre: "Ambre"
        case .terracotta: "Terracotta"
        case .ardoise: "Ardoise"
        }
    }

    /// La couleur d'accent de l'app avec cette icône.
    var accent: Color {
        self == .classique ? .accent : Color("Accent\(rawValue)")
    }

    var preview: Image {
        Image("Icon\(rawValue)")
    }

    /// Change l'icône de l'app ; iOS l'annonce lui-même par une alerte.
    /// Renvoie `false` si iOS refuse : le choix précédent reste alors en place.
    @MainActor
    static func apply(_ choice: AppIconChoice) async -> Bool {
        let application = UIApplication.shared
        // Sans icônes alternatives, seule la couleur change.
        guard application.supportsAlternateIcons,
              application.alternateIconName != choice.iconName else { return true }
        do {
            try await application.setAlternateIconName(choice.iconName)
            return true
        } catch {
            Log.ui.error("Changement d'icône impossible : \(error.localizedDescription)")
            return false
        }
    }
}

/// La page des icônes, ouverte depuis les paramètres.
struct AppIconSettingsView: View {
    var body: some View {
        ScrollView {
            CardSection(footer: "La couleur de l'app suit l'icône choisie.") {
                AppIconPicker()
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 30)
        }
        .readableScrollContent()
        .navigationTitle("Icône de l'app")
    }
}

/// La grille des icônes, sous son nom ; la choisie est cochée.
struct AppIconPicker: View {
    @AppStorage(SettingKey.appIcon) private var stored = AppIconChoice.classique.rawValue

    private var selection: AppIconChoice { AppIconChoice(stored: stored) }

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 74), spacing: 8, alignment: .top)], spacing: 14) {
            ForEach(AppIconChoice.allCases) { choice in
                Button {
                    select(choice)
                } label: {
                    cell(for: choice)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(choice.title))
                .accessibilityAddTraits(choice == selection ? .isSelected : [])
            }
        }
        .padding(.vertical, 12)
        .sensoryFeedback(.selection, trigger: stored)
    }

    private func cell(for choice: AppIconChoice) -> some View {
        let isSelected = choice == selection
        return VStack(spacing: 6) {
            choice.preview
                .resizable()
                .frame(width: 60, height: 60)
                .overlay(alignment: .bottomTrailing) {
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, choice.accent)
                            .offset(x: 4, y: 4)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
            Text(choice.title)
                .font(.caption)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundStyle(isSelected ? choice.accent : .primary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }

    private func select(_ choice: AppIconChoice) {
        guard choice != selection else { return }
        Task {
            if await AppIconChoice.apply(choice) {
                withAnimation(.snappy) { stored = choice.rawValue }
            }
        }
    }
}

#Preview("Icône de l'app") {
    AppIconSettingsView()
        .previewEnvironment()
}
