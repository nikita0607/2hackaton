//
//  ContentView.swift
//  2gis
//
//  Created by Павел on 04.10.2025.
//

import SwiftUI
import RealityKit
import Observation

struct ContentView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @Environment(\.openWindow) private var openWindow

    @State private var navigationViewModel = NavigationViewModel()
    @State private var catalogViewModel = CatalogFlowViewModel()
    
    @State private var destPoint: RoutePoint = RoutePoint(lon: 0, lat: 0, type: RoutePoint.PointType.stop)
    @State private var destinationPlaceText: String = ""
    
    @State private var lonText: String = "37.625325"
    @State private var latText: String = "55.695281"

    // NEW:
    @State private var locationService = LocationService()

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
            // Выбор сцены
            // ScenePickerView(appModel: appModel)

            // Текущие GPS-координаты
            gpsBlock

            Divider()

            // Демонстрация Navigation API
                NavigationDemoView(viewModel: navigationViewModel, addrText: $destinationPlaceText, locationService: $locationService, destPoint: $destPoint)

            Divider()

            // Каталог по координатам
            CatalogFlowSection(viewModel: catalogViewModel, lonText: $lonText, latText: $latText)
            }
            .padding(24)
        }
        .onAppear {
            locationService.distanceThresholdMeters = 1.0
            locationService.start()
            if appModel.selectedScene == .arrow && !appModel.hasOpenedArrowWindowOnce {
                openWindow(id: "ArrowWindow1")
                openWindow(id: "ArrowWindow2")
                openWindow(id: "ArrowWindow3")
                appModel.hasOpenedArrowWindowOnce = true
            }
//            Task { await updateImmersiveSpace(for: appModel.selectedScene) }
        }
        .onChange(of: locationService.currentLocation) { _, newLoc in
            guard let loc = newLoc else { return }
            lonText = String(format: "%.6f", loc.coordinate.longitude)
            latText = String(format: "%.6f", loc.coordinate.latitude)
    
            if locationService.checkAndSnapIfNeeded() {
                Task {
                    await catalogViewModel.run(lon: loc.coordinate.longitude, lat: loc.coordinate.latitude)
                }
            }
        }
        // ✅ Изменение сцены: открыть окна стрелок и синхронизировать Immersive
        .onChange(of: appModel.selectedScene) { _, newSelection in
            Task {
                if newSelection == .arrow && !appModel.hasOpenedArrowWindowOnce {
                    openWindow(id: "ArrowWindow1")
                    openWindow(id: "ArrowWindow2")
                    openWindow(id: "ArrowWindow3")
                    appModel.hasOpenedArrowWindowOnce = true
                }
//                await updateImmersiveSpace(for: newSelection)
            }
        }
    }


    private var gpsBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("GPS")
                .font(.title3).bold()
            switch locationService.status {
            case .authorized:
                if let loc = locationService.currentLocation {
                    Text(String(format: "Lat: %.6f, Lon: %.6f (±%.0f м)",
                                loc.coordinate.latitude,
                                loc.coordinate.longitude,
                                loc.horizontalAccuracy))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Ожидание данных…").foregroundStyle(.secondary)
                }
            case .requesting:
                Text("Запрашиваем разрешение…").foregroundStyle(.secondary)
            case .denied:
                Text("Доступ к геолокации запрещён. Разрешите доступ в настройках.")
                    .foregroundStyle(.red)
            case .restricted:
                Text("Геолокация недоступна (ограничения системы).")
                    .foregroundStyle(.red)
            case .idle:
                Text("Инициализация сервиса…").foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    // @MainActor
    // private func updateImmersiveSpace(for selection: AppModel.SceneSelection) async {
    //     // 🚫 Если сейчас меню — не пытаемся открывать Immersive
    //     guard appModel.uiMode == .immersive else { return }

    //     switch appModel.immersiveSpaceState {
    //     case .closed:
    //         appModel.immersiveSpaceState = .inTransition
    //         let result = await openImmersiveSpace(id: appModel.immersiveSpaceID)
    //         switch result {
    //         case .opened: break
    //         case .userCancelled, .error: appModel.immersiveSpaceState = .closed
    //         @unknown default: appModel.immersiveSpaceState = .closed
    //         }
    //     case .open, .inTransition:
    //         break
    //     }
    // }
}

