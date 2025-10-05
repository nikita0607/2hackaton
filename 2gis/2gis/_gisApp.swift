// _gisApp.swift
import SwiftUI

@main
struct _gisApp: App {
    @State private var appModel = AppModel()

    var body: some Scene {
        // Главное окно (как было)
        WindowGroup {
            ContentView()
                .environment(appModel)
        }
        .defaultSize(CGSize(width: 900, height: 800))

        // Группа окон с карточками подсказок (билборды) по значениям узлов
        WindowGroup(id: "SignpostWindow", for: ManeuverNode.self) { $node in
            if let node {
                SignpostWindow(node: node)
                    .environment(appModel)
            } else {
                // fallback на случай отсутствия значения
                Text("Нет данных точки")
                    .padding()
            }
        }
        .defaultSize(CGSize(width: 260, height: 130))
        .windowResizability(.contentSize)
    }
}
