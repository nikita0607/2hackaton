import Foundation
import Observation

@MainActor
@Observable
class NavigationViewModel {
    private let client: NavigationAPIClient

    var isLoading: Bool = false
    var lastRouteResponse: RouteResponse?
    var lastMapMatchResponse: MapMatchResponse?
    var lastGeolocationResponse: GeolocationResponse?
    var errorMessage: String?

    init(client: NavigationAPIClient = NavigationAPIClient(apiKey: "6fe4cc7a-89b8-4aec-a5c3-ac94224044fe")) {
        self.client = client
    }

    func loadSampleRoute(locationService: LocationService, destinationPoint: RoutePoint) async {
        await execute {
            let currentLocation = locationService.currentLocation;
            
            
            if (currentLocation == nil) {
                debugPrint("Use mock instead")
            }
            
            let request = RouteRequest(
                points: [
                    RoutePoint(lon: currentLocation?.coordinate.longitude ?? 104.798401, lat: currentLocation?.coordinate.latitude ?? 51.877124, type: .stop),
                    destinationPoint
                ],
                transport: "walking",
                output: .detailed,
                locale: "ru"
            )
            lastRouteResponse = try await client.buildRoute(request)
        }
    }

    func loadSampleMapMatch() async {
        await execute {
            let baseTimestamp = Int(Date().timeIntervalSince1970) - 120
            let request = MapMatchRequest(
                query: [
                    RecordedPoint(lon: 37.582591, lat: 55.775364, utc: baseTimestamp, speed: 5.0, azimuth: 95),
                    RecordedPoint(lon: 37.610000, lat: 55.772300, utc: baseTimestamp + 30, speed: 6.2, azimuth: 110),
                    RecordedPoint(lon: 37.633200, lat: 55.769500, utc: baseTimestamp + 60, speed: 6.8, azimuth: 115),
                    RecordedPoint(lon: 37.656625, lat: 55.765036, utc: baseTimestamp + 90, speed: 5.4, azimuth: 118)
                ]
            )
            lastMapMatchResponse = try await client.mapMatch(request)
        }
    }

    func loadSampleGeolocation() async {
        await execute {
            let request = GeolocationRequest(
                sessionUUID: UUID().uuidString,
                captureTimestampUnix: Int(Date().timeIntervalSince1970),
                gnssLocation: .init(latitude: 55.770200, longitude: 37.620500, horizontalAccuracyM: 50),
                mobileNetwork: .init(
                    homeMobileCountryCode: 250,
                    homeMobileNetworkCode: 99,
                    cellTowers: [
                        .init(cellID: 42012345, networkType: "lte", locationAreaCode: 41001, signalStrengthDBm: -65, ageMs: 500)
                    ]
                ),
                wifiAccessPoints: [
                    .init(macAddress: "00:11:22:33:44:55", signalStrengthDBm: -45, ageMs: 300),
                    .init(macAddress: "66:77:88:99:AA:BB", signalStrengthDBm: -60, ageMs: 200)
                ]
            )
            lastGeolocationResponse = try await client.geolocate(request)
        }
    }

    private func execute(_ operation: @Sendable @MainActor () async throws -> Void) async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        do {
            try await operation()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Extract maneuver nodes and full polyline
    func extractManeuverNodes(from response: RouteResponse) -> [ManeuverNode] {
        guard let route = response.result?.first, let mans = route.maneuvers else { return [] }
        return mans.compactMap { m in
            guard let sel = m.outcomingPath?.geometry?.first?.selection else { return nil }
            guard let first = WKT.parseLineString(sel).first else { return nil }
            let icon = (m.icon ?? "")
            let title: String = (icon == "turn_right") ? "↱" :
                                (icon == "turn_left")  ? "↰" :
                                (icon == "finish")     ? "●" :
                                (icon == "start")      ? "◎" : "⬆︎"
            return ManeuverNode(lon: first.lon, lat: first.lat, title: title, detail: m.outcomingPathComment ?? m.comment)
        }
    }

    func extractFullPolyline(from response: RouteResponse) -> RoutePolyline {
        guard let route = response.result?.first, let mans = route.maneuvers else {
            return .init(points: [])
        }
        var all: [GeoPoint] = []
    
        for m in mans {
            if let sel = m.outcomingPath?.geometry?.first?.selection {
                let pts = WKT.parseLineString(sel) // [(lon, lat)]
                guard !pts.isEmpty else { continue }
                // Склеиваем, избегая дубля первой вершины
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

}
