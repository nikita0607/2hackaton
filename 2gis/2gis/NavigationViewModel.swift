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

    // Постоянная проверка позиции (map matching)
    private var positionMonitorTask: Task<Void, Never>?
    private var recordedPoints: [RecordedPoint] = []
    private var lastMapMatchSentAt: Date?
    private let minMapMatchInterval: TimeInterval = 2.0
    private let maxRecordedPoints: Int = 30

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

    func startContinuousPositionCheck(locationService: LocationService) {
        // перезапуск, если уже был запущен
        positionMonitorTask?.cancel()
        positionMonitorTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                await self.captureAndSendIfNeeded(locationService: locationService)
                try? await Task.sleep(nanoseconds: 1_000_000_000) // ~1 сек
            }
        }
    }

    func stopContinuousPositionCheck() {
        positionMonitorTask?.cancel()
        positionMonitorTask = nil
    }

    private func captureAndSendIfNeeded(locationService: LocationService) async {
        guard let loc = locationService.currentLocation else { return }
        let now = Int(Date().timeIntervalSince1970)
        let point = RecordedPoint(
            lon: loc.coordinate.longitude,
            lat: loc.coordinate.latitude,
            utc: now,
            speed: max(loc.speed, 0),
            azimuth: loc.course >= 0 ? loc.course : nil
        )

        // добавим и ограничим буфер
        recordedPoints.append(point)
        if recordedPoints.count > maxRecordedPoints { recordedPoints.removeFirst(recordedPoints.count - maxRecordedPoints) }

        // Троттлинг запросов map match
        let shouldSend: Bool = {
            if recordedPoints.count < 2 { return false }
            if let lastAt = lastMapMatchSentAt, Date().timeIntervalSince(lastAt) < minMapMatchInterval { return false }
            return true
        }()
        guard shouldSend else { return }

        let req = MapMatchRequest(query: recordedPoints)
        do {
            let resp = try await client.mapMatch(req)
            // обновим на главном потоке
            await MainActor.run {
                self.lastMapMatchResponse = resp
                self.lastMapMatchSentAt = Date()
            }
        } catch {
            await MainActor.run {
                self.errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
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

}
