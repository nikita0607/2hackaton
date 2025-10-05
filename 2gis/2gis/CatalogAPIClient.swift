import Foundation

struct CatalogAPIClient {
    enum APIError: LocalizedError { case invalidURL, http(Int), decoding(Error) }

    struct Configuration: Sendable {
        let baseV3: URL
        static let production = Configuration(baseV3: URL(string: "https://catalog.api.2gis.com/3.0")!)
    }

    private let apiKey: String
    private let session: URLSession
    private let config: Configuration
    private let decoder: JSONDecoder

    init(apiKey: String, session: URLSession = .shared, config: Configuration = .production) {
        self.apiKey = apiKey
        self.session = session
        self.config = config
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        self.decoder = d
    }

    // MARK: Endpoints

    func geocodeBuilding(lon: Double, lat: Double, radius: Int? = 50) async throws -> GeocodeResponse {
        var comp = URLComponents(url: config.baseV3.appendingPathComponent("items/geocode"), resolvingAgainstBaseURL: false)!
        var qi: [URLQueryItem] = [
            .init(name: "lon", value: String(lon)),
            .init(name: "lat", value: String(lat)),
            .init(name: "type", value: "building"),
            .init(name: "key", value: apiKey)
        ]
        if let radius { qi.append(.init(name: "radius", value: String(radius))) }
        comp.queryItems = qi
        let req = URLRequest(url: comp.url!)
        return try await send(req, decode: GeocodeResponse.self)
    }

    func buildingDetails(id: String, fields: String?) async throws -> BuildingDetailsResponse {
        var comp = URLComponents(url: config.baseV3.appendingPathComponent("items/byid"), resolvingAgainstBaseURL: false)!
        var items = [URLQueryItem(name: "id", value: id), URLQueryItem(name: "key", value: apiKey)]
        if let fields, !fields.isEmpty { items.append(.init(name: "fields", value: fields)) }
        comp.queryItems = items
        let req = URLRequest(url: comp.url!)
        return try await send(req, decode: BuildingDetailsResponse.self)
    }

    func listIndoorOrganizations(buildingId: String, page: Int = 1, pageSize: Int = 12) async throws -> PlacesSearchResponse {
        var comp = URLComponents(url: config.baseV3.appendingPathComponent("items"), resolvingAgainstBaseURL: false)!
        comp.queryItems = [
            .init(name: "key", value: apiKey),
            .init(name: "building_id", value: buildingId),
            .init(name: "search_type", value: "indoor"),
            .init(name: "page", value: String(page)),
            .init(name: "page_size", value: String(pageSize))
        ]
        let req = URLRequest(url: comp.url!)
        return try await send(req, decode: PlacesSearchResponse.self)
    }

    func listServicing(buildingId: String, group: String = "default", fields: String? = nil, page: Int = 1, pageSize: Int = 12) async throws -> PlacesSearchResponse {
        var comp = URLComponents(url: URL(string: "https://catalog.api.2gis.com")!.appendingPathComponent("3.0/items/byservicing"), resolvingAgainstBaseURL: false)!
        var items = [
            URLQueryItem(name: "key", value: apiKey),
            URLQueryItem(name: "building_id", value: buildingId),
            URLQueryItem(name: "servicing_group", value: group),
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "page_size", value: String(pageSize))
        ]
        if let fields, !fields.isEmpty { items.append(.init(name: "fields", value: fields)) }
        comp.queryItems = items
        let req = URLRequest(url: comp.url!)
        return try await send(req, decode: PlacesSearchResponse.self)
    }

    // MARK: Sending
    private func send<T: Decodable>(_ req: URLRequest, decode: T.Type) async throws -> T {
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw APIError.invalidURL }
        guard 200..<300 ~= http.statusCode else { throw APIError.http(http.statusCode) }
        do { return try decoder.decode(T.self, from: data) } catch { throw APIError.decoding(error) }
    }
}

// MARK: Models

struct GeocodeResponse: Decodable {
    struct Result: Decodable { let items: [GeocodeItem]?; let total: Int? }
    let meta: Meta?
    let result: Result?
}

struct GeocodeItem: Decodable, Identifiable { let id: String; let name: String; let fullName: String?; let type: String }

struct BuildingDetailsResponse: Decodable {
    struct Result: Decodable { let items: [BuildingDetails]?; let total: Int? }
    let meta: Meta?
    let result: Result?
}

struct BuildingDetails: Decodable, Identifiable {
    struct Point: Decodable { let lon: Double?; let lat: Double? }
    struct StructureInfo: Decodable {
        let material: String?
        let apartmentsCount: Int?
        let porchCount: Int?
        let floorType: String?
        let gasType: String?
        let yearOfConstruction: Int?
        let elevatorsCount: Int?
        let isInEmergencyState: Bool?
        let projectType: String?
        let chsName: String?
        let chsCategory: String?
    }
    let id: String
    let name: String
    let addressName: String?
    let type: String
    let floors: Int?
    let point: Point?
    let structureInfo: StructureInfo?
}

struct Meta: Decodable { let apiVersion: String?; let code: Int?; let issueDate: String? }

struct PlacesSearchResponse: Decodable {
    struct Result: Decodable { let items: [PlaceItem]? }
    let meta: Meta?
    let result: Result?
}

struct PlaceItem: Decodable, Identifiable {
    struct Point: Decodable { let lon: Double?; let lat: Double? }
    struct ContactGroup: Decodable { let name: String?; let contacts: [Contact]?; struct Contact: Decodable { let type: String?; let value: String? } }
    struct WorkingHours: Decodable { let text: String? }
    let id: String
    let name: String?
    let addressName: String?
    let point: Point?
    let rubrics: [Rubric]?
    let contactGroups: [ContactGroup]?
    let workingHours: WorkingHours?
    let links: [String: String]? // keep flexible
    let rating: Double?
    let reviewsCount: Int?
    struct Rubric: Decodable { let name: String? }
}

