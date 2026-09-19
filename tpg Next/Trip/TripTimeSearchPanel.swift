//
//  TripTimeSearchPanel.swift
//  tpg Next
//
//  Carte du bas de l'itinéraire : date et heure, départ ou arrivée, bouton de recherche.
//

import SwiftUI
import tpgNextFunc

struct TripTimeSearchPanel: View {
    @Environment(ItineraryViewModel.self) private var itineraryViewModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// Lance la recherche ; appelée seulement quand départ et arrivée sont choisis.
    let search: () -> Void
    @Namespace private var animation
    @State private var timeAnimate = false

    var body: some View {
        @Bindable var viewModel = itineraryViewModel
        VStack(spacing: 15) {
            let resetTimeButton = Button(action: {
                viewModel.selectedTime = Date()
                viewModel.tripDone = false
                timeAnimate.toggle()
            }) {
                Image(systemName: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                    .symbolEffect(.rotate, value: timeAnimate)
                    .font(.title2)
            }
            // Jusqu'à la taille de texte par défaut, le libellé reste à gauche (sur deux
            // lignes au besoin) ; au-delà, il passe au-dessus : il s'étirait sinon à une
            // ou deux lettres par ligne.
            if dynamicTypeSize <= .large {
                HStack {
                    DatePicker(selection: $viewModel.selectedTime) {
                        Text("Date et heure:")
                    }
                    .padding(.trailing, 5)
                    resetTimeButton
                }
            } else {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Date et heure:")
                    HStack {
                        DatePicker("Date et heure:", selection: $viewModel.selectedTime)
                            .labelsHidden()
                        Spacer()
                        resetTimeButton
                    }
                }
            }

            if #available(iOS 26, *) {
                HStack {
                    Picker("", selection: $viewModel.isArrivalTime) {
                        Text("Départ").tag(false)
                        Text("Arrivée").tag(true)
                    }
                    .pickerStyle(.segmented)
                    Button {

                        if viewModel.canSearch {
                            withAnimation {
                                search()
                                viewModel.tripDone = true
                            }
                        }
                    } label: {
                        Text("Rechercher")
                            .foregroundStyle(.white)
                            .padding(.vertical, 10)
                            .padding(.horizontal)
                            .glassEffect(.regular.tint(viewModel.canSearch ? .accentColor : .gray).interactive(viewModel.canSearch))
                    }
                    .disabled(!viewModel.canSearch)
                }
            } else {
                HStack {
                    CustomPicker(secondSelected: $viewModel.isArrivalTime, height: 45, firstOption: String(localized: "Départ"), firstIcon: nil, secondOption: String(localized: "Arrivée"), secondIcon: nil, animation: animation)
                        // Au plus 220 pt : sur un écran étroit, le sélecteur cède la place au bouton.
                        .frame(maxWidth: 220)

                    Button {
                        if viewModel.canSearch {
                            search()
                            viewModel.tripDone = true
                        }
                    } label: {
                        // Au moins 110 × 45 : le bouton s'élargit avec un texte agrandi.
                        Text("Rechercher")
                            .lineLimit(1)
                            .fixedSize()
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .frame(minWidth: 110, minHeight: 45)
                            .background {
                                Capsule()
                                    .fill(viewModel.canSearch ? .accent : .gray)
                                    .shadow(color: Color.customShadows, radius: 1, y: 0.8)
                            }
                    }
                    .disabled(!viewModel.canSearch)
                }
            }
        }
        .padding()
    }
}

#Preview("Heure de l'itinéraire") {
    VStack {
        Spacer()
        TripTimeSearchPanel {}
            .padding()
    }
    .previewEnvironment(itinerary: (PreviewData.rive, PreviewData.cornavin))
}

#Preview("Heure de l'itinéraire — sans arrivée") {
    VStack {
        Spacer()
        TripTimeSearchPanel {}
            .padding()
    }
    .previewEnvironment()
}
