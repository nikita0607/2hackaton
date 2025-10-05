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
    @Environment(\.dismissWindow) private var dismissWindow

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

                // Эскиз маршрута (манёвры и полная полилиния)
                RouteOverlayPanel(
                    origin: appModel.routeOriginLonLat,
                    polyline: appModel.routePolyline,
                    nodes: appModel.maneuverNodes,
                    generated: appModel.generatedBillboards,
                    user: appModel.userLonLat,
                    userAlong: appModel.userAlongMeters
                )

                Divider()

                // Каталог объектов по координатам
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
            // Используем реальный GPS (без мок-геопозиции)
            locationService.mode = .real
            locationService.start()
            navigationViewModel.startContinuousPositionCheck(locationService: locationService)
        }
        .onDisappear { navigationViewModel.stopContinuousPositionCheck() }
        .onChange(of: locationService.currentLocation) { _, newLoc in
            guard let loc = newLoc else { return }
            lonText = String(format: "%.6f", loc.coordinate.longitude)
            latText = String(format: "%.6f", loc.coordinate.latitude)

            // Сохраним предыдущую позицию и обновим текущую
            let prevUser = appModel.userLonLat
            appModel.userLonLat = (lon: loc.coordinate.longitude, lat: loc.coordinate.latitude)

            if locationService.checkAndSnapIfNeeded() {
                Task {
                    await catalogViewModel.run(
                        lon: loc.coordinate.longitude,
                        lat: loc.coordinate.latitude
                    )
                }
            }

            // Динамическое управление окнами-билбордами по мере продвижения
            if let origin = appModel.routeOriginLonLat, !appModel.routePolyline.points.isEmpty, !appModel.generatedBillboards.isEmpty {
                let along = projectAlongMeters(
                    lon: loc.coordinate.longitude,
                    lat: loc.coordinate.latitude,
                    origin: origin,
                    polyline: appModel.routePolyline
                )
                appModel.userAlongMeters = along

                // Берём только один ближайший впереди билборд
                let upcoming = appModel.generatedBillboards.filter { $0.alongMeters + 0.1 >= along }
                let nextBillboard = upcoming.first
                let desiredIDs: Set<UUID> = nextBillboard.map { Set([$0.id]) } ?? []

                // Закрыть лишние окна (используем исходное значение узла, с которым открывали)
                let toClose = appModel.openedBillboardNodeIDs.subtracting(desiredIDs)
                for id in toClose {
                    if let openedNode = appModel.openedBillboardNodesByID[id] {
                        dismissWindow(id: "SignpostWindow", value: openedNode)
                        appModel.openedBillboardNodesByID.removeValue(forKey: id)
                    } else {
                        // Фоллбэк: если не знаем точного значения, закроем все окна этой сцены
                        dismissWindow(id: "SignpostWindow")
                        appModel.openedBillboardNodesByID.removeAll()
                        appModel.openedBillboardNodeIDs.removeAll()
                        break
                    }
                    appModel.openedBillboardNodeIDs.remove(id)
                }

                // Открыть недостающее окно (ровно одно)
                if let b = nextBillboard, !appModel.openedBillboardNodeIDs.contains(b.id) {
                    let distanceLeft = max(0, Int((b.alongMeters - along).rounded()))
                    let node = ManeuverNode(id: b.id, lon: b.lon, lat: b.lat, title: "⬆︎", detail: distanceLeft > 0 ? "через \(distanceLeft) м" : nil)
                    openWindow(id: "SignpostWindow", value: node)
                    appModel.openedBillboardNodeIDs.insert(b.id)
                    appModel.openedBillboardNodesByID[b.id] = node
                }
            }
        }
        // Побочные действия при смене маршрута выполняем через .task(id: routeToken)
        // SwiftUI переинициализирует этот блок при изменении routeToken (обычно соответствует route.id)
        .task(id: routeToken) {
            guard routeToken != "no-route",
                  routeToken != lastProcessedRouteToken,
                  let resp = navigationViewModel.lastRouteResponse else { return }

            // Закрыть ранее открытые окна билбордов (смена маршрута)
            if !appModel.openedBillboardNodeIDs.isEmpty {
                let prevIds = appModel.openedBillboardNodeIDs
                for id in prevIds {
                    if let openedNode = appModel.openedBillboardNodesByID[id] {
                        dismissWindow(id: "SignpostWindow", value: openedNode)
                        appModel.openedBillboardNodesByID.removeValue(forKey: id)
                    } else {
                        dismissWindow(id: "SignpostWindow")
                        appModel.openedBillboardNodesByID.removeAll()
                        appModel.openedBillboardNodeIDs.removeAll()
                        break
                    }
                    appModel.openedBillboardNodeIDs.remove(id)
                }
            }

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

            // 3) Предгенерация билбордов каждые 10 метров вдоль полной полилинии
            if let origin = appModel.routeOriginLonLat {
                appModel.generatedBillboards = generateBillboardsEvery(
                    spacingMeters: 10.0,
                    origin: origin,
                    polyline: full
                )
                // Обновим прогресс пользователя по новому маршруту, если знаем позицию
                if let u = appModel.userLonLat {
                    appModel.userAlongMeters = projectAlongMeters(
                        lon: u.lon, lat: u.lat, origin: origin, polyline: full
                    )
                } else {
                    appModel.userAlongMeters = 0
                }
            } else {
                appModel.generatedBillboards = []
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
                    if !appModel.userTurnHint.isEmpty {
                        Text(appModel.userTurnHint)
                            .font(.callout)
                    }
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

// MARK: - Navigation Demo

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
                    Label("Найти адресс", systemImage: "house")
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

// MARK: - Route Overlay (Canvas)

struct RouteOverlayPanel: View {
    let origin: (lon: Double, lat: Double)?
    let polyline: RoutePolyline
    let nodes: [ManeuverNode]
    let generated: [GeneratedBillboard]
    let user: (lon: Double, lat: Double)?
    let userAlong: Double
    @Environment(AppModel.self) private var appModel

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

                // 5) Все сгенерированные билборды (светло-оранжевые точки)
                for b in generated {
                    let p2 = Geo.geoToMeters(lon: b.lon, lat: b.lat,
                                             originLon: origin.lon, originLat: origin.lat)
                    let p = mapPoint(p2)
                    let r: CGFloat = 2
                    let rect = CGRect(x: p.x - r, y: p.y - r, width: r*2, height: r*2)
                    ctx.fill(Path(ellipseIn: rect), with: .color(.orange.opacity(0.6)))
                }

                // 6) Ближайшие 3 впереди — выделим ярче и подпишем дистанцию
                let ahead = generated.filter { $0.alongMeters + 0.1 >= userAlong }.prefix(3)
                for b in ahead {
                    let p2 = Geo.geoToMeters(lon: b.lon, lat: b.lat,
                                             originLon: origin.lon, originLat: origin.lat)
                    let p = mapPoint(p2)
                    let r: CGFloat = 4
                    let rect = CGRect(x: p.x - r, y: p.y - r, width: r*2, height: r*2)
                    ctx.fill(Path(ellipseIn: rect), with: .color(.orange))
                    let left = max(0, Int((b.alongMeters - userAlong).rounded()))
                    ctx.draw(Text("\(left)m").font(.system(size: 9)).foregroundStyle(.orange), at: CGPoint(x: p.x, y: p.y - 10))
                }

                // 7) Позиция пользователя
                if let user {
                    let pu2 = Geo.geoToMeters(lon: user.lon, lat: user.lat, originLon: origin.lon, originLat: origin.lat)
                    let pu = mapPoint(pu2)
                    let r: CGFloat = 5
                    let rect = CGRect(x: pu.x - r, y: pu.y - r, width: r*2, height: r*2)
                    ctx.stroke(Path(ellipseIn: rect), with: .color(.yellow), lineWidth: 2)
                    let coordLabel = String(format: "%.5f, %.5f", user.lat, user.lon)
                    ctx.draw(Text(coordLabel).font(.system(size: 9)).foregroundStyle(.yellow), at: CGPoint(x: pu.x, y: pu.y + 12))
                    if !appModel.userTurnHint.isEmpty {
                        ctx.draw(Text(appModel.userTurnHint).font(.system(size: 11).bold()), at: CGPoint(x: pu.x, y: pu.y - 18))
                    }
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

// MARK: - Генерация билбордов каждые N метров

private func generateBillboardsEvery(spacingMeters: Double,
                                     origin: (lon: Double, lat: Double),
                                     polyline: RoutePolyline) -> [GeneratedBillboard] {
    guard polyline.points.count >= 2 else { return [] }

    let meters: [SIMD2<Double>] = polyline.points.map {
        Geo.geoToMeters(lon: $0.lon, lat: $0.lat, originLon: origin.lon, originLat: origin.lat)
    }

    // сегменты и накопленные длины
    var cum: [Double] = [0]
    for i in 1..<meters.count {
        let dl = distance(meters[i], meters[i-1])
        cum.append(cum.last! + dl)
    }
    let total = cum.last ?? 0
    guard total > 0 else { return [] }

    func point(atAlong d: Double) -> SIMD2<Double> {
        if d <= 0 { return meters.first! }
        if d >= total { return meters.last! }
        // бинарный поиск сегмента
        var lo = 0, hi = cum.count - 1
        while lo < hi {
            let mid = (lo + hi) / 2
            if cum[mid] < d { lo = mid + 1 } else { hi = mid }
        }
        let i = max(1, lo)
        let segStart = meters[i-1]
        let segEnd = meters[i]
        let segLen = max(distance(segEnd, segStart), 1e-6)
        let t = (d - cum[i-1]) / segLen
        return mix(segStart, segEnd, t)
    }

    var out: [GeneratedBillboard] = []
    var d = 0.0
    while d <= total {
        let p = point(atAlong: d)
        let geo = Geo.metersToGeo(dx: p.x, dz: p.y, originLon: origin.lon, originLat: origin.lat)
        out.append(GeneratedBillboard(lon: geo.lon, lat: geo.lat, alongMeters: d))
        d += spacingMeters
    }
    return out
}

// MARK: - Вспомогательные векторы

@inline(__always) private func distance(_ a: SIMD2<Double>, _ b: SIMD2<Double>) -> Double {
    let dx = a.x - b.x, dy = a.y - b.y
    return (dx*dx + dy*dy).squareRoot()
}

@inline(__always) private func mix(_ a: SIMD2<Double>, _ b: SIMD2<Double>, _ t: Double) -> SIMD2<Double> {
    return .init(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t)
}

// MARK: - Проекция текущей позиции на полилинию → прогресс (метры)

private func projectAlongMeters(lon: Double,
                                lat: Double,
                                origin: (lon: Double, lat: Double),
                                polyline: RoutePolyline) -> Double {
    let pts = polyline.points
    guard pts.count >= 2 else { return 0 }
    let meters: [SIMD2<Double>] = pts.map {
        Geo.geoToMeters(lon: $0.lon, lat: $0.lat, originLon: origin.lon, originLat: origin.lat)
    }
    var cum: [Double] = [0]
    for i in 1..<meters.count { cum.append(cum.last! + distance(meters[i], meters[i-1])) }
    let p = Geo.geoToMeters(lon: lon, lat: lat, originLon: origin.lon, originLat: origin.lat)

    var bestDist = Double.greatestFiniteMagnitude
    var bestAlong = 0.0
    for i in 1..<meters.count {
        let a = meters[i-1], b = meters[i]
        let ab = b &- a
        let ap = p &- a
        let abLen2 = max(ab.x*ab.x + ab.y*ab.y, 1e-12)
        var t = (ap.x*ab.x + ap.y*ab.y) / abLen2
        t = max(0, min(1, t))
        let proj = a &+ (b &- a) * t
        let d2 = (proj.x - p.x)*(proj.x - p.x) + (proj.y - p.y)*(proj.y - p.y)
        if d2 < bestDist {
            bestDist = d2
            let segLen = distance(b, a)
            bestAlong = cum[i-1] + segLen * t
        }
    }
    return bestAlong
}

private extension SIMD2 where Scalar == Double {
    static func &- (lhs: SIMD2<Double>, rhs: SIMD2<Double>) -> SIMD2<Double> { .init(lhs.x - rhs.x, lhs.y - rhs.y) }
    static func &+ (lhs: SIMD2<Double>, rhs: SIMD2<Double>) -> SIMD2<Double> { .init(lhs.x + rhs.x, lhs.y + rhs.y) }
    static func * (lhs: SIMD2<Double>, rhs: Double) -> SIMD2<Double> { .init(lhs.x * rhs, lhs.y * rhs) }
}

// MARK: - Подсказка поворота пользователя

private func computeTurnHint(
    prev: (lon: Double, lat: Double),
    curr: (lon: Double, lat: Double),
    origin: (lon: Double, lat: Double),
    polyline: RoutePolyline,
    along: Double
) -> String {
    // Вектор движения пользователя
    let p0 = Geo.geoToMeters(lon: prev.lon, lat: prev.lat, originLon: origin.lon, originLat: origin.lat)
    let p1 = Geo.geoToMeters(lon: curr.lon, lat: curr.lat, originLon: origin.lon, originLat: origin.lat)
    var vu = p1 &- p0
    let vuLen = max(1e-6, distance(p1, p0))
    vu = .init(vu.x / vuLen, vu.y / vuLen)

    // Тангенс маршрута в точке проекции
    let vr = routeTangentAtAlong(origin: origin, polyline: polyline, along: along)
    let dotv = max(-1.0, min(1.0, vu.x*vr.x + vu.y*vr.y))
    let angleRad = acos(dotv)
    let angleDeg = angleRad * 180.0 / .pi
    let crossZ = vu.x*vr.y - vu.y*vr.x // >0 — поворот влево, <0 — вправо

    // Градации
    if angleDeg < 10 {
        return "⬆️ идите прямо"
    } else if angleDeg < 45 {
        return crossZ >= 0 ? "↖️ слегка поверните налево" : "↗️ слегка поверните направо"
    } else if angleDeg <= 90 {
        return crossZ >= 0 ? "↩️ поверните налево" : "↪️ поверните направо"
    } else {
        // если угол > 90°, вероятно идём в обратную сторону — дадим сильную подсказку
        return crossZ >= 0 ? "⬅️ развернитесь налево" : "➡️ развернитесь направо"
    }
}

private func routeTangentAtAlong(origin: (lon: Double, lat: Double), polyline: RoutePolyline, along: Double) -> SIMD2<Double> {
    let meters: [SIMD2<Double>] = polyline.points.map {
        Geo.geoToMeters(lon: $0.lon, lat: $0.lat, originLon: origin.lon, originLat: origin.lat)
    }
    guard meters.count >= 2 else { return .init(0, 1) }
    var cum: [Double] = [0]
    for i in 1..<meters.count { cum.append(cum.last! + distance(meters[i], meters[i-1])) }
    let total = cum.last ?? 0
    let d = min(max(0, along), total)
    // бинарный поиск сегмента
    var lo = 0, hi = cum.count - 1
    while lo < hi {
        let mid = (lo + hi) / 2
        if cum[mid] < d { lo = mid + 1 } else { hi = mid }
    }
    let i = max(1, lo)
    let a = meters[i-1], b = meters[i]
    var v = b &- a
    let len = max(1e-6, distance(b, a))
    v = .init(v.x / len, v.y / len)
    return v
}
