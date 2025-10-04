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
    @State private var navigationViewModel = NavigationViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                ToggleImmersiveSpaceButton()

                Divider()

                NavigationDemoView(viewModel: navigationViewModel)
            }
            .padding(24)
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

#Preview(windowStyle: .automatic) {
    ContentView()
        .environment(AppModel())
}
