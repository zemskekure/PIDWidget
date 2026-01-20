// Vercel serverless function: GET /api/departures?stop=Anděl
// Returns departures for a stop

const GOLEMIO_API_KEY = process.env.GOLEMIO_API_KEY;
const GOLEMIO_BASE_URL = "https://api.golemio.cz/v2";

export default async function handler(req, res) {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  if (req.method !== 'GET') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const { stop } = req.query;

  if (!stop) {
    return res.status(400).json({ error: 'Missing stop parameter' });
  }

  try {
    const params = new URLSearchParams({
      names: stop,
      minutesBefore: '0',
      minutesAfter: '60',
      limit: '20',
      order: 'real',
      mode: 'departures',
      preferredTimezone: 'Europe/Prague',
      includeMetroTrains: 'true',
    });

    const url = `${GOLEMIO_BASE_URL}/pid/departureboards?${params}`;

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
    const now = new Date();

    // Transform departures
    const departures = data.departures
      .map(dep => {
        const timeString = dep.departure_timestamp?.predicted || dep.departure_timestamp?.scheduled;
        if (!timeString) return null;

        const depTime = new Date(timeString);
        const minutesRemaining = Math.floor((depTime - now) / 60000);
        const routeType = dep.route?.type ?? -1;
        const delayMinutes = dep.delay?.is_available ? (dep.delay?.minutes ?? 0) : 0;

        return {
          line: dep.route?.short_name ?? '?',
          headsign: dep.trip?.headsign ?? '',
          minutesRemaining,
          isTram: routeType === 0,
          departureTime: depTime.toISOString(),
          delayMinutes,
        };
      })
      .filter(dep => dep !== null)
      .sort((a, b) => a.minutesRemaining - b.minutesRemaining);

    return res.status(200).json({ departures });
  } catch (error) {
    console.error('Error fetching departures:', error);
    return res.status(500).json({ error: 'Internal server error' });
  }
}
