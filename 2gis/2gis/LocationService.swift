import Foundation
import CoreLocation
import Observation

@MainActor
@Observable
final class LocationService: NSObject {
    enum Status {
        case idle, requesting, authorized, denied, restricted
    }

    enum Mode {
        case real
        case mockGPX
    }

    private let manager = CLLocationManager()

    // Публичные данные
    var status: Status = .idle
    var currentLocation: CLLocation?
    var lastMeterSnapLocation: CLLocation?
    var mode: Mode = .real
    private var playbackTask: Task<Void, Never>?
    private var gpxWaypoints: [GPXWaypoint] = []

    // Настройки
    var distanceThresholdMeters: CLLocationDistance = 1.0   // «каждый метр»
    var desiredAccuracy: CLLocationAccuracy = kCLLocationAccuracyBest

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = desiredAccuracy
        manager.distanceFilter = kCLDistanceFilterNone // пусть отдаёт максимально часто, фильтруем сами
        manager.activityType = .fitness                // пешеходный кейс; можно .otherNavigation
        manager.pausesLocationUpdatesAutomatically = true
    }

    func requestAuthorizationIfNeeded() {
        switch manager.authorizationStatus {
        case .notDetermined:
            if mode == .real {
                status = .requesting
                manager.requestWhenInUseAuthorization()
            } else {
                // В мок-режиме считаем, что «разрешено» и не трогаем системные диалоги
                status = .authorized
            }
        case .authorizedAlways, .authorizedWhenInUse:
            status = .authorized
        case .denied:
            status = .denied
        case .restricted:
            status = .restricted
        @unknown default:
            status = .restricted
        }
    }

    func start() {
        requestAuthorizationIfNeeded()
        switch mode {
        case .real:
            if case .authorized = status { manager.startUpdatingLocation() }
        case .mockGPX:
            // Запускаем воспроизведение GPX
            startMockPlayback()
        }
    }

    func stop() {
        manager.stopUpdatingLocation()
        playbackTask?.cancel()
        playbackTask = nil
    }

    /// Возвращает true, если от последней «защёлкнутой» точки пройдено >= threshold
    @discardableResult
    func checkAndSnapIfNeeded(threshold: CLLocationDistance? = nil) -> Bool {
        guard let loc = currentLocation else { return false }
        let thr = threshold ?? distanceThresholdMeters
        if let last = lastMeterSnapLocation {
            if loc.distance(from: last) >= thr {
                lastMeterSnapLocation = loc
                return true
            }
            return false
        } else {
            lastMeterSnapLocation = loc
            return true
        }
    }
}

extension LocationService: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            switch manager.authorizationStatus {
            case .authorizedAlways, .authorizedWhenInUse:
                status = .authorized
                self.manager.startUpdatingLocation()
            case .denied:
                status = .denied
            case .restricted:
                status = .restricted
            case .notDetermined:
                status = .requesting
            @unknown default:
                status = .restricted
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last else { return }
        Task { @MainActor in
            currentLocation = latest
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Можно логировать/показывать пользователю
        // print("Location error:", error.localizedDescription)
    }
}

// MARK: - GPX Mock Playback

extension LocationService {
    struct GPXWaypoint {
        let lat: Double
        let lon: Double
        let time: Date?
    }

    func enableMockFromBundledGPX(named name: String = "xcode_route_2mps") {
        // Пытаемся найти ресурс в бандле
        var url: URL?
        if let direct = Bundle.main.url(forResource: name, withExtension: "gpx") {
            url = direct
        } else if let urls = Bundle.main.urls(forResourcesWithExtension: "gpx", subdirectory: nil) {
            url = urls.first { $0.lastPathComponent.contains(name) }
        }

        if let url { self.loadGPX(url: url) }
        self.mode = .mockGPX
    }

    private func loadGPX(url: URL) {
        do {
            let data = try Data(contentsOf: url)
            self.gpxWaypoints = try GPXParser.parse(data: data)
        } catch {
            print("GPX load error:", error)
            self.gpxWaypoints = []
        }
    }

