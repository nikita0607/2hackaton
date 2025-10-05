//
//  ContentView.swift
//  2gis
//
//  Created by Павел on 04.10.2025.
//

import SwiftUI
import Observation

struct ContentView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.openWindow) private var openWindow

    @State private var navigationViewModel = NavigationViewModel()
    @State private var catalogViewModel = CatalogFlowViewModel()

    @State private var destPoint: RoutePoint = RoutePoint(lon: 0, lat: 0, type: RoutePoint.PointType.stop)
    @State private var destinationPlaceText: String = ""

    @State private var lonText: String = "37.625325"
    @State private var latText: String = "55.695281"

    // Текущая геолокация (для echo-origin и фонового каталога)
    @State private var locationService = LocationService()

    // Чтобы не обрабатывать один и тот же маршрут повторно
    @State private var lastProcessedRouteToken: String?

    // Стабильный токен для .task(id:) — берём route.id; если его нет, делаем безопасный ключ
    private var routeToken: String {
        if let r = navigationViewModel.lastRouteResponse?.result?.first {
            return (r.id ?? "no-id") + "|\(r.maneuvers?.count ?? -1)"
        }
        return "no-route"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Текущие GPS-координаты
                gpsBlock

                Divider()

                // Демонстрация Navigation API
                NavigationDemoView(
                    viewModel: navigationViewModel,
                    addrText: $destinationPlaceText,
                    locationService: $locationService,
                    destPoint: $destPoint
                )

                // Эскиз всего маршрута (по манёврам и полной полилинии)
                RouteOverlayPanel(
                    origin: appModel.routeOriginLonLat,
                    polyline: appModel.routePolyline,
                    nodes: appModel.maneuverNodes
                )

                Divider()

                // Каталог по координатам
                CatalogFlowSection(
                    viewModel: catalogViewModel,
                    lonText: $lonText,
                    latText: $latText
                )
            }
            .padding(24)
        }
        .onAppear {
            locationService.distanceThresholdMeters = 1.0
            locationService.start()
        }
        .onChange(of: locationService.currentLocation) { _, newLoc in
            guard let loc = newLoc else { return }
            lonText = String(format: "%.6f", loc.coordinate.longitude)
            latText = String(format: "%.6f", loc.coordinate.latitude)

            if locationService.checkAndSnapIfNeeded() {
                Task {
                    await catalogViewModel.run(
                        lon: loc.coordinate.longitude,
                        lat: loc.coordinate.latitude
                    )
                }
            }
        }
        // ✅ БЕЗ Equatable: побочные действия при смене маршрута — через .task(id:)
        // SwiftUI перезапустит этот блок, когда поменяется routeToken (обычно = route.id).
        .task(id: routeToken) {
            guard routeToken != "no-route",
                  routeToken != lastProcessedRouteToken,
                  let resp = navigationViewModel.lastRouteResponse else { return }

            // 1) Origin — фиксируем на момент построения маршрута
            if let loc = locationService.currentLocation {
                appModel.routeOriginLonLat = (
                    lon: loc.coordinate.longitude,
                    lat: loc.coordinate.latitude
                )
            } else {
                // Фоллбэк: если нет GPS, возьмём первую точку из полилинии (ниже её построим)
                appModel.routeOriginLonLat = nil
            }

            // 2) Узлы манёвров + цельная полилиния (локальные функции ниже)
            let nodes = extractManeuverNodes(from: resp)
            var full  = extractFullPolyline(from: resp)

            // Если origin ещё пуст — выберем первую точку маршрута
            if appModel.routeOriginLonLat == nil {
                if let first = full.points.first {
                    appModel.routeOriginLonLat = (lon: first.lon, lat: first.lat)
                } else if let n = nodes.first {
                    appModel.routeOriginLonLat = (lon: n.lon, lat: n.lat)
                }
            }

            appModel.maneuverNodes = nodes
            appModel.routePolyline = full

            // 3) Автоподъём независимых окон-билбордов по всем узлам (ограничим число)
            let maxWindows = 8
            for node in nodes.prefix(maxWindows) where !appModel.openedBillboardNodeIDs.contains(node.id) {
                openWindow(id: "SignpostWindow", value: node)
                appModel.openedBillboardNodeIDs.insert(node.id)
            }

            lastProcessedRouteToken = routeToken
        }
    }

    // MARK: - GPS Block

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
}

// MARK: - NavigationDemoView (как раньше)

private struct NavigationDemoView: View {
    @Environment(AppModel.self) private var appModel
    @Bindable var viewModel: NavigationViewModel
    @Binding var addrText: String
    @Binding var locationService: LocationService
    @Binding var destPoint: RoutePoint

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("2GIS Navigation APIs").font(.title2).bold()

