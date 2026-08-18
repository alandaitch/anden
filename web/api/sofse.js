// Proxy de arribos de Trenes Argentinos (SOFSE). Sin token: /arribos/estacion/{id}.
// Corre en el servidor (evita CORS del navegador).
module.exports = async (req, res) => {
  const station = String(req.query.station || '');
  if (!/^\d{1,6}$/.test(station)) {
    return res.status(400).json({ error: 'station inválida' });
  }
  try {
    const r = await fetch(`https://api-servicios.sofse.gob.ar/v1/arribos/estacion/${station}`, {
      headers: { Accept: 'application/json' },
    });
    if (!r.ok) return res.status(502).json({ error: 'sofse', status: r.status });
    const data = await r.json();
    res.setHeader('Cache-Control', 's-maxage=15, stale-while-revalidate=30');
    return res.status(200).json(data);
  } catch (e) {
    return res.status(502).json({ error: 'sofse inalcanzable' });
  }
};
