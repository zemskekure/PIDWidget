import WidgetKit
import SwiftUI
import CoreLocation

// MARK: - Widget Entry

struct DepartureEntry: TimelineEntry {
    let date: Date
    let stopName: String
    let departures: [Departure]
    let error: String?
    let isPlaceholder: Bool

    static var placeholder: DepartureEntry {
        DepartureEntry(
            date: Date(),
            stopName: "Anděl",
            departures: [
                Departure(line: "9", headsign: "Sídliště Řepy", minutesRemaining: 2, isTram: true, departureTime: Date()),
                Departure(line: "15", headsign: "Kotlářka", minutesRemaining: 5, isTram: true, departureTime: Date()),
                Departure(line: "20", headsign: "Divoká Šárka", minutesRemaining: 8, isTram: true, departureTime: Date()),
            ],
            error: nil,
            isPlaceholder: true
        )
    }

    static var error: DepartureEntry {
        DepartureEntry(
            date: Date(),
            stopName: "—",
            departures: [],
            error: "Chyba načtení",
            isPlaceholder: false
        )
    }
}

// MARK: - Timeline Provider

struct DepartureProvider: TimelineProvider {
    private let userDefaults = UserDefaults(suiteName: "group.cz.cervenka.pidwidget")

    func placeholder(in context: Context) -> DepartureEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (DepartureEntry) -> Void) {
        if context.isPreview {
            completion(.placeholder)
            return
        }

        Task {
            let entry = await fetchDepartures()
            completion(entry)
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DepartureEntry>) -> Void) {
        Task {
            let entry = await fetchDepartures()

            // Refresh every 5 minutes
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 5, to: Date())!
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))

            completion(timeline)
        }
    }

    private func fetchDepartures() async -> DepartureEntry {
        // Try to get cached location and find nearby stops
        var nearbyStopName: String?

        if let locationData = userDefaults?.data(forKey: "lastLocation"),
           let cached = try? JSONDecoder().decode(CachedLocation.self, from: locationData),
           Date().timeIntervalSince(cached.timestamp) < 600 {

            print("📍 [Widget] Using location: \(cached.latitude), \(cached.longitude)")

            do {
                let stops = try await GolemioAPI.shared.findNearbyStops(
                    latitude: cached.latitude,
                    longitude: cached.longitude
                )
                nearbyStopName = stops.first?.name
                print("📍 [Widget] Found nearby stop: \(nearbyStopName ?? "none")")
            } catch {
                print("📍 [Widget] Error finding stops: \(error)")
            }
        }

        // Use nearby stop or fallback
        let finalStopName = nearbyStopName ?? userDefaults?.string(forKey: "fallbackStop")

        guard let stopName = finalStopName, !stopName.isEmpty else {
            return DepartureEntry(
                date: Date(),
                stopName: "—",
                departures: [],
                error: "Nastavte zastávku v aplikaci",
                isPlaceholder: false
            )
        }

        // Fetch departures
        print("🚇 [Widget] Fetching departures for: '\(stopName)'")
        do {
            let departures = try await GolemioAPI.shared.getDepartures(stopName: stopName)
            print("🚇 [Widget] Got \(departures.count) departures")

            return DepartureEntry(
                date: Date(),
                stopName: stopName,
                departures: Array(departures.prefix(4)),
                error: nil,
                isPlaceholder: false
            )
        } catch {
            print("🚇 [Widget] Error: \(error)")
            return DepartureEntry(
                date: Date(),
                stopName: stopName,
                departures: [],
                error: "Chyba: \(error.localizedDescription)",
                isPlaceholder: false
            )
        }
    }
}

// MARK: - Widget Views

// LED Board style colors
extension Color {
    static let ledGreen = Color(red: 0.4, green: 1.0, blue: 0.4)
    static let ledYellow = Color(red: 1.0, green: 0.9, blue: 0.3)
    static let ledBoard = Color.black
}

struct SmallWidgetView: View {
    let entry: DepartureEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            if let error = entry.error {
                Text(error)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.ledYellow)
                Spacer()
            } else if entry.departures.isEmpty {
                Text("Žádné odjezdy")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.ledYellow)
                Spacer()
            } else {
                ForEach(entry.departures.prefix(3)) { dep in
                    LEDDepartureRow(departure: dep, compact: true)
                }
                Spacer()
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.ledBoard)
        .redacted(reason: entry.isPlaceholder ? .placeholder : [])
    }
}

struct LEDDepartureRow: View {
    let departure: Departure
    var compact: Bool = false

    var body: some View {
        HStack(spacing: compact ? 4 : 8) {
            // Line number - yellow
            Text(departure.line)
                .font(.system(compact ? .caption : .body, design: .monospaced, weight: .bold))
                .foregroundColor(.ledYellow)
                .frame(width: compact ? 20 : 28, alignment: .trailing)

            // Destination - white
            Text(departure.headsign)
                .font(.system(compact ? .caption2 : .callout, design: .monospaced))
                .foregroundColor(.white)
                .lineLimit(1)

            Spacer()

            // Time - green
            Text(departure.formattedTime)
                .font(.system(compact ? .caption2 : .callout, design: .monospaced, weight: .medium))
                .foregroundColor(.ledGreen)
        }
    }
}

struct MediumWidgetView: View {
    let entry: DepartureEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Stop name header
            Text(entry.stopName)
                .font(.system(.caption, design: .monospaced, weight: .bold))
                .foregroundColor(.ledYellow)
                .lineLimit(1)

            if let error = entry.error {
                Text(error)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.ledYellow)
                Spacer()
            } else if entry.departures.isEmpty {
                Text("Žádné odjezdy")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.ledYellow)
                Spacer()
            } else {
                ForEach(entry.departures.prefix(4)) { dep in
                    LEDDepartureRow(departure: dep, compact: false)
                }
                Spacer()
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.ledBoard)
        .redacted(reason: entry.isPlaceholder ? .placeholder : [])
    }
}

