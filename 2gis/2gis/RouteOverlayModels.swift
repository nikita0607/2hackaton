import Foundation
import simd

// Узел манёвра для окон-билбордов
public struct ManeuverNode: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let lon: Double
    public let lat: Double
    public let title: String
    public let detail: String?

    public init(id: UUID = UUID(), lon: Double, lat: Double, title: String, detail: String?) {
        self.id = id
        self.lon = lon
        self.lat = lat
        self.title = title
        self.detail = detail
    }
}

// Номинальный тип точки вместо неименованного кортежа
public struct GeoPoint: Codable, Hashable, Sendable {
    public let lon: Double
    public let lat: Double
    public init(lon: Double, lat: Double) {
        self.lon = lon
        self.lat = lat
    }
}

// Полилиния маршрута (теперь на GeoPoint, а не на tuple)
public struct RoutePolyline: Codable, Hashable, Sendable, Equatable {
    public var points: [GeoPoint]
    public init(points: [GeoPoint]) {
        self.points = points
    }
}

// Полезные утилиты
public enum Geo {
    public static let metersPerDeg: Double = 111_320.0
    public static func geoToMeters(lon: Double, lat: Double, originLon: Double, originLat: Double) -> SIMD2<Double> {
        let dx = (lon - originLon) * cos(originLat * .pi / 180.0) * metersPerDeg
        let dz = (lat - originLat) * metersPerDeg
        return .init(dx, dz)
    }

    public static func metersToGeo(dx: Double, dz: Double, originLon: Double, originLat: Double) -> (lon: Double, lat: Double) {
        let dLon = dx / (cos(originLat * .pi / 180.0) * metersPerDeg)
        let dLat = dz / metersPerDeg
        return (originLon + dLon, originLat + dLat)
    }
}

public enum WKT {
    // LINESTRING(lon lat, lon lat, ...)
    public static func parseLineString(_ wkt: String) -> [(lon: Double, lat: Double)] {
        let up = wkt.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard up.hasPrefix("LINESTRING"),
              let l = wkt.firstIndex(of: "("),
              let r = wkt.lastIndex(of: ")"),
              l < r
        else { return [] }
        let inner = wkt[wkt.index(after: l)..<r]
        return inner.split(separator: ",").compactMap { pair in
            let comps = pair.trimmingCharacters(in: .whitespaces).split(separator: " ")
            guard comps.count >= 2, let lon = Double(comps[0]), let lat = Double(comps[1]) else { return nil }
            return (lon, lat)
        }
    }
}

// Сэмплы вдоль маршрута с привязкой к длине (в метрах)
public struct GeneratedBillboard: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let lon: Double
    public let lat: Double
    public let alongMeters: Double

    public init(id: UUID = UUID(), lon: Double, lat: Double, alongMeters: Double) {
        self.id = id
        self.lon = lon
        self.lat = lat
        self.alongMeters = alongMeters
    }
}
