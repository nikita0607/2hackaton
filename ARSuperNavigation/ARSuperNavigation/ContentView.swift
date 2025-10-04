//
//  ContentView.swift
//  ARSuperNavigation
//
//  Created by Никита Пырлицану on 05.10.2025.
//

import SwiftUI
import RealityKit

struct ContentView: View {

    var body: some View {
        VStack {
            ToggleImmersiveSpaceButton()
        }
    }
}

#Preview(windowStyle: .automatic) {
    ContentView()
        .environment(AppModel())
}
