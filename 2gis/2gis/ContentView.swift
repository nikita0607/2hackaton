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
    @State private var navigationViewModel = NavigationViewModel()
    @State private var catalogViewModel = CatalogFlowViewModel()
    @State private var lonText: String = "37.625325"
    @State private var latText: String = "55.695281"

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                ScenePickerView(appModel: appModel)
                ScenePreview(selection: appModel.selectedScene)

                Divider()

                NavigationDemoView(viewModel: navigationViewModel)

                Divider()

                CatalogFlowSection(viewModel: catalogViewModel, lonText: $lonText, latText: $latText)
            }
            .padding(24)
        }
        .onChange(of: appModel.selectedScene) { _, newSelection in
            Task { await updateImmersiveSpace(for: newSelection) }
        }
    }

    @MainActor
    private func updateImmersiveSpace(for selection: AppModel.SceneSelection) async {
        switch selection {
        case .arrow:
            guard appModel.immersiveSpaceState == .open else { return }
            appModel.immersiveSpaceState = .inTransition
            await dismissImmersiveSpace()

        case .cube:
            guard appModel.immersiveSpaceState == .closed else { return }
            appModel.immersiveSpaceState = .inTransition
            let result = await openImmersiveSpace(id: appModel.immersiveSpaceID)
            switch result {
            case .opened:
                break
            case .userCancelled, .error:
                appModel.immersiveSpaceState = .closed
                appModel.selectedScene = .arrow
            @unknown default:
                appModel.immersiveSpaceState = .closed
                appModel.selectedScene = .arrow
            }
        }
    }
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

    var body: some View {
        switch selection {
        case .arrow:
            ArrowView()
                .frame(maxWidth: .infinity)
                .frame(height: 240)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("2GIS Navigation APIs")
                .font(.title2)
                .bold()

            Text("Вызовы выполняются с использованием предоставленного API ключа")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack {
                Button(action: loadRoute) {
                    Label("Построить маршрут", systemImage: "car")
                }
                .disabled(viewModel.isLoading)

                Button(action: loadMapMatch) {
                    Label("Map matching", systemImage: "map")
                }
                .disabled(viewModel.isLoading)

                Button(action: loadGeolocation) {
                    Label("Radar геолокация", systemImage: "location.north.line")
                }
                .disabled(viewModel.isLoading)
            }
            .buttonStyle(.borderedProminent)

            if viewModel.isLoading {
                ProgressView()
            }

            if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundStyle(Color.red)
            }

            if let route = viewModel.lastRouteResponse?.result.first {
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

            if let mapMatch = viewModel.lastMapMatchResponse {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Map matching")
                        .font(.headline)
                    if let distance = mapMatch.distance {
                        Text(String(format: "Длина: %.0f м", distance))
                    }
                    if let duration = mapMatch.duration {
                        Text(String(format: "Время: %.0f с", duration))
                    }
                    if let status = mapMatch.status {
                        Text("Статус: \(status)")
                            .font(.footnote)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
            }

            if let location = viewModel.lastGeolocationResponse?.location {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Геолокация Radar")
                        .font(.headline)
                    if let latitude = location.latitude, let longitude = location.longitude {
                        Text(String(format: "Lat: %.5f, Lon: %.5f", latitude, longitude))
                    }
                    if let accuracy = location.accuracy {
                        Text(String(format: "Точность: %.0f м", accuracy))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private func loadRoute() {
        Task { await viewModel.loadSampleRoute() }
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
