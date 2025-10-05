import Foundation
import CoreLocation

// MARK: - Navigation API Client

/// Lightweight client for 2GIS navigation-related APIs (Routing, Map Matching, Radar).
struct NavigationAPIClient {

    // MARK: Configuration

    struct Configuration: Sendable {
        let routingBaseURL: URL
        let radarBaseURL: URL

        static let production = Configuration(
            routingBaseURL: URL(string: "https://routing.api.2gis.com")!,
            radarBaseURL: URL(string: "https://radar.api.2gis.com")!
        )
    }

    // MARK: Errors

    enum APIError: LocalizedError {
        case invalidURL
        case httpError(statusCode: Int, body: Data)
        case decoding(DecodingError)          // конкретно DecodingError (чтобы видеть, что именно не так)
        case decodingOther(Error)             // на случай другой ошибки при decode()

        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Не удалось собрать URL для запроса."
            case let .httpError(statusCode, _):
                return "Сервер вернул статус-код \(statusCode)."
            case let .decoding(err):
                return "Ошибка декодирования ответа: \(err)"
            case let .decodingOther(err):
                return "Ошибка при обработке ответа: \(err.localizedDescription)"
            }
        }
    }

    // MARK: Core

    private let apiKey: String
    private let session: URLSession
    private let configuration: Configuration
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        apiKey: String,
        session: URLSession = .shared,
        configuration: Configuration = .production
    ) {
        self.apiKey = apiKey
        self.session = session
        self.configuration = configuration

        let enc = JSONEncoder()
        enc.keyEncodingStrategy = .convertToSnakeCase
        enc.dateEncodingStrategy = .secondsSince1970
        self.encoder = enc

        let dec = JSONDecoder()
        dec.keyDecodingStrategy = .convertFromSnakeCase
        dec.dateDecodingStrategy = .secondsSince1970
        self.decoder = dec
    }
}

// MARK: - Public API

extension NavigationAPIClient {

    /// POST /routing/7.0.0/global?key=...
    func buildRoute(_ request: RouteRequest) async throws -> RouteResponse {
        let url = try url(base: configuration.routingBaseURL, pathComponents: ["routing", "7.0.0", "global"], key: apiKey)
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.httpBody = try encoder.encode(request)
        return try await send(req, decode: RouteResponse.self)
    }

    /// POST /map_matching/1.0.0?key=...
    func mapMatch(_ request: MapMatchRequest) async throws -> MapMatchResponse {
        let url = try url(base: configuration.routingBaseURL, pathComponents: ["map_matching", "1.0.0"], key: apiKey)
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.httpBody = try encoder.encode(request)
        return try await send(req, decode: MapMatchResponse.self)
    }

    /// POST /v2/geolocation?key=...
    func geolocate(_ request: GeolocationRequest) async throws -> GeolocationResponse {
        let url = try url(base: configuration.radarBaseURL, pathComponents: ["v2", "geolocation"], key: apiKey)
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.httpBody = try encoder.encode(request)
        return try await send(req, decode: GeolocationResponse.self)
    }
}

// MARK: - Request helpers

private extension NavigationAPIClient {

    /// Собирает URL из базового домена + path components, добавляет `key` как query item.
    func url(base: URL, pathComponents: [String], key: String) throws -> URL {
        var url = base
        for p in pathComponents {
            url.appendPathComponent(p)
        }
        guard var comps = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw APIError.invalidURL
        }
        var q: [URLQueryItem] = comps.queryItems ?? []
        q.append(URLQueryItem(name: "key", value: key))
        comps.queryItems = q
        guard let final = comps.url else { throw APIError.invalidURL }
        return final
    }

    func send<Response: Decodable>(_ request: URLRequest, decode type: Response.Type) async throws -> Response {
        #if DEBUG
        debugPrint("➡️ \(request.httpMethod ?? "GET") \(request.url?.absoluteString ?? "")")
        if let body = request.httpBody, let s = String(data: body, encoding: .utf8) {
            debugPrint("➡️ Body:\n\(s)")
        }
        #endif

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidURL
        }

        #if DEBUG
        debugPrint("⬅️ Status: \(http.statusCode)")
        if let s = String(data: data, encoding: .utf8) {
            debugPrint("⬅️ Raw JSON (\(data.count) bytes):\n\(s)")
        }
        #endif

        guard (200..<300).contains(http.statusCode) else {
            throw APIError.httpError(statusCode: http.statusCode, body: data)
        }

        do {
            return try decoder.decode(Response.self, from: data)
        } catch let decErr as DecodingError {
            throw APIError.decoding(decErr)
        } catch {
            throw APIError.decodingOther(error)
        }
    }
}

// MARK: - Routing models

struct RouteRequest: Encodable {
    enum Output: String, Codable { case summary, detailed }

