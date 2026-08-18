// Proxy de la API de Transporte de la Ciudad (subte + EcoBici).
// La credencial va en variables de entorno de Vercel (NO en el cliente).
const ID = process.env.BA_CLIENT_ID;
const SECRET = process.env.BA_CLIENT_SECRET;

const paths = {
  subte: 'subtes/forecastGTFS',
  'ecobici-info': 'ecobici/gbfs/stationInformation',
  'ecobici-status': 'ecobici/gbfs/stationStatus',
};

module.exports = async (req, res) => {
  const path = paths[req.query.ep];
  if (!path) return res.status(400).json({ error: 'ep inválido' });
  if (!ID || !SECRET) return res.status(503).json({ error: 'no configurado' });
  const url = `https://apitransporte.buenosaires.gob.ar/${path}?client_id=${encodeURIComponent(ID)}&client_secret=${encodeURIComponent(SECRET)}&json=1`;
  try {
    const r = await fetch(url, { headers: { Accept: 'application/json' } });
    if (!r.ok) return res.status(502).json({ error: 'ba', status: r.status });
    const data = await r.json();
    res.setHeader('Cache-Control', 's-maxage=15, stale-while-revalidate=30');
    return res.status(200).json(data);
  } catch (e) {
    return res.status(502).json({ error: 'ba inalcanzable' });
  }
};
