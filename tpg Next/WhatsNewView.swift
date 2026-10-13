//
//  WhatsNewView.swift
//  tpg Next
//

import SwiftUI

/// Annonce des nouveautés, affichée une seule fois par annonce.
///
/// Pour annoncer une mise à jour : modifier `items` **et** changer `id`.
/// Pour une mise à jour sans annonce : ne rien toucher, la sheet ne réapparaît pas
/// (l'identifiant déjà vu reste le même). `current = nil` désactive toute annonce.
struct WhatsNew {
    /// Identifiant libre de l'annonce, indépendant du numéro de version.
    let id: String
    let items: [Item]

    struct Item: Identifiable {
        let id = UUID()
        let systemImage: String
        let title: LocalizedStringResource
        let description: LocalizedStringResource
        /// Boutons posés sous la description.
        var links: [Link] = []
    }

    enum Link {
        /// La visite guidée, ouverte dans la feuille.
        case tour
        /// Le guide d'utilisation, ouvert dans l'onglet en cours une fois la feuille fermée.
        case guide
    }

    static let current: WhatsNew? = WhatsNew(
        id: "1.2",
        items: [
            Item(systemImage: "calendar.badge.clock",
                 title: "Trajets réguliers",
                 description: "Enregistrez vos trajets de la semaine : rappels et alertes en cas de changement, un nouvel onglet Trajets et le widget Prochain trajet"),
            Item(systemImage: "inset.filled.circle",
                 title: "Suivi en direct",
                 description: "Suivez votre trajet sur l'écran verrouillé et dans la Dynamic Island : quand descendre, correspondances vérifiées, et une nouvelle suite proposée si l'une d'elles tombe"),
            Item(systemImage: "book.pages.fill",
                 title: "Bienvenue et guide",
                 description: "Un nouveau message de bienvenue et un guide d'utilisation à toucher du doigt. La visite guidée vous fait essayer l'essentiel en deux minutes",
                 links: [.tour, .guide]),
            Item(systemImage: "house.fill",
                 title: "Accueil repensé",
                 description: "Lieux favoris, carte « Autour de vous », sections à réorganiser, et synchronisation iCloud de vos favoris et trajets"),
            Item(systemImage: "paintpalette.fill",
                 title: "Icônes au choix",
                 description: "Vingt icônes dans Paramètres › Apparence, et les couleurs de l'app qui s'accordent à la vôtre"),
            Item(systemImage: "ipad.landscape.and.iphone",
                 title: "Nouvelle app pour iPad et iPhone Duo",
                 description: "Une expérience adaptée pour les grands écrans"),
            Item(systemImage: "exclamationmark.triangle.fill",
                 title: "Perturbations",
                 description: "Courses supprimées, arrêts non desservis et parcours modifiés sont signalés, avec l'arrêt desservi le plus proche"),
            Item(systemImage: "applewatch",
                 title: "Apple Watch",
                 description: "Complications des prochains départs, vos trajets envoyés par l'iPhone et le détail des courses")
        ]
    )

    /// Clé `@AppStorage` de la dernière annonce vue.
    static let lastSeenKey = "LastSeenWhatsNew"
}

struct WhatsNewView: View {
    let whatsNew: WhatsNew
    /// Ouvre le guide d'utilisation, une fois la feuille fermée.
    var openGuide: () -> Void = {}
    @SwiftUICore.Environment(\.dismiss) private var dismiss
    @State private var showsTour = false

    var body: some View {
        ZStack {
            if showsTour {
                GuideTourView(onOpenGuide: showGuide, onClose: { dismiss() })
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                announcement
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .animation(.smooth(duration: 0.45), value: showsTour)
    }

    private var announcement: some View {
        VStack(alignment: .leading) {
            Text("Nouveautés").font(.largeTitle).bold()
                .padding(.top, 30)
                .padding(.bottom, 20)

            ScrollView {
                VStack(alignment: .leading, spacing: 25) {
                    ForEach(whatsNew.items) { item in
                        HStack(alignment: .top, spacing: 15) {
                            Image(systemName: item.systemImage)
//                                .resizable()
//                                .aspectRatio(contentMode: .fit)
                                .font(.title)
                                .foregroundStyle(Color.accentColor)
                                .frame(width: 45)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.title).font(.headline)
                                Text(item.description)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                                if !item.links.isEmpty {
                                    HStack(spacing: 10) {
                                        ForEach(item.links, id: \.self) { link in
                                            linkButton(link)
                                        }
                                    }
                                    .padding(.top, 8)
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 16)
            }
            .scrollBounceBehavior(.basedOnSize)

            Button { dismiss() } label: {
                Text("Continuer").foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 30)
            }
            .prominentButtonStyle()
        }
        .padding()
    }

    @ViewBuilder private func linkButton(_ link: WhatsNew.Link) -> some View {
        switch link {
        case .tour:
            Button { showsTour = true } label: {
                Label("Visite guidée", systemImage: "hand.tap.fill")
            }
            .secondaryButtonStyle()
        case .guide:
            Button(action: showGuide) {
                Label("Guide", systemImage: "book.pages")
            }
            .secondaryButtonStyle()
        }
    }

    private func showGuide() {
        dismiss()
        openGuide()
    }
}

#Preview("Nouveautés") {
    WhatsNewView(whatsNew: WhatsNew.current!)
}

#Preview("Nouveautés — en feuille") {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            WhatsNewView(whatsNew: WhatsNew.current!)
        }
        .previewEnvironment(navigation: false)
}
