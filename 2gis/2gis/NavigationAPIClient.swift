import Foundation

/// Lightweight client for the 2GIS navigation-related APIs described in `openapi_navigation`.
struct NavigationAPIClient {
    struct Configuration: Sendable {
        let routingBaseURL: URL
        let radarBaseURL: URL

        static let production = Configuration(
            routingBaseURL: URL(string: "https://routing.api.2gis.com")!,
            radarBaseURL: URL(string: "https://radar.api.2gis.com")!
        )
    }

    enum APIError: LocalizedError {
        case invalidURL
        case httpError(statusCode: Int, body: Data)
        case decoding(Error)

        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Не удалось собрать URL для запроса."
            case let .httpError(statusCode, _):
                return "Сервер вернул статус-код \(statusCode)."
            case let .decoding(error):
                return "Ошибка декодирования ответа: \(error.localizedDescription)"
            }
        }
    }

    private let apiKey: String
    private let session: URLSession
    private let configuration: Configuration
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(apiKey: String, session: URLSession = .shared, configuration: Configuration = .production) {
        self.apiKey = apiKey
        self.session = session
        self.configuration = configuration

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        self.decoder = decoder
    }
}

// MARK: - Public API

extension NavigationAPIClient {
    func buildRoute(_ request: RouteRequest) async throws -> RouteResponse {
        let request = try makePOSTRequest(
            baseURL: configuration.routingBaseURL,
            path: "routing/7.0.0/global",
            body: request
        )
        return try await send(request, decode: RouteResponse.self)
    }

    func mapMatch(_ request: MapMatchRequest) async throws -> MapMatchResponse {
        let request = try makePOSTRequest(
            baseURL: configuration.routingBaseURL,
            path: "map_matching/1.0.0",
            body: request
        )
        return try await send(request, decode: MapMatchResponse.self)
    }

    func geolocate(_ request: GeolocationRequest) async throws -> GeolocationResponse {
        let request = try makePOSTRequest(
            baseURL: configuration.radarBaseURL,
            path: "v2/geolocation",
            body: request
        )
        return try await send(request, decode: GeolocationResponse.self)
    }
}

// MARK: - Request helpers

private extension NavigationAPIClient {
    func makePOSTRequest<T: Encodable>(baseURL: URL, path: String, body: T) throws -> URLRequest {
        let url = baseURL.appendingPathComponent(path)
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw APIError.invalidURL
        }

        var queryItems = components.queryItems ?? []
        queryItems.append(URLQueryItem(name: "key", value: apiKey))
        components.queryItems = queryItems

        guard let finalURL = components.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: finalURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try encoder.encode(body)
        return request
    }

    func send<Response: Decodable>(_ request: URLRequest, decode type: Response.Type) async throws -> Response {
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidURL
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw APIError.httpError(statusCode: httpResponse.statusCode, body: data)
        }

        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw APIError.decoding(error)
        }
    }
}

// MARK: - Routing models

struct RouteRequest: Encodable {
    enum Output: String, Codable {
        case summary
        case detailed
    }

    var points: [RoutePoint]
    var transport: String?
    var filters: [String]?
    var output: Output?
    var locale: String?
    var avoid: [String]?
}

struct RoutePoint: Codable {
    enum PointType: String, Codable {
        case walking
        case stop
        case pref
    }

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
    let result: [RouteResult]
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
    let selection: String?
    let style: String?
}

// MARK: - Map matching models

struct MapMatchRequest: Encodable {
    var query: [RecordedPoint]
}

struct RecordedPoint: Codable {
    var lon: Double
    var lat: Double
    var utc: Int
    var speed: Double?
    var azimuth: Double?
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
