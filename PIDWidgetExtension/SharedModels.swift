// Shared models and API client for widget extension
// These are duplicated from the main app because widget extensions
// run in a separate process and need their own copies

import Foundation

// MARK: - Models

struct Departure: Identifiable, Codable {
    let id: UUID
    let line: String
    let headsign: String
    let minutesRemaining: Int
    let isTram: Bool
    let departureTime: Date
    let delayMinutes: Int

    init(id: UUID = UUID(), line: String, headsign: String, minutesRemaining: Int, isTram: Bool, departureTime: Date, delayMinutes: Int = 0) {
        self.id = id
        self.line = line
        self.headsign = headsign
        self.minutesRemaining = minutesRemaining
        self.isTram = isTram
        self.departureTime = departureTime
        self.delayMinutes = delayMinutes
    }

    var formattedTime: String {
        if minutesRemaining <= 0 {
            return "teď"
        }
        return "za \(minutesRemaining) min"
    }
}

struct Stop: Identifiable, Codable {
    let id: String
    let name: String
    let latitude: Double
    let longitude: Double
    let platformCode: String?

    init(id: String, name: String, latitude: Double, longitude: Double, platformCode: String? = nil) {
        self.id = id
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.platformCode = platformCode
    }

    var displayName: String {
        if let platform = platformCode, !platform.isEmpty {
            return "\(name) (\(platform))"
        }
        return name
    }
}

struct CachedLocation: Codable {
    let latitude: Double
    let longitude: Double
    let timestamp: Date
}

// MARK: - API Client

actor GolemioAPI {
    static let shared = GolemioAPI()

    // TODO: Replace with your Vercel deployment URL
    private let baseURL = "https://pid-widget-api.vercel.app/api"

    private init() {}

    func findNearbyStops(latitude: Double, longitude: Double, radius: Int = 500) async throws -> [Stop] {
        var components = URLComponents(string: "\(baseURL)/stops")!
        components.queryItems = [
            URLQueryItem(name: "lat", value: String(latitude)),
            URLQueryItem(name: "lng", value: String(longitude)),
            URLQueryItem(name: "radius", value: String(radius)),
        ]

        guard let url = components.url else { throw URLError(.badURL) }

        print("🔍 [Widget] findNearbyStops URL: \(url)")

        var request = URLRequest(url: url)
        request.timeoutInterval = 30

        let (data, httpResp) = try await URLSession.shared.data(for: request)

        if let resp = httpResp as? HTTPURLResponse {
            print("🔍 [Widget] findNearbyStops status: \(resp.statusCode)")
            if resp.statusCode != 200 {
                let body = String(data: data, encoding: .utf8) ?? "no body"
                print("🔍 [Widget] findNearbyStops error body: \(body)")
                throw URLError(.badServerResponse)
            }
        }

        let response = try JSONDecoder().decode(StopsAPIResponse.self, from: data)
        print("🔍 [Widget] findNearbyStops found \(response.stops.count) stops")

        return response.stops.map { stop in
            Stop(
                id: stop.id ?? UUID().uuidString,
                name: stop.name,
                latitude: stop.latitude,
                longitude: stop.longitude,
                platformCode: stop.platformCode
            )
        }
    }

    func getDepartures(stopName: String) async throws -> [Departure] {
        var components = URLComponents(string: "\(baseURL)/departures")!
        components.queryItems = [
            URLQueryItem(name: "stop", value: stopName),
        ]

        guard let url = components.url else { throw URLError(.badURL) }

        print("🚇 [Widget] getDepartures URL: \(url)")

        var request = URLRequest(url: url)
        request.timeoutInterval = 10

        let (data, httpResponse) = try await URLSession.shared.data(for: request)

        if let resp = httpResponse as? HTTPURLResponse {
            print("🚇 [Widget] getDepartures status: \(resp.statusCode)")
            if resp.statusCode != 200 {
                let body = String(data: data, encoding: .utf8) ?? "no body"
                print("🚇 [Widget] getDepartures error body: \(body)")
                throw URLError(.badServerResponse)
            }
        }

        let decoded = try JSONDecoder().decode(DeparturesAPIResponse.self, from: data)

        return decoded.departures.map { dep in
            Departure(
                line: dep.line,
                headsign: dep.headsign,
                minutesRemaining: dep.minutesRemaining,
                isTram: dep.isTram,
                departureTime: ISO8601DateFormatter().date(from: dep.departureTime) ?? Date(),
                delayMinutes: dep.delayMinutes
            )
        }.sorted { $0.minutesRemaining < $1.minutesRemaining }
    }
}

// MARK: - API Response Models

struct StopsAPIResponse: Codable {
    let stops: [StopDTO]
}

struct StopDTO: Codable {
    let id: String?
    let name: String
    let latitude: Double
    let longitude: Double
    let platformCode: String?
    let distance: Int?
}

struct DeparturesAPIResponse: Codable {
    let departures: [DepartureDTO]
}

struct DepartureDTO: Codable {
    let line: String
    let headsign: String
    let minutesRemaining: Int
    let isTram: Bool
    let departureTime: String
    let delayMinutes: Int
}