private struct ScenePickerView: View {
    @Bindable var appModel: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Выбор сцены")
                .font(.headline)

            Picker("Сцена", selection: $appModel.selectedScene) {
                Text("Плоская стрелка").tag(AppModel.SceneSelection.arrow)
                Text("3D куб").tag(AppModel.SceneSelection.cube)
            }
            .pickerStyle(.segmented)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ScenePreview: View {
    let selection: AppModel.SceneSelection
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        switch selection {
        case .arrow:
            VStack(alignment: .leading, spacing: 12) {
                Label("Окна со стрелкой", systemImage: "rectangle.on.rectangle")
                    .font(.headline)
                Text("Три окна со стрелкой открываются автоматически. В иммерсивной сцене показаны три стрелки с шагом 1 м по глубине.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))

        case .cube:
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: "cube")
                    .font(.largeTitle)
                Text("Куб отображается в иммерсивной сцене перед вами. Перемещайтесь свободно — объект остаётся закреплённым в пространстве.")
                    .font(.callout)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        }
    }
}

private struct NavigationDemoView: View {
    @Bindable var viewModel: NavigationViewModel
    @Binding var addrText: String
    @Binding var locationService: LocationService
    @Binding var destPoint: RoutePoint

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("2GIS Navigation APIs")
                .font(.title2)
                .bold()

            TextField("addr", text: $addrText)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.numbersAndPunctuation)
            
            Button(action: savePointFromAddr) {
                Label("Найти адрессс", systemImage: "house")
            }
            

            HStack {
                Button(action: loadRoute) {
                    Label("Построить маршрут", systemImage: "car")
                }
                .disabled(viewModel.isLoading)

                // Button(action: loadMapMatch) {
                //     Label("Map matching", systemImage: "map")
                // }
                // .disabled(viewModel.isLoading)

                // Button(action: loadGeolocation) {
                //     Label("Radar геолокация", systemImage: "location.north.line")
                // }
                // .disabled(viewModel.isLoading)
            }
            .buttonStyle(.borderedProminent)

            if viewModel.isLoading {
                ProgressView()
            }

