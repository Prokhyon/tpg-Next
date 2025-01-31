//
//  TestWatchView.swift
//  watch tpg Next Watch App
//
//  Created by Loris Thomas on 04.01.2025.
//

import SwiftUI

struct TestWatchView: View {
    @State var selected: Int?
    @State var showTime = false
    @State var viewLineSorted = true
    @State var autoRefresh = false
    
    var body: some View {
        NavigationSplitView {
            List(selection: $selected) {
                NavigationLink("detail", value: 1)
            }
        } detail: {
//            if viewLineSorted {
//                ZStack {
                    TabView {
                        Text("Test1")
                        Text("Test2")
                        Text("Test3")
                    }
                    .tabViewStyle(.verticalPage)
                    .toolbar {
                        ToolbarItemGroup(placement: .bottomBar) {
                            Button {
                                // Action for button 1
                            } label: {
                                Image(systemName: "hourglass.circle.fill")
                            }
                            Button {
                                viewLineSorted.toggle()
                            } label: {
                                Image(systemName: "location.circle.fill")
                            }
                        }
                    }
//                    VStack {
//                        Text("Detail")
//                        Spacer()
//                    }
//                }
//            } else {
//                VStack {
//                    Text("TestA")
//                    Spacer()
//                }
//                .toolbar {
//                    ToolbarItemGroup(placement: .bottomBar) {
//                        Button {
//                            // Action for button 1
//                        } label: {
//                            Image(systemName: "hourglass.circle.fill")
//                        }
//                        Button {
//                            viewLineSorted.toggle()
//                        } label: {
//                            Image(systemName: "location.circle.fill")
//                        }
//                    }
//                }
//            }
            
            
//            if let selected = selected {
//                StopView(stopName: "Genève, Rive", stopCodedidoc: "8593006", isCloseStop: false, showTime: $showTime, viewLineSorted: $viewLineSorted, autoRefresh: $autoRefresh)
//                    
//            } else {
//            }
        }
    }
}

#Preview {
    TestWatchView()
}
