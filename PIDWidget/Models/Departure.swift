import Foundation

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

    var lineColor: String {
        // Prague tram line colors (simplified)
        switch line {
        case "9", "10", "16", "22": return "red"
        case "1", "2", "3", "4", "5", "6", "7", "8": return "orange"
        default: return "blue"
        }
    }
}

struct Stop: Identifiable, Codable {
    let id: String
    let name: String
    let latitude: Double
    let longitude: Double
    let platformCode: String?
    let aswNodeId: Int?
    let aswStopId: Int?

    init(id: String, name: String, latitude: Double, longitude: Double, platformCode: String? = nil, aswNodeId: Int? = nil, aswStopId: Int? = nil) {
        self.id = id
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.platformCode = platformCode
        self.aswNodeId = aswNodeId
        self.aswStopId = aswStopId
    }

    var displayName: String {
        if let platform = platformCode, !platform.isEmpty {
            return "\(name) (\(platform))"
        }
        return name
    }
}
