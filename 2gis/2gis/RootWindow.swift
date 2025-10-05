//
//  RootWindow.swift
//  2gis
//
//  Created by Павел on 05.10.2025.
//

import SwiftUI

struct RootWindow: View {
    @Environment(AppModel.self) private var appModel
    @Bindable var avPlayerViewModel: AVPlayerViewModel

    var body: some View {
        ZStack {
            if avPlayerViewModel.isPlaying {
                // 🔵 твоя «синяя менюшка»/AVPlayer экран
                AVPlayerView(viewModel: avPlayerViewModel)
            } else {
                ContentView()
            }

            // Невидимый мост, который следит за appModel.uiMode и управляет Immersive Space
            ImmersiveBridge()
        }
        // Любое включение «менюшки» переключает режим → мост закроет Immersive
        .onChange(of: avPlayerViewModel.isPlaying) { _, playing in
            appModel.uiMode = playing ? .menu : .immersive
        }
        // Стартовый режим — в зависимости от текущего состояния
        .task {
            appModel.uiMode = avPlayerViewModel.isPlaying ? .menu : .immersive
        }
    }
}

