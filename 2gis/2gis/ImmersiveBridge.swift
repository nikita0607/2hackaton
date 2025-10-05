//
//  ImmersiveBridge.swift
//  2gis
//
//  Created by Павел on 05.10.2025.
//

import SwiftUI

/// Невидимый мост, который живёт в главном окне и синхронизирует AppModel.uiMode с Immersive Space.
struct ImmersiveBridge: View {
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @Environment(AppModel.self) private var appModel

    var body: some View {
        // Ничего не рисуем — просто живём в иерархии.
        Color.clear
            .frame(width: 0, height: 0)
            .task { await sync(with: appModel.uiMode) }
            .onChange(of: appModel.uiMode) { _, newMode in
                Task { await sync(with: newMode) }
            }
    }

    @MainActor
    private func sync(with mode: AppModel.UIMode) async {
        switch mode {
        case .menu:
            // Меню — Immersive MUST die
            if appModel.immersiveSpaceState == .open {
                appModel.immersiveSpaceState = .inTransition
                await dismissImmersiveSpace()
                // .closed станет в ImmersiveView.onDisappear()
            }
        case .immersive:
            // Иммерсив — открыть, если закрыт
            if appModel.immersiveSpaceState == .closed {
                appModel.immersiveSpaceState = .inTransition
                let result = await openImmersiveSpace(id: appModel.immersiveSpaceID)
                if case .opened = result {
                    // .open станет в ImmersiveView.onAppear()
                } else {
                    appModel.immersiveSpaceState = .closed
                }
            }
        }
    }
}

