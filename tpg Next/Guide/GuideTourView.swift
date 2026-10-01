//
//  GuideTourView.swift
//  tpg Next
//
//  La visite guidée : quelques gestes à essayer, une page chacun. Proposée à la fin de la
//  bienvenue, et en tête du guide d'utilisation.
//

import SwiftUI

struct GuideTourStep: Identifiable {
    let demo: GuideDemo
    let symbol: String
    let title: LocalizedStringResource
    let text: LocalizedStringResource

    var id: GuideDemo { demo }
}

extension GuideTourStep {
    static let all: [GuideTourStep] = [
        GuideTourStep(demo: .favorite, symbol: "star.fill",
                      title: "Vos arrêts favoris",
                      text: "Dans les résultats d'une recherche, l'étoile ajoute un arrêt à vos favoris : il apparaît sur l'accueil et dans l'onglet Itinéraire. L'icône à droite ouvre un aperçu de son emplacement sur la carte."),
        GuideTourStep(demo: .departureTime, symbol: "hourglass",
                      title: "L'heure ou les minutes",
                      text: "Le sablier alterne entre l'heure de départ et le temps qu'il reste avant le passage."),
        GuideTourStep(demo: .reminder, symbol: "bell.fill",
                      title: "Un rappel avant de partir",
                      text: "Appuyez longuement sur un départ pour être prévenu à son arrivée, ou quelques minutes avant. Vous l'êtes aussi s'il prend de l'avance ou du retard."),
        GuideTourStep(demo: .sortAndFilter, symbol: "line.3.horizontal.decrease.circle.fill",
                      title: "Trier et filtrer",
                      text: "En bas de la page d'un arrêt, rangez les départs par ligne plutôt que par heure. Le filtre ouvre les lignes de l'arrêt : touchez-en une, puis sa direction, pour ne garder qu'elle."),
        GuideTourStep(demo: .earlierLater, symbol: "clock.arrow.2.circlepath",
                      title: "Plus tôt, plus tard",
                      text: "Les deux flèches en bas à droite de la page d'un arrêt affichent les départs précédents ou suivants. Entre elles, l'horloge choisit un jour et une heure précis, ou revient à maintenant."),
        GuideTourStep(demo: .tripActions, symbol: "point.bottomleft.forward.to.point.topright.scurvepath.fill",
                      title: "Un itinéraire depuis un arrêt",
                      text: "Sur un arrêt ou un favori, le bouton d'itinéraire prépare la recherche : partir de là, y aller, ou y aller tout de suite depuis votre position."),
        GuideTourStep(demo: .liveTracking, symbol: "inset.filled.circle",
                      title: "Le suivi en direct",
                      text: "Suivez votre trajet sur l'écran verrouillé. Quand une correspondance est serrée, l'app vous demande si vous êtes monté et adapte la suite."),
    ]
}

struct GuideTourView: View {
    /// Ouvre le guide complet ; `nil` depuis le guide lui-même.
    var onOpenGuide: (() -> Void)?
    let onClose: () -> Void

    private let steps = GuideTourStep.all
    @State private var index = 0
    @State private var tried: Set<GuideDemo> = []

    private var isOnSummary: Bool { index == steps.count }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            TabView(selection: $index) {
                ForEach(Array(steps.enumerated()), id: \.element.id) { position, step in
                    page(step).tag(position)
                }
                summary.tag(steps.count)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.snappy, value: index)
            bottomBar
        }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 5) {
                ForEach(0...steps.count, id: \.self) { position in
                    Capsule()
                        .fill(position <= index ? Color.accentColor : Color.secondary.opacity(0.25))
                        .frame(height: 4)
                }
            }
            .animation(.snappy, value: index)
            .accessibilityElement()
            .accessibilityLabel("Étape \(min(index + 1, steps.count)) sur \(steps.count)")
            Button(isOnSummary ? "Fermer" : "Passer") { onClose() }
                .font(.subheadline.weight(.semibold))
        }
        .padding(.horizontal)
        .padding(.top, 20)
        .padding(.bottom, 8)
    }

    private func page(_ step: GuideTourStep) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Image(systemName: step.symbol)
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .symbolEffect(.bounce, value: tried.contains(step.demo))
                    .padding(.top, 10)
                Text(step.title)
                    .font(.largeTitle.bold())
                    .fixedSize(horizontal: false, vertical: true)
                Text(step.text)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                GuideDemoView(demo: step.demo) {
                    tried.insert(step.demo)
                }
                .padding(.top, 10)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    private var summary: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.green)
                    .symbolEffect(.bounce, value: isOnSummary)
                    .padding(.top, 10)
                Text("Vous êtes prêt")
                    .font(.largeTitle.bold())
                Text("Il y a bien plus à découvrir : trajets réguliers, widgets, iPad et Apple Watch… Tout est dans le guide d'utilisation, depuis les paramètres.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(steps) { step in
                        let done = tried.contains(step.demo)
                        Button {
                            if let position = steps.firstIndex(where: { $0.id == step.id }) { index = position }
                        } label: {
                            Label {
                                Text(step.title).foregroundStyle(.primary)
                            } icon: {
                                Image(systemName: done ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(done ? Color.green : .secondary)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityValue(done ? Text("Essayé") : Text("Pas encore essayé"))
                    }
                }
                .padding(.top, 6)
            }
            .padding(.horizontal, 20)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    private var bottomBar: some View {
        HStack(spacing: 12) {
            if index > 0 {
                Button {
                    index -= 1
                } label: {
                    Image(systemName: "chevron.backward")
                        .font(.headline)
                        .frame(width: 30, height: 34)
                }
                .secondaryButtonStyle()
                .buttonBorderShape(.circle)
                .accessibilityLabel("Précédent")
            }
            if isOnSummary {
                if let onOpenGuide {
                    Button {
                        onOpenGuide()
                    } label: {
                        Text("Guide complet")
                            .frame(maxWidth: .infinity, minHeight: 34)
                    }
                    .secondaryButtonStyle()
                }
                Button {
                    onClose()
                } label: {
                    Text("Terminer")
                        .frame(maxWidth: .infinity, minHeight: 34)
                }
                .prominentButtonStyle()
            } else {
                Button {
                    index += 1
                } label: {
                    Text(index == steps.count - 1 ? "Terminer la visite" : "Suivant")
                        .frame(maxWidth: .infinity, minHeight: 34)
                }
                .prominentButtonStyle()
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .frame(maxWidth: 600)
        .animation(.snappy, value: index)
    }
}

#Preview("Visite guidée") {
    GuideTourView(onOpenGuide: {}, onClose: {})
        .previewEnvironment(navigation: false, favorites: [])
}
