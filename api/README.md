# PID Widget API

Backend proxy for the PID Widget iOS app. Handles Golemio API authentication so users don't need their own API key.

## Deploy to Vercel

1. **Install Vercel CLI** (if not already installed):
   ```bash
   npm i -g vercel
   ```

2. **Navigate to this directory**:
   ```bash
   cd api
   ```

3. **Deploy**:
   ```bash
   vercel
   ```

4. **Set the API key as environment variable**:
   ```bash
   vercel env add GOLEMIO_API_KEY
   ```
   Enter your Golemio API key when prompted.

5. **Redeploy to apply the env variable**:
   ```bash
   vercel --prod
   ```

6. **Update the iOS app** with your deployment URL:
   - Edit `PIDWidget/Services/GolemioAPI.swift`
   - Edit `PIDWidgetExtension/SharedModels.swift`
   - Change `baseURL` to your Vercel URL (e.g., `https://your-project.vercel.app/api`)

## API Endpoints

### GET /api/stops
Find nearby stops by location.

**Parameters:**
- `lat` (required) - Latitude
- `lng` (required) - Longitude
- `radius` (optional) - Search radius in meters (default: 500)

**Response:**
```json
{
  "stops": [
    {
      "id": "U123",
      "name": "Anděl",
      "latitude": 50.0712,
      "longitude": 14.4037,
      "platformCode": "A",
      "distance": 42
    }
  ]
}
```

### GET /api/departures
Get departures for a stop.

**Parameters:**
- `stop` (required) - Stop name

**Response:**
```json
{
  "departures": [
    {
      "line": "9",
      "headsign": "Sídliště Řepy",
      "minutesRemaining": 2,
      "isTram": true,
      "departureTime": "2024-01-20T22:15:00Z",
      "delayMinutes": 0
    }
  ]
}
```

## Local Development

```bash
npm install
vercel dev
```

Then test at `http://localhost:3000/api/stops?lat=50.08&lng=14.42`