    private func startMockPlayback() {
        // Если точки ещё не загружены — попробуем найти дефолтный GPX
        if gpxWaypoints.isEmpty {
            enableMockFromBundledGPX()
        }
        guard !gpxWaypoints.isEmpty else { return }

        status = .authorized
        let waypoints = gpxWaypoints
        let formatter = ISO8601DateFormatter()

        playbackTask?.cancel()
        playbackTask = Task { [weak self] in
            guard let self else { return }

            // Отнормируем по времени: воспроизводим с реальными дельтами
            let times: [TimeInterval?] = waypoints.map { $0.time?.timeIntervalSince1970 }
            let t0 = times.compactMap { $0 }.min() ?? Date().timeIntervalSince1970

            var prevLoc: CLLocation?
            var prevDelay: TimeInterval = 0

            for (idx, w) in waypoints.enumerated() {
                if Task.isCancelled { break }
                let targetTime = (times[idx] ?? (t0 + prevDelay + 1))
                // Отсчитываем от минимального времени t0 (first может быть nil и даёт двойной optional)
                let delay = max(0, targetTime - t0) - prevDelay
                prevDelay += delay
                if delay > 0 { try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000)) }

                // Рассчитываем скорость и курс
                var speed: CLLocationSpeed = 0
                var course: CLLocationDirection = -1
                let nowCoord = CLLocationCoordinate2D(latitude: w.lat, longitude: w.lon)
                let nowLoc = CLLocation(latitude: w.lat, longitude: w.lon)
                if let prev = prevLoc, let prevT = times[max(0, idx-1)], let curT = times[idx] {
                    let dt = max(0.1, curT - prevT)
                    let dist = nowLoc.distance(from: prev)
                    speed = dist / dt
                    course = bearing(from: prev.coordinate, to: nowCoord)
                }

                await MainActor.run {
                    let mocked = CLLocation(coordinate: nowCoord,
                                            altitude: 0,
                                            horizontalAccuracy: 5,
                                            verticalAccuracy: 10,
                                            course: course,
                                            speed: speed,
                                            timestamp: Date())
                    self.currentLocation = mocked
                }
                prevLoc = nowLoc
            }
        }
    }

    private func bearing(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> CLLocationDirection {
        let φ1 = from.latitude * .pi/180
        let φ2 = to.latitude * .pi/180
        let Δλ = (to.longitude - from.longitude) * .pi/180
        let y = sin(Δλ) * cos(φ2)
        let x = cos(φ1)*sin(φ2) - sin(φ1)*cos(φ2)*cos(Δλ)
        var θ = atan2(y, x) * 180 / .pi
        if θ < 0 { θ += 360 }
        return θ
    }
}

// MARK: - Simple GPX parser (wpt/trkpt with time)

private enum GPXParser {
    static func parse(data: Data) throws -> [LocationService.GPXWaypoint] {
        let delegate = _GPXDelegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        if parser.parse() {
            return delegate.points
        } else {
            throw parser.parserError ?? NSError(domain: "GPXParser", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unknown GPX parse error"])
        }
    }

    private final class _GPXDelegate: NSObject, XMLParserDelegate {
        var points: [LocationService.GPXWaypoint] = []
        private var curLat: Double?
        private var curLon: Double?
        private var curTimeString: String = ""
        private var inWpt = false
        private var inTrkpt = false
        private let iso = ISO8601DateFormatter()

        func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
            if elementName == "wpt" || elementName == "trkpt" {
                inWpt = elementName == "wpt"
                inTrkpt = elementName == "trkpt"
                curLat = Double(attributeDict["lat"] ?? "")
                curLon = Double(attributeDict["lon"] ?? "")
                curTimeString = ""
            }
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            curTimeString += string
        }

        func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
            if elementName == "time" {
                // handled on close of wpt/trkpt
            }
            if elementName == "wpt" || elementName == "trkpt" {
                if let lat = curLat, let lon = curLon {
                    let t = iso.date(from: curTimeString.trimmingCharacters(in: .whitespacesAndNewlines))
                    points.append(.init(lat: lat, lon: lon, time: t))
                }
                inWpt = false
                inTrkpt = false
                curLat = nil
                curLon = nil
                curTimeString = ""
            }
        }
    }
}
