//
//  LineColorsTests.swift
//  tpgNextFuncTests
//

import SwiftUI
import Testing
@testable import tpgNextFunc

@Suite("Couleurs des lignes")
struct LineColorsTests {
    private func rgb(_ hex: UInt32) -> Color {
        Color(red: Double(hex >> 16 & 0xFF) / 255, green: Double(hex >> 8 & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }

    @Test func catalogComesFirst() {
        // Le 12 des tpg : l'orange de search.ch, plus celui, approché, de `tpgColors`.
        #expect(LineColors.lineColor(for: "12", operatorName: "Transports Publics Genevois") == rgb(0xF5A300))
        #expect(LineColors.lineColor(for: "4", operatorName: "Verkehrsbetriebe Zürich") == rgb(0x11296F))
    }

    @Test func whiteAndBlackTakeTheNeutralColor() {
        // Les bus blancs et les trams noirs des VBZ disparaîtraient sur le fond.
        #expect(LineColors.lineColor(for: "37", operatorName: "Verkehrsbetriebe Zürich") == .primary)
        #expect(LineColors.lineColor(for: "7", operatorName: "Verkehrsbetriebe Zürich", inverted: true) == .color1)
    }

    @Test func spacesInTheNumberDoNotMatter() {
        // Le relevé écrit « IC1 », comme le registre ; les horaires écrivent parfois « IC 1 ».
        #expect(LineColors.lineColor(for: "IC 1", operatorName: "Schweizerische Bundesbahnen SBB") == rgb(0xFF0000))
    }

    @Test func tablesStillCoverLinesOutsideTheCatalog() {
        // Les TAC d'Annemasse ne sont pas dans le registre suisse.
        #expect(LineColors.lineColor(for: "TANGO", operatorName: "Transports Publics de l'agglomération d'Annemasse")
                == LineColors.lineBlue)
    }
}
