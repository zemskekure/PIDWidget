// Vercel serverless function: GET /api/stops?lat=50.08&lng=14.42&radius=500
// Returns nearby stops

const GOLEMIO_API_KEY = process.env.GOLEMIO_API_KEY;
const GOLEMIO_BASE_URL = "https://api.golemio.cz/v2";

// Haversine formula to calculate distance in meters
function haversineDistance(lat1, lon1, lat2, lon2) {
  const R = 6371000; // Earth's radius in meters
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLon = (lon2 - lon1) * Math.PI / 180;
  const a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
    Math.sin(dLon / 2) * Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

export default async function handler(req, res) {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  if (req.method !== 'GET') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const { lat, lng, radius = 500 } = req.query;

  if (!lat || !lng) {
    return res.status(400).json({ error: 'Missing lat or lng parameter' });
  }

  const latitude = parseFloat(lat);
  const longitude = parseFloat(lng);
  const searchRadius = parseInt(radius, 10);

  if (isNaN(latitude) || isNaN(longitude)) {
    return res.status(400).json({ error: 'Invalid lat or lng parameter' });
  }

  try {
    // Fetch all stops from Golemio
    const url = `${GOLEMIO_BASE_URL}/gtfs/stops?limit=5000`;

    const response = await fetch(url, {
      headers: {
        'X-Access-Token': GOLEMIO_API_KEY,
      },
    });

    if (!response.ok) {
      const errorText = await response.text();
      console.error('Golemio API error:', response.status, errorText);
      return res.status(response.status).json({ error: `Golemio API error: ${response.status}` });
    }

    const data = await response.json();

    // Filter and sort stops by distance
    const nearbyStops = data.features
      .map(feature => {
        const coords = feature.geometry?.coordinates;
        if (!coords || coords.length < 2 || !feature.properties.stop_name) {
          return null;
        }

        const stopLat = coords[1];
        const stopLon = coords[0];
        const distance = haversineDistance(latitude, longitude, stopLat, stopLon);

        return {
          id: feature.properties.stop_id,
          name: feature.properties.stop_name,
          latitude: stopLat,
          longitude: stopLon,
          platformCode: feature.properties.platform_code,
          distance: Math.round(distance),
        };
      })
      .filter(stop => stop !== null && stop.distance <= searchRadius)
      .sort((a, b) => a.distance - b.distance)
      .slice(0, 10);

    return res.status(200).json({ stops: nearbyStops });
  } catch (error) {
    console.error('Error fetching stops:', error);
    return res.status(500).json({ error: 'Internal server error' });
  }
}
