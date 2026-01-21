import SwiftUI
import CoreLocation
import WidgetKit

struct ContentView: View {
    @StateObject private var locationManager = LocationManager.shared
    @State private var departures: [Departure] = []
    @State private var nearestStop: Stop?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var fallbackStopName: String = ""

    private let userDefaults = UserDefaults(suiteName: "group.cz.cervenka.pidwidget")

    var body: some View {
        NavigationView {
            List {
                // Fallback Stop Section
                Section {
                    TextField("Název zastávky", text: $fallbackStopName)
                        .autocapitalization(.none)
                        .onChange(of: fallbackStopName) { newValue in
                            userDefaults?.set(newValue, forKey: "fallbackStop")
                        }
                } header: {
                    Text("Záložní zastávka")
                } footer: {
                    Text("Použije se, když není dostupná poloha.")
                }

                // Location Status
                Section {
                    HStack {
                        Text("Stav polohy")
                        Spacer()
                        Text(locationStatusText)
                            .foregroundColor(locationStatusColor)
                    }

                    if locationManager.authorizationStatus == .denied {
                        Button("Otevřít Nastavení") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                    }

                    if locationManager.authorizationStatus == .notDetermined {
                        Button("Povolit polohu") {
                            locationManager.requestPermission()
                        }
                    }
                } header: {
                    Text("Poloha")
                }

                // Current Departures Preview
                Section {
                    if isLoading {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    } else if let error = errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.footnote)
                    } else if departures.isEmpty {
                        Text("Žádné odjezdy")
                            .foregroundColor(.secondary)
                    } else {
                        if let stop = nearestStop {
                            Text(stop.displayName)
                                .font(.headline)
                        }

                        ForEach(departures.prefix(5)) { departure in
                            DepartureRow(departure: departure)
                        }
                    }

                    Button(action: refreshDepartures) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Obnovit")
                        }
                    }
                    .disabled(isLoading)
                } header: {
                    Text("Odjezdy")
                } footer: {
                    Text("Widget se aktualizuje automaticky každých 5-15 minut.")
                }

                // Info Section
                Section {
                    HStack {
                        Text("Verze")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Informace")
                }
            }
            .navigationTitle("PID Odjezdy")
            .onAppear {
                loadSavedSettings()
                refreshDepartures()
            }
        }
    }

    private var locationStatusText: String {
        switch locationManager.authorizationStatus {
        case .notDetermined: return "Nenastaveno"
        case .denied, .restricted: return "Zamítnuto"
        case .authorizedWhenInUse, .authorizedAlways: return "Povoleno"
        @unknown default: return "Neznámý"
        }
    }

    private var locationStatusColor: Color {
        switch locationManager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways: return .green
        case .denied, .restricted: return .red
        default: return .orange
        }
    }

    private func loadSavedSettings() {
        fallbackStopName = userDefaults?.string(forKey: "fallbackStop") ?? ""
    }

    private func refreshDepartures() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                // Try to get location
                print("📍 Requesting location...")
                let location = try await locationManager.requestLocation()
                print("📍 Got location: \(location.coordinate.latitude), \(location.coordinate.longitude)")

                // Save location for widget
                locationManager.saveLocationForWidget(location)

                // Find nearby stops
                print("🔍 Finding nearby stops...")
                let stops = try await GolemioAPI.shared.findNearbyStops(
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude
                )
                print("🔍 Found \(stops.count) stops: \(stops.map { $0.name })")

                // Try each stop until we find one with tram departures
                for stop in stops {
                    print("🚇 Trying stop: \(stop.name)")
                    let deps = try await GolemioAPI.shared.getDepartures(stopName: stop.name)
                    if !deps.isEmpty {
                        print("🚇 Got \(deps.count) departures from \(stop.name)")
                        await MainActor.run {
                            self.nearestStop = stop
                            self.departures = deps
                            self.isLoading = false
                            WidgetCenter.shared.reloadAllTimelines()
                        }
                        return
                    }
                    print("🚇 No trams at \(stop.name), trying next...")
                }

                // No stops with trams found
                await MainActor.run {
                    errorMessage = "Žádná tramvaj v okolí"
                    isLoading = false
                }
            } catch {

                // Try fallback stop
                if !fallbackStopName.isEmpty {
                    do {
                        let deps = try await GolemioAPI.shared.getDepartures(stopName: fallbackStopName)
                        await MainActor.run {
                            self.nearestStop = Stop(id: "fallback", name: fallbackStopName, latitude: 0, longitude: 0)
                            self.departures = deps
                            self.isLoading = false
                        }
                        return
                    } catch {
                        // Fall through to error
                    }
                }

                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
}

struct DepartureRow: View {
    let departure: Departure

    var body: some View {
        HStack {
            // Line number badge
            Text(departure.line)
                .font(.system(.body, design: .rounded, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 36, height: 28)
                .background(lineColor)
                .cornerRadius(6)

            // Destination
            Text(departure.headsign)
                .lineLimit(1)

            Spacer()

            // Time
            Text(departure.formattedTime)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(departure.minutesRemaining <= 2 ? .red : .primary)
        }
    }

    private var lineColor: Color {
        if departure.isTram {
            return .red
        }
        // Metro colors
        switch departure.line {
        case "A": return .green
        case "B": return .yellow
        case "C": return .red
        default: return .blue
        }
    }
}

#Preview {
    ContentView()
}