    var points: [RoutePoint]
    var transport: String?           // "driving", "walking", "bicycle", "scooter", "motorcycle", "truck", "taxi"
    var filters: [String]?           // e.g. ["dirt_road","toll_road","ferry"]
    var output: Output?              // summary | detailed (default detailed)
    var locale: String?              // "en", "ru", ...
    var avoid: [String]?             // area/road types to avoid

    init(
        points: [RoutePoint],
        transport: String? = nil,
        filters: [String]? = nil,
        output: Output? = .detailed,
        locale: String? = nil,
        avoid: [String]? = nil
    ) {
        self.points = points
        self.transport = transport
        self.filters = filters
        self.output = output
        self.locale = locale
        self.avoid = avoid
    }
}

struct RoutePoint: Codable {
    enum PointType: String, Codable { case walking, stop, pref }
    var lon: Double
    var lat: Double
    var type: PointType
    var start: Bool?

    init(lon: Double, lat: Double, type: PointType, start: Bool? = nil) {
        self.lon = lon
        self.lat = lat
        self.type = type
        self.start = start
    }
}

struct RouteResponse: Decodable {
    let message: String?
    let query: [String: JSONValue]?   // сервер может эхо-возвращать запрос
    let result: [RouteResult]?        // делаем optional: иногда сервис возвращает только message
}

struct RouteResult: Decodable {
    let algorithm: String?
    let id: String?
    let maneuvers: [Maneuver]?
    let filterRoadTypes: [String]?
}

struct Maneuver: Decodable {
    let id: String?
    let comment: String?
    let icon: String?
    let outcomingPath: Segment?
    let outcomingPathComment: String?

    struct Segment: Decodable {
        let distance: Double?
        let duration: Double?
        let geometry: [SegmentGeometry]?
    }
}

struct SegmentGeometry: Decodable, Identifiable {
    let id = UUID()
    let color: String?
    let length: Double?
    let selection: String?   // WKT LINESTRING
    let style: String?

    private enum CodingKeys: String, CodingKey { case color, length, selection, style }
}

// MARK: - Map matching models

struct MapMatchRequest: Encodable {
    var query: [RecordedPoint]

    init(query: [RecordedPoint]) {
        self.query = query
    }
}

struct RecordedPoint: Codable {
    var lon: Double
    var lat: Double
    var utc: Int
    var speed: Double?
    var azimuth: Double?

    init(lon: Double, lat: Double, utc: Int, speed: Double? = nil, azimuth: Double? = nil) {
        self.lon = lon
        self.lat = lat
        self.utc = utc
        self.speed = speed
        self.azimuth = azimuth
    }
}

struct MapMatchResponse: Decodable {
    let distance: Double?
    let duration: Double?
    let edges: [MatchedEdge]?
    let query: [MatchedQueryPoint]?
    let route: String?
    let status: String?
}

struct MatchedEdge: Decodable, Identifiable {
    let edgeId: Int
    let distance: Double?
    let geometry: String?

    var id: Int { edgeId }
}

struct MatchedQueryPoint: Decodable, Identifiable {
    let utc: Int
    let lon: Double?
    let lat: Double?
    let lonMatched: Double?
    let latMatched: Double?
    let edgeId: Int?
    let speed: Double?
    let azimuth: Double?

    var id: Int { utc }
}

// MARK: - Radar geolocation models

struct GeolocationRequest: Encodable {
    var sessionUUID: String
    var captureTimestampUnix: Int
    var gnssLocation: GnssLocation?
    var mobileNetwork: MobileNetwork?
    var wifiAccessPoints: [WifiAccessPoint]?

    struct GnssLocation: Codable {
        var latitude: Double
        var longitude: Double
        var horizontalAccuracyM: Double?
    }

    struct MobileNetwork: Codable {
        var homeMobileCountryCode: Int
        var homeMobileNetworkCode: Int
        var cellTowers: [CellTower]
    }

    struct CellTower: Codable {
        var cellID: Int
        var networkType: String
        var locationAreaCode: Int
        var signalStrengthDBm: Int?
        var ageMs: Int?
    }

    struct WifiAccessPoint: Codable {
        var macAddress: String
        var signalStrengthDBm: Int?
        var ageMs: Int?
    }
}

struct GeolocationResponse: Decodable {
    let statusCode: Int?
    let state: String?
    let location: Location?

    struct Location: Decodable {
        let longitude: Double?
        let latitude: Double?
        let accuracy: Double?
    }
}

// MARK: - JSONValue (для произвольных кусочков JSON)

/// Универсальный JSON узел (null/bool/number/string/array/object)
enum JSONValue: Decodable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { self = .null; return }
        if let b = try? container.decode(Bool.self) { self = .bool(b); return }
        if let d = try? container.decode(Double.self) { self = .number(d); return }
        if let s = try? container.decode(String.self) { self = .string(s); return }
        if let arr = try? container.decode([JSONValue].self) { self = .array(arr); return }
        if let obj = try? container.decode([String: JSONValue].self) { self = .object(obj); return }
        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON type")
    }
}
