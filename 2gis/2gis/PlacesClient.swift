//
//  PlacesClient.swift
//  2gis
//
//  Created by Павел on 05.10.2025.
//

import Foundation

public struct DGisPlacesClient {
    public struct Config {
        public var apiKey: String
        public var baseURL: URL
        public init(apiKey: String,
                    baseURL: URL = URL(string: "https://catalog.api.2gis.com/3.0")!) {
            self.apiKey = apiKey
            self.baseURL = baseURL
        }
    }

    public enum ClientError: Error, LocalizedError {
        case invalidURL
        case http(Int)
        case emptyResult
        public var errorDescription: String? {
            switch self {
            case .invalidURL: return "Invalid URL"
            case .http(let code): return "HTTP error \(code)"
            case .emptyResult: return "No items found"
            }
        }
    }

    public struct Point: Decodable {
        public let lon: Double?
        public let lat: Double?
    }

    public struct PlaceItem: Decodable {
        public let id: String
        public let name: String
        public let addressName: String?
        public let point: Point?

        private enum CodingKeys: String, CodingKey {
            case id, name, point
            case addressName = "address_name"
        }
    }

    public struct Meta: Decodable {
        public let code: Int?
        public let total: Int?
        public let page: Int?
        public let pageSize: Int?

        private enum CodingKeys: String, CodingKey {
            case code, total, page
            case pageSize = "page_size"
        }
    }

    public struct PlacesResultBlock: Decodable {
        public let items: [PlaceItem]?
    }

    public struct PlacesResponse: Decodable {
        public let meta: Meta?
        public let result: PlacesResultBlock?
    }

    private let config: Config
    private let session: URLSession

    public init(config: Config, session: URLSession = .shared) {
        self.config = config
        self.session = session
    }

    /// Поиск мест по названию. Рекомендуется указывать город в тексте запроса (например, "Moscow cafe") для более точного результата. 2GIS также поддерживает пагинацию `page`/`page_size` и список полей `fields`.
    /// Документация: /3.0/items?q=...&key=... (+ page, page_size, fields)
    /// - Parameters:
    ///   - name: Текст запроса (например, "Coffee Like" или "Moscow cafe").
    ///   - cityHint: Необязательная подсказка города; будет добавлена к запросу (см. рекомендации 2GIS).
    ///   - page: Номер страницы (по умолчанию 1).
    ///   - pageSize: Размер страницы (1...50).
    ///   - fields: Дополнительные поля, например: ["items.point","items.address_name"].
    /// - Returns: Распарсенный ответ с метаданными и списком найденных объектов.
    public func searchPlacesByName(
        _ name: String,
        cityHint: String? = nil,
        page: Int = 1,
        pageSize: Int = 12,
        fields: [String] = ["items.point","items.address_name"]
    ) async throws -> PlacesResponse {
        // Сборка q с учётом cityHint (по рекомендации 2GIS добавлять город в текст запроса).
        // См. пример: `q=Moscow cafe&type=branch&key=...`
        let q: String = {
            if let city = cityHint?.trimmingCharacters(in: .whitespacesAndNewlines), !city.isEmpty {
                return "\(city) \(name)"
            } else {
                return name
            }
        }()

        var comps = URLComponents(url: config.baseURL.appendingPathComponent("items"), resolvingAgainstBaseURL: false)
        comps?.queryItems = [
            URLQueryItem(name: "q", value: q),
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "page_size", value: String(pageSize)),
            URLQueryItem(name: "key", value: config.apiKey)
        ]

        if !fields.isEmpty {
            comps?.queryItems?.append(URLQueryItem(name: "fields", value: fields.joined(separator: ",")))
        }

        guard let url = comps?.url else { throw ClientError.invalidURL }

        var req = URLRequest(url: url)
        req.httpMethod = "GET"

        let (data, resp) = try await session.data(for: req)
        if let http = resp as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw ClientError.http(http.statusCode)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .useDefaultKeys

        let dto = try decoder.decode(PlacesResponse.self, from: data)
        return dto
    }

    /// Удобный хелпер: вернуть лучший (первый) матч, иначе ошибка.
    public func bestMatch(
        _ name: String,
        cityHint: String? = nil,
        fields: [String] = ["items.point","items.address_name"]
    ) async throws -> PlaceItem {
        let response = try await searchPlacesByName(name, cityHint: cityHint, page: 1, pageSize: 1, fields: fields)
        if let first = response.result?.items?.first {
            return first
        } else {
            throw ClientError.emptyResult
        }
    }
}
