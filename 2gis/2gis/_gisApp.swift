// _gisApp.swift
import SwiftUI

@main
struct _gisApp: App {
    @State private var appModel = AppModel()
    @State private var avPlayerViewModel = AVPlayerViewModel()

    // Управляемый стиль иммерсии
    @State private var immersionStyle: ImmersionStyle = .mixed

    var body: some Scene {
        // Главное окно
        WindowGroup {
            if avPlayerViewModel.isPlaying {
                AVPlayerView(viewModel: avPlayerViewModel)
            } else {
                ContentView()
                    .environment(appModel)
            }
        }
        .defaultSize(CGSize(width: 900, height: 800))

        // Окно со стрелкой
        WindowGroup(id: "ArrowWindow") {
            ArrowWindow()
                .environment(appModel)
        }
        .defaultSize(CGSize(width: 640, height: 320))

        // Иммерсивная сцена
        ImmersiveSpace(id: appModel.immersiveSpaceID) {
            ImmersiveView()
                .environment(appModel)
                // ✅ Здесь .onAppear работает, потому что это View
                .onAppear {
                    immersionStyle = (appModel.selectedScene == .arrow) ? .mixed : .full
                }
                // ✅ Здесь тоже можно следить за изменением сцены
                .onChange(of: appModel.selectedScene) { _, newValue in
                    switch newValue {
                    case .arrow:
                        immersionStyle = .mixed
                    case .cube:
                        immersionStyle = .full
                    }
                }
        }
        // ✅ Модификатор применяется к ImmersiveSpace (Scene) корректно
        .immersionStyle(selection: $immersionStyle, in: .mixed, .full)
    }
}


