//
//  StopTest.swift
//  tpg Next
//
//  Created by Loris Thomas on 02.08.2026.
//

import SwiftUI
import Combine
import tpgNextFunc


struct StopTest: View {
    @StateObject private var stopManager = StopManager()
    
    var body: some View {
        Button("Test") {
            stopManager.selectStop(stopName: "Tavannes", stopSloid: "ch:1:sloid:100", stopEventNumber: 5, timeRequest: Date())
        }
    }
}



#Preview {
    StopTest()
}
