import Foundation
import CoreLocation

enum GolemioError: Error, LocalizedError {
    case invalidURL
    case networkError(Error)
    case decodingError(Error)
    case noData
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .networkError(let error): return "Network error: \(error.localizedDescription)"
        case .decodingError(let error): return "Decoding error: \(error.localizedDescription)"
        case .noData: return "No data received"
        case .apiError(let message): return "API error: \(message)"
        }
    }
}

actor GolemioAPI {
    static let shared = GolemioAPI()

    // TODO: Replace with your Vercel deployment URL
    private let baseURL = "https://pid-widget-api.vercel.app/api"

    private init() {}

    // MARK: - Find Nearby Stops

    func findNearbyStops(latitude: Double, longitude: Double, radius: Int = 500) async throws -> [Stop] {
        var components = URLComponents(string: "\(baseURL)/stops")!
        components.queryItems = [
            URLQueryItem(name: "lat", value: String(latitude)),
            URLQueryItem(name: "lng", value: String(longitude)),
            URLQueryItem(name: "radius", value: String(radius)),
        ]

        guard let url = components.url else {
            throw GolemioError.invalidURL
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw GolemioError.apiError("HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)")
        }

        let decoder = JSONDecoder()
        let stopsResponse = try decoder.decode(StopsAPIResponse.self, from: data)

        return stopsResponse.stops.map { stop in
            Stop(
                id: stop.id ?? UUID().uuidString,
                name: stop.name,
                latitude: stop.latitude,
                longitude: stop.longitude,
                platformCode: stop.platformCode,
                aswNodeId: nil,
                aswStopId: nil
            )
        }
    }

    // MARK: - Get Departures

    func getDepartures(stopName: String, directionFilter: String? = nil, tramOnly: Bool = false) async throws -> [Departure] {
        var components = URLComponents(string: "\(baseURL)/departures")!
        components.queryItems = [
            URLQueryItem(name: "stop", value: stopName),
        ]

        guard let url = components.url else {
            throw GolemioError.invalidURL
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 10

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw GolemioError.apiError("HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)")
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let departuresResponse = try decoder.decode(DeparturesAPIResponse.self, from: data)

        var departures = departuresResponse.departures.map { dep in
            Departure(
                line: dep.line,
                headsign: dep.headsign,
                minutesRemaining: dep.minutesRemaining,
                isTram: dep.isTram,
                departureTime: ISO8601DateFormatter().date(from: dep.departureTime) ?? Date(),
                delayMinutes: dep.delayMinutes
            )
        }

        // Apply filters
        if tramOnly {
            departures = departures.filter { $0.isTram }
        }

        if let filter = directionFilter, !filter.isEmpty {
            departures = departures.filter { $0.headsign.localizedCaseInsensitiveContains(filter) }
        }

        return departures.sorted { $0.minutesRemaining < $1.minutesRemaining }
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
