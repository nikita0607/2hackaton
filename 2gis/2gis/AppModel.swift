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
    
    // === Route overlay state (для окна NavigationDemoView и окон-билбордов) ===
    var routeOriginLonLat: (lon: Double, lat: Double)?
    var maneuverNodes: [ManeuverNode] = []
    var routePolyline: RoutePolyline = .init(points: [])
    // чтобы не открывать дубликаты окон
    var openedBillboardNodeIDs: Set<UUID> = []
}
