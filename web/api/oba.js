// Proxy de OneBusAway de cuandosubo (colectivos en vivo). key=web es pública.
// Endpoints permitidos, con validación de parámetros.
const BASE = 'https://cuandosubo.sube.gob.ar/onebusaway-api-webapp/api/where';
const KEY = 'web';

const num = (v) => {
  const n = Number(v);
  return Number.isFinite(n) ? n : null;
};
const id = (v) => (/^[0-9A-Za-z_.:-]{1,40}$/.test(String(v || '')) ? String(v) : null);

const builders = {
  'stops-for-location': (q) => {
    const lat = num(q.lat), lon = num(q.lon);
    const radius = Math.min(1500, Math.max(50, num(q.radius) || 500));
    if (lat === null || lon === null) return null;
    return `stops-for-location.json?key=${KEY}&lat=${lat}&lon=${lon}&radius=${radius}`;
  },
  arrivals: (q) => {
    const sid = id(q.id);
    return sid ? `arrivals-and-departures-for-stop/${encodeURIComponent(sid)}.json?key=${KEY}` : null;
  },
  trip: (q) => {
    const tid = id(q.id);
    return tid ? `trip/${encodeURIComponent(tid)}.json?key=${KEY}` : null;
  },
  shape: (q) => {
    const shid = id(q.id);
    return shid ? `shape/${encodeURIComponent(shid)}.json?key=${KEY}` : null;
  },
};

module.exports = async (req, res) => {
  const build = builders[req.query.ep];
  if (!build) return res.status(400).json({ error: 'ep inválido' });
  const path = build(req.query);
  if (!path) return res.status(400).json({ error: 'parámetros inválidos' });
  try {
    const r = await fetch(`${BASE}/${path}`, { headers: { Accept: 'application/json' } });
    if (!r.ok) return res.status(502).json({ error: 'oba', status: r.status });
    const data = await r.json();
    res.setHeader('Cache-Control', 's-maxage=15, stale-while-revalidate=30');
    return res.status(200).json(data);
  } catch (e) {
    return res.status(502).json({ error: 'oba inalcanzable' });
  }
};
