# PID Widget - iOS App

iOS widget showing Prague public transport departures from your nearest tram stop.

## Features

- Automatically finds nearest tram/metro/bus stop based on location
- Shows next 3-4 departures with line number, destination, and time
- Supports Small, Medium, and Large widget sizes
- Fallback stop when location unavailable
- Czech language UI

## Setup in Xcode

### 1. Create New Project

1. Open Xcode → File → New → Project
2. Choose **App** (iOS)
3. Product Name: `PIDWidget`
4. Team: Your team (or Personal Team)
5. Organization Identifier: `cz.cervenka` (or your own)
6. Interface: **SwiftUI**
7. Language: **Swift**
8. Uncheck "Include Tests"

### 2. Add Widget Extension

1. File → New → Target
2. Choose **Widget Extension**
3. Product Name: `PIDWidgetExtension`
4. **Uncheck** "Include Configuration App Intent" (we use static config)
5. Finish

### 3. Configure App Group

This allows the main app and widget to share data (API key, location).

1. Select project in navigator → select `PIDWidget` target
2. Signing & Capabilities → + Capability → **App Groups**
3. Add group: `group.cz.cervenka.pidwidget`
4. Repeat for `PIDWidgetExtension` target (same group name)

### 4. Add Location Permission

1. Select `PIDWidget` target → Info tab
2. Add these keys:
   - `Privacy - Location When In Use Usage Description`: `Aplikace potřebuje polohu pro nalezení nejbližší zastávky.`
   - `Privacy - Location Always and When In Use Usage Description`: `Pro aktualizaci widgetu na pozadí.`

### 5. Copy Source Files

Copy these files into your project:

**Main App (PIDWidget folder):**
- `PIDWidgetApp.swift` → replace generated file
- `Models/Departure.swift` → create Models group
- `Services/GolemioAPI.swift` → create Services group
- `Services/LocationManager.swift`
- `Views/ContentView.swift` → replace generated ContentView

**Widget Extension (PIDWidgetExtension folder):**
- `PIDWidgetExtension.swift` → replace generated file
- `SharedModels.swift` → add new file

### 6. Delete Generated Files

Delete these auto-generated files:
- `PIDWidgetExtensionBundle.swift` (if exists)
- `PIDWidgetExtensionLiveActivity.swift` (if exists)
- `AppIntent.swift` (if exists)

### 7. Build & Run

1. Select your iPhone or Simulator
2. Build and run (⌘R)
3. In the app:
   - Enter your Golemio API key
   - Allow location access
   - Set a fallback stop (optional)
4. Add widget to home screen:
   - Long press home screen → + button → search "PID"

## Project Structure

```
PIDWidget/
├── PIDWidget/                      # Main app
│   ├── PIDWidgetApp.swift         # App entry point
│   ├── Models/
│   │   └── Departure.swift        # Data models
│   ├── Services/
│   │   ├── GolemioAPI.swift       # API client
│   │   └── LocationManager.swift  # Location handling
│   └── Views/
│       └── ContentView.swift      # Settings UI
│
└── PIDWidgetExtension/            # Widget
    ├── PIDWidgetExtension.swift   # Widget views & provider
    └── SharedModels.swift         # Duplicated models for widget
```

## How It Works

1. **Main app** requests location permission and saves coordinates to shared App Group
2. **Widget** reads cached location from App Group
3. Widget calls Golemio API to find nearest stop
4. Widget fetches departures for that stop
5. Widget refreshes every ~5 minutes (iOS controlled)

## Limitations

- iOS widgets refresh on a system schedule (5-15 min), not real-time
- Location in widgets is approximate (last known position)
- Widget must be configured via main app first

## API Key

Get your free Golemio API key at: https://api.golemio.cz/api-keys

## Troubleshooting

**Widget shows "Nastavte API klíč"**
- Open main app and enter your API key

**Widget shows "Otevřete aplikaci"**
- Open main app, allow location, optionally set fallback stop

**Location not working**
- Check Settings → Privacy → Location Services → PIDWidget

**Build errors about App Group**
- Ensure both targets have the same App Group configured
- App Group ID must match in code: `group.cz.cervenka.pidwidget`

## License

MIT