struct LargeWidgetView: View {
    let entry: DepartureEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header - LED style
            HStack {
                Image(systemName: "tram.fill")
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.ledYellow)
                Text(entry.stopName)
                    .font(.system(.body, design: .monospaced, weight: .bold))
                    .foregroundColor(.ledYellow)
                    .lineLimit(1)
                Spacer()
                Text(entry.date, style: .time)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.ledGreen)
            }

            Rectangle()
                .fill(Color.ledYellow.opacity(0.3))
                .frame(height: 1)

            if let error = entry.error {
                Spacer()
                HStack {
                    Spacer()
                    Text(error)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.ledYellow)
                    Spacer()
                }
                Spacer()
            } else if entry.departures.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    Text("Žádné odjezdy")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.ledYellow)
                    Spacer()
                }
                Spacer()
            } else {
                ForEach(entry.departures) { dep in
                    LEDDepartureRow(departure: dep, compact: false)
                }
                Spacer()
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.ledBoard)
        .redacted(reason: entry.isPlaceholder ? .placeholder : [])
    }
}

// MARK: - Lock Screen Widget Views

@available(iOS 16.0, *)
struct AccessoryRectangularView: View {
    let entry: DepartureEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let error = entry.error {
                Text(error)
                    .font(.system(.caption, design: .rounded, weight: .medium))
            } else if entry.departures.isEmpty {
                Text("Žádné odjezdy")
                    .font(.system(.caption, design: .rounded, weight: .medium))
            } else {
                ForEach(entry.departures.prefix(3)) { dep in
                    HStack(spacing: 6) {
                        // Line number - prominent
                        Text(dep.line)
                            .font(.system(.callout, design: .rounded, weight: .bold))
                            .frame(width: 24, alignment: .trailing)

                        // Destination - truncated
                        Text(dep.headsign)
                            .font(.system(.caption, design: .rounded))
                            .lineLimit(1)

                        Spacer(minLength: 4)

                        // Time - prominent with "min" suffix
                        Text(dep.minutesRemaining <= 0 ? "<1" : "\(dep.minutesRemaining)")
                            .font(.system(.callout, design: .rounded, weight: .semibold))
                        + Text(" min")
                            .font(.system(.caption2, design: .rounded))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .redacted(reason: entry.isPlaceholder ? .placeholder : [])
    }
}

@available(iOS 16.0, *)
struct AccessoryInlineView: View {
    let entry: DepartureEntry

    var body: some View {
        if let error = entry.error {
            Text(error)
        } else if let first = entry.departures.first {
            Text("\(first.line) → \(first.headsign) \(first.minutesRemaining)m")
        } else {
            Text("Žádné odjezdy")
        }
    }
}

@available(iOS 16.0, *)
struct AccessoryCircularView: View {
    let entry: DepartureEntry

    var body: some View {
        if let first = entry.departures.first {
            VStack(spacing: 0) {
                Text(first.line)
                    .font(.system(.body, design: .monospaced, weight: .bold))
                Text(first.minutesRemaining <= 0 ? "<1" : "\(first.minutesRemaining)")
                    .font(.system(.caption, design: .monospaced))
                Text("min")
                    .font(.system(.caption2, design: .monospaced))
            }
        } else {
            Image(systemName: "tram")
        }
    }
}

// MARK: - Widget Configuration

struct PIDDepartureWidget: Widget {
    let kind: String = "PIDDepartureWidget"

    private var supportedFamilies: [WidgetFamily] {
        if #available(iOS 16.0, *) {
            return [.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular, .accessoryInline, .accessoryCircular]
        } else {
            return [.systemSmall, .systemMedium, .systemLarge]
        }
    }

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DepartureProvider()) { entry in
            if #available(iOS 17.0, *) {
                WidgetContentView(entry: entry)
                    .containerBackground(Color.ledBoard, for: .widget)
            } else {
                WidgetContentView(entry: entry)
                    .background(Color.ledBoard)
            }
        }
        .configurationDisplayName("PID Odjezdy")
        .description("Zobrazí nejbližší odjezdy z tramvajové zastávky.")
        .supportedFamilies(supportedFamilies)
        .contentMarginsDisabled()
    }
}

struct WidgetContentView: View {
    @Environment(\.widgetFamily) var family
    let entry: DepartureEntry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        case .systemLarge:
            LargeWidgetView(entry: entry)
        case .accessoryRectangular:
            if #available(iOS 16.0, *) {
                AccessoryRectangularView(entry: entry)
            }
        case .accessoryInline:
            if #available(iOS 16.0, *) {
                AccessoryInlineView(entry: entry)
            }
        case .accessoryCircular:
            if #available(iOS 16.0, *) {
                AccessoryCircularView(entry: entry)
            }
        default:
            MediumWidgetView(entry: entry)
        }
    }
}

// MARK: - Widget Bundle

@main
struct PIDWidgetBundle: WidgetBundle {
    var body: some Widget {
        PIDDepartureWidget()
    }
}

// MARK: - Previews

@available(iOS 17.0, *)
#Preview("Small", as: .systemSmall) {
    PIDDepartureWidget()
} timeline: {
    DepartureEntry.placeholder
}

@available(iOS 17.0, *)
#Preview("Medium", as: .systemMedium) {
    PIDDepartureWidget()
} timeline: {
    DepartureEntry.placeholder
}

@available(iOS 17.0, *)
#Preview("Large", as: .systemLarge) {
    PIDDepartureWidget()
} timeline: {
    DepartureEntry.placeholder
}