            if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundStyle(Color.red)
            }

            if let route = viewModel.lastRouteResponse?.result?.first {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Маршрут: \(route.id ?? "неизвестно")")
                        .font(.headline)
                    if let algorithm = route.algorithm {
                        Text("Алгоритм: \(algorithm)")
                            .font(.subheadline)
                    }
                    if let maneuvers = route.maneuvers {
                        Text("Манёвры")
                            .font(.subheadline)
                            .bold()
                        ForEach(Array(maneuvers.prefix(3).enumerated()), id: \.offset) { index, maneuver in
                            Text("\(index + 1). \(maneuver.comment ?? "—")")
                                .font(.footnote)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
            }

            // if let mapMatch = viewModel.lastMapMatchResponse {
            //     VStack(alignment: .leading, spacing: 8) {
            //         Text("Map matching")
            //             .font(.headline)
            //         if let distance = mapMatch.distance {
            //             Text(String(format: "Длина: %.0f м", distance))
            //         }
            //         if let duration = mapMatch.duration {
            //             Text(String(format: "Время: %.0f с", duration))
            //         }
            //         if let status = mapMatch.status {
            //             Text("Статус: \(status)")
            //                 .font(.footnote)
            //         }
            //     }
            //     .frame(maxWidth: .infinity, alignment: .leading)
            //     .padding()
            //     .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
            // }

            // if let location = viewModel.lastGeolocationResponse?.location {
            //     VStack(alignment: .leading, spacing: 8) {
            //         Text("Геолокация Radar")
            //             .font(.headline)
            //         if let latitude = location.latitude, let longitude = location.longitude {
            //             Text(String(format: "Lat: %.5f, Lon: %.5f", latitude, longitude))
            //         }
            //         if let accuracy = location.accuracy {
            //             Text(String(format: "Точность: %.0f м", accuracy))
            //         }
            //     }
            //     .frame(maxWidth: .infinity, alignment: .leading)
            //     .padding()
            //     .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
            // }
        }
    }
    
    private func savePointFromAddr() {
        Task { 
            do {
                let client = DGisPlacesClient(
                    config: DGisPlacesClient.Config(apiKey: "6fe4cc7a-89b8-4aec-a5c3-ac94224044fe")
                )

                // bestMatch бросит ошибку, если ничего не найдено
                let best = try await client.bestMatch(self.addrText)

                // безопасно распакуем координаты
                guard let p = best.point,
                      let lon = p.lon,
                      let lat = p.lat else {
                    return
                }

                // обновляем UI на главном потоке
                await MainActor.run {
                    self.addrText = best.addressName ?? best.name

                    // ВАРИАНТ 1: если у тебя инициализатор помеченный:
                    self.destPoint = RoutePoint(lon: best.point!.lon!, lat: best.point!.lat!, type:RoutePoint.PointType.stop)

                    // ВАРИАНТ 2: если требуется ещё type:
                    // self.destPoint = RoutePoint(lon: lon, lat: lat, type: .pref)

                    // ВАРИАНТ 3: если у тебя позиционный init:
                    // self.destPoint = RoutePoint(lon, lat)
                }
            } catch {
                // обработай/залогуй ошибку
                print("Search failed:", error)
            }
        }
    }


    private func loadRoute() {
        Task { await viewModel.loadSampleRoute(locationService: locationService, destinationPoint:destPoint) }
    }

    private func loadMapMatch() {
        Task { await viewModel.loadSampleMapMatch() }
    }

    private func loadGeolocation() {
        Task { await viewModel.loadSampleGeolocation() }
    }
}

private struct CatalogFlowSection: View {
    @Bindable var viewModel: CatalogFlowViewModel
    @Binding var lonText: String
    @Binding var latText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Здание и организации по координате")
                .font(.title3)
                .bold()

            HStack(spacing: 12) {
                TextField("lon", text: $lonText)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.numbersAndPunctuation)
                TextField("lat", text: $latText)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.numbersAndPunctuation)
                Button {
                    Task {
                        if let lon = Double(lonText), let lat = Double(latText) {
                            await viewModel.run(lon: lon, lat: lat)
                        }
                    }
                } label: {
                    Label("Найти", systemImage: "building.2")
                }
                .disabled(viewModel.isRunning)
            }

            if viewModel.isRunning { ProgressView() }

            if let result = viewModel.lastResult {
                if let b = result.building {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(b.name).font(.headline)
                        if let addr = b.addressName { Text(addr).font(.subheadline) }
                        HStack(spacing: 8) {
                            if let floors = b.floors { Text("Этажей: \(floors)") }
                            if let material = b.structureInfo?.material { Text("Материал: \(material)") }
                            if let year = b.structureInfo?.yearOfConstruction { Text("Год: \(year)") }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                } else {
                    Text("Здание не найдено рядом с точкой").foregroundStyle(.secondary)
                }

                if !result.organizations.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Организации внутри")
                            .font(.headline)
                        ForEach(result.organizations, id: \.id) { org in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(org.name ?? "—").font(.subheadline).bold()
                                if let addr = org.addressName { Text(addr).font(.footnote).foregroundStyle(.secondary) }
                                if let rub = org.rubrics?.compactMap({ $0.name }).first { Text(rub).font(.footnote) }
                            }
                            .padding(8)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                        }
                    }
                } else {
                    Text("Организации не найдены").foregroundStyle(.secondary)
                }

                if !result.diagnostics.isEmpty {
                    Text(result.diagnostics.joined(separator: " · "))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

#Preview(windowStyle: .automatic) {
    ContentView()
        .environment(AppModel())
}
