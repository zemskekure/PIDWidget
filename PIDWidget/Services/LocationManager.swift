import Foundation
import CoreLocation

@MainActor
class LocationManager: NSObject, ObservableObject {
    static let shared = LocationManager()

    private let manager = CLLocationManager()

    @Published var location: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var error: Error?

    private var continuation: CheckedContinuation<CLLocation, Error>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        authorizationStatus = manager.authorizationStatus
    }

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    func requestLocation() async throws -> CLLocation {
        // Check authorization
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
            // Wait a bit for user to respond
            try await Task.sleep(nanoseconds: 500_000_000)
            return try await requestLocation()

        case .denied, .restricted:
            throw LocationError.permissionDenied

        case .authorizedWhenInUse, .authorizedAlways:
            break

        @unknown default:
            break
        }

        // Return cached location if recent enough (within 5 minutes)
        if let cached = location, Date().timeIntervalSince(cached.timestamp) < 300 {
            return cached
        }

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            manager.requestLocation()
        }
    }

    /// Get location for widget (synchronous, uses cached)
    func getCachedLocation() -> CLLocation? {
        // Try to get from UserDefaults (shared with widget)
        if let data = UserDefaults(suiteName: "group.cz.cervenka.pidwidget")?.data(forKey: "lastLocation"),
           let decoded = try? JSONDecoder().decode(CachedLocation.self, from: data),
           Date().timeIntervalSince(decoded.timestamp) < 600 { // 10 minutes
            return CLLocation(latitude: decoded.latitude, longitude: decoded.longitude)
        }
        return location
    }

    func saveLocationForWidget(_ location: CLLocation) {
        let cached = CachedLocation(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            timestamp: Date()
        )
        if let data = try? JSONEncoder().encode(cached) {
            UserDefaults(suiteName: "group.cz.cervenka.pidwidget")?.set(data, forKey: "lastLocation")
        }
    }
}

extension LocationManager: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        Task { @MainActor in
            self.location = location
            self.saveLocationForWidget(location)
            self.continuation?.resume(returning: location)
            self.continuation = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.error = error
            self.continuation?.resume(throwing: error)
            self.continuation = nil
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            self.authorizationStatus = manager.authorizationStatus
        }
    }
}

enum LocationError: Error, LocalizedError {
    case permissionDenied
    case locationUnavailable

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Přístup k poloze byl zamítnut. Povolte v Nastavení."
        case .locationUnavailable:
            return "Poloha není dostupná."
        }
    }
}

struct CachedLocation: Codable {
    let latitude: Double
    let longitude: Double
    let timestamp: Date
}
