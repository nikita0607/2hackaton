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
    enum ImmersiveSpaceState {
        case closed
        case inTransition
        case open
    }

    enum SceneSelection: String, CaseIterable, Equatable, Hashable {
        case arrow
        case cube
    }

    var immersiveSpaceState = ImmersiveSpaceState.closed
    var selectedScene: SceneSelection = .arrow
}
