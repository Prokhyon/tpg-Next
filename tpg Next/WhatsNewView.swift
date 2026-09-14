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
        id: "1.2.0",
        items: [
            Item(systemImage: "widget.medium",
                 title: "Widgets",
                 description: "Affichez les prochains départs d'un arrêt directement sur l'écran d'accueil"),
            Item(systemImage: "point.topleft.down.to.point.bottomright.curvepath.fill",
                 title: "Tracé de ligne",
                 description: "Les tracés sur les cartes suivent désormais les routes"),
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
                                .foregroundStyle(.accent)
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

            if #available(iOS 26, *) {
                Button { dismiss() } label: {
                    Text("Continuer").foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 30)
                }
                .buttonStyle(.glassProminent)
            } else {
                Button { dismiss() } label: {
                    Text("Continuer").foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 30)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }
}

#Preview {
    WhatsNewView(whatsNew: WhatsNew.current!)
}
