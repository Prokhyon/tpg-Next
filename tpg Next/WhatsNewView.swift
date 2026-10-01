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
    }

    static let current: WhatsNew? = WhatsNew(
        id: "1.1.4",
        items: [
            Item(systemImage: "widget.medium",
                 title: "Widgets",
                 description: "Affichez les prochains départs d'un arrêt directement sur l'écran d'accueil"),
            Item(systemImage: "map.fill",
                 title: "Tracés de ligne",
                 description: "Les tracés sur les cartes suivent désormais les routes"),
            Item(systemImage: "point.bottomleft.forward.to.point.topright.scurvepath.fill",
                 title: "Aperçus d'itinéraire",
                 description: "Une timeline simplifiée du trajet s'affiche à présent, avec lignes, changements, marches et attente dans les résultats et itinéraires enregistrés")
        ]
    )

    /// Clé `@AppStorage` de la dernière annonce vue.
    static let lastSeenKey = "LastSeenWhatsNew"
}

struct WhatsNewView: View {
    let whatsNew: WhatsNew
    @SwiftUICore.Environment(\.dismiss) private var dismiss

    var body: some View {
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
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
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
