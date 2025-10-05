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
    var generatedBillboards: [GeneratedBillboard] = []
    // Текущее положение пользователя и прогресс по маршруту (в метрах)
    var userLonLat: (lon: Double, lat: Double)?
    var userAlongMeters: Double = 0
    // Подсказка поворота (эмоджи + текст)
    var userTurnHint: String = ""
    // чтобы не открывать дубликаты окон
    var openedBillboardNodeIDs: Set<UUID> = []
    // Точное значение узла, с которым открывалось окно (для корректного dismiss)
    var openedBillboardNodesByID: [UUID: ManeuverNode] = [:]
}
