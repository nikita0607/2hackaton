import Foundation
import CoreLocation
import Observation

@MainActor
@Observable
final class LocationService: NSObject {
    enum Status {
        case idle, requesting, authorized, denied, restricted
    }

    private let manager = CLLocationManager()

    // Публичные данные
    var status: Status = .idle
    var currentLocation: CLLocation?
    var lastMeterSnapLocation: CLLocation?

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
            status = .requesting
            manager.requestWhenInUseAuthorization()
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
        if case .authorized = status {
            manager.startUpdatingLocation()
        }
    }

    func stop() {
        manager.stopUpdatingLocation()
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
