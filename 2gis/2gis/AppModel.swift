//
//  AppModel.swift
//  2gis
//
//  Created by Павел on 04.10.2025.
//

import SwiftUI

/// Maintains app-wide state
@MainActor
@Observable
class AppModel {
    let immersiveSpaceID = "ImmersiveSpace"
    enum ImmersiveSpaceState { case closed, inTransition, open }

    // 👇 новый флаг режима
    enum UIMode { case immersive, menu }
    var uiMode: UIMode = .immersive

    enum SceneSelection: String, CaseIterable, Equatable, Hashable {
        case arrow
        case cube
    }

    var immersiveSpaceState = ImmersiveSpaceState.closed
    var selectedScene: SceneSelection = .arrow

    // ✅ Добавь этот флаг — используется в ContentView для одноразового открытия окон
    var hasOpenedArrowWindowOnce: Bool = false

    // Дистанция для стрелки (м) с жёстким клэмпом 1...5
    private(set) var arrowDistance: Float = 1.5
    func setArrowDistance(_ meters: Float) {
        arrowDistance = max(1.0, min(5.0, meters))
    }
}