            TextField("addr", text: $addrText)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.numbersAndPunctuation)

            HStack {
                Button(action: savePointFromAddr) {
                    Label("Найти адрессс", systemImage: "house")
                }
                Button(action: loadRoute) {
                    Label("Построить маршрут", systemImage: "car")
                }
                .disabled(viewModel.isLoading)
            }
            .buttonStyle(.borderedProminent)

            if viewModel.isLoading { ProgressView() }

            if let error = viewModel.errorMessage {
                Text(error).foregroundStyle(.red)
            }

            if let route = viewModel.lastRouteResponse?.result?.first {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Маршрут: \(route.id ?? "неизвестно")").font(.headline)
                    if let algorithm = route.algorithm {
                        Text("Алгоритм: \(algorithm)").font(.subheadline)
                    }
                    if let maneuvers = route.maneuvers {
                        Text("Манёвры").font(.subheadline).bold()
                        ForEach(Array(maneuvers.prefix(3).enumerated()), id: \.offset) { index, maneuver in
                            Text("\(index + 1). \(maneuver.comment ?? "—")").font(.footnote)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
            } else {
                Text("Постройте маршрут, чтобы увидеть оверлей.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func savePointFromAddr() {
        Task {
            do {
                let client = DGisPlacesClient(
                    config: DGisPlacesClient.Config(apiKey: "6fe4cc7a-89b8-4aec-a5c3-ac94224044fe")
                )
                let best = try await client.bestMatch(self.addrText)
                guard let p = best.point, let lon = p.lon, let lat = p.lat else { return }
                await MainActor.run {
                    self.addrText = best.addressName ?? best.name
                    self.destPoint = RoutePoint(lon: lon, lat: lat, type: .stop)
                }
            } catch {
                print("Search failed:", error)
            }
        }
    }

    private func loadRoute() {
        Task { await viewModel.loadSampleRoute(locationService: locationService, destinationPoint: destPoint) }
    }
}

// MARK: - Catalog Flow Section (как было)

private struct CatalogFlowSection: View {
    @Bindable var viewModel: CatalogFlowViewModel
    @Binding var lonText: String
    @Binding var latText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Здание и организации по координате")
                .font(.title3).bold()

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
                        Text("Организации внутри").font(.headline)
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

// MARK: - 2D Sketch Panel (Canvas) — полный маршрут + узлы манёвров

struct RouteOverlayPanel: View {
    let origin: (lon: Double, lat: Double)?
    let polyline: RoutePolyline
    let nodes: [ManeuverNode]

    private let panelHeight: CGFloat = 240

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Маршрут (эскиз)").font(.headline)
            Canvas { ctx, size in
                guard let origin, !polyline.points.isEmpty else {
                    ctx.draw(Text("Нет данных для отрисовки"),
                             at: CGPoint(x: size.width/2, y: size.height/2))
                    return
                }
                // 1) Гео → «метры» (локальная ENU от origin)
                let meters: [SIMD2<Double>] = polyline.points.map {
                    Geo.geoToMeters(lon: $0.lon, lat: $0.lat,
                                    originLon: origin.lon, originLat: origin.lat)
                }

                // 2) Нормализация в виджет с отступами
                let inset = 18.0
                let xs = meters.map { $0.x }, zs = meters.map { $0.y }
                guard let minX = xs.min(), let maxX = xs.max(),
                      let minZ = zs.min(), let maxZ = zs.max() else { return }
                let w = max(maxX - minX, 1.0), h = max(maxZ - minZ, 1.0)
                let scale = min(Double(size.width - inset*2)/w,
                                Double(size.height - inset*2)/h)

                func mapPoint(_ m: SIMD2<Double>) -> CGPoint {
                    let x = (m.x - minX) * scale + inset
                    let y = (m.y - minZ) * scale + inset
                    // инвертируем по вертикали (экранная Y вниз)
                    return CGPoint(x: x, y: Double(size.height) - y)
                }

                // 3) Линия маршрута
                var path = Path()
                path.move(to: mapPoint(meters[0]))
                for i in 1..<meters.count { path.addLine(to: mapPoint(meters[i])) }
                ctx.stroke(path, with: .color(.white.opacity(0.85)), lineWidth: 4)

                // 4) Узлы-манёвры
                for (i, n) in nodes.enumerated() {
                    let p2 = Geo.geoToMeters(lon: n.lon, lat: n.lat,
                                             originLon: origin.lon, originLat: origin.lat)
                    let p = mapPoint(p2)
                    let r: CGFloat = (i == 0 || i == nodes.count-1) ? 6 : 4
                    let rect = CGRect(x: p.x - r, y: p.y - r, width: r*2, height: r*2)
                    ctx.fill(Path(ellipseIn: rect),
                             with: .color(i == 0 ? .green : (i == nodes.count-1 ? .red : .cyan)))
                }
            }
            .frame(height: panelHeight)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Локальные хелперы извлечения данных из RouteResponse (без зависимостей от ViewModel)

private func extractManeuverNodes(from response: RouteResponse) -> [ManeuverNode] {
    guard let route = response.result?.first, let mans = route.maneuvers else { return [] }
    return mans.compactMap { m in
        guard let sel = m.outcomingPath?.geometry?.first?.selection else { return nil }
        guard let first = WKT.parseLineString(sel).first else { return nil }
        let t: String
        switch (m.icon ?? "") {
        case "turn_right": t = "↱"
        case "turn_left":  t = "↰"
        case "finish":     t = "●"
        case "start":      t = "◎"
        default:           t = "⬆︎"
        }
        return ManeuverNode(lon: first.lon, lat: first.lat, title: t, detail: m.outcomingPathComment ?? m.comment)
    }
}

private func extractFullPolyline(from response: RouteResponse) -> RoutePolyline {
    guard let route = response.result?.first, let mans = route.maneuvers else {
        return .init(points: [])
    }
    var all: [GeoPoint] = []
    for m in mans {
        if let sel = m.outcomingPath?.geometry?.first?.selection {
            let pts = WKT.parseLineString(sel) // [(lon, lat)]
            guard !pts.isEmpty else { continue }
            if let last = all.last, let first = pts.first,
               last.lon == first.lon, last.lat == first.lat {
                all.append(contentsOf: pts.dropFirst().map { GeoPoint(lon: $0.lon, lat: $0.lat) })
            } else {
                all.append(contentsOf: pts.map { GeoPoint(lon: $0.lon, lat: $0.lat) })
            }
        }
    }
    return .init(points: all)
}
