// _gisApp.swift
import SwiftUI

@main
struct _gisApp: App {
    @State private var appModel = AppModel()

    // Управляемый стиль иммерсии
    @State private var immersionStyle: ImmersionStyle = .mixed

    var body: some Scene {
        // Главное окно
        WindowGroup {
            ContentView()
                .environment(appModel)
        }
        .defaultSize(CGSize(width: 900, height: 800))

        // Окна со стрелкой (три отдельных экземпляра)
        // WindowGroup(id: "ArrowWindow1") {
        //     ArrowWindow(index: 1)
        //         .environment(appModel)
        // }
        // .defaultSize(CGSize(width: 640, height: 320))

        // WindowGroup(id: "ArrowWindow2") {
        //     ArrowWindow(index: 2)
        //         .environment(appModel)
        // }
        // .defaultSize(CGSize(width: 640, height: 320))

        // WindowGroup(id: "ArrowWindow3") {
        //     ArrowWindow(index: 3)
        //         .environment(appModel)
        // }
        // .defaultSize(CGSize(width: 640, height: 320))
    }
}

