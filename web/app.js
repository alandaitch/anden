'use strict';

/* ─────────── Google Analytics (GA4) ───────────
   Pegá tu Measurement ID (G-XXXXXXXXXX) acá abajo y listo. */
const GA_ID = 'G-407FNTKDJN'; // Google Analytics 4
function initGA() {
  if (!GA_ID) return;
  const s = document.createElement('script');
  s.async = true;
  s.src = 'https://www.googletagmanager.com/gtag/js?id=' + GA_ID;
  document.head.appendChild(s);
  window.dataLayer = window.dataLayer || [];
  window.gtag = function () { dataLayer.push(arguments); };
  gtag('js', new Date());
  gtag('config', GA_ID);
}
function track(name, params) { if (window.gtag) gtag('event', name, params || {}); }

/* ─────────── Catálogos de colores ─────────── */
const TRAIN_LINES = {
  1:  { code: 'SA', color: '#B83280', name: 'Sarmiento' },
  5:  { code: 'MI', color: '#1E7FD4', name: 'Mitre' },
  11: { code: 'RO', color: '#16A34A', name: 'Roca' },
  21: { code: 'BS', color: '#EAB308', name: 'Belgrano Sur' },
  31: { code: 'SM', color: '#E0632B', name: 'San Martín' },
  41: { code: 'TC', color: '#0D9488', name: 'Tren de la Costa' },
  61: { code: 'BN', color: '#8A94A6', name: 'Belgrano Norte' },
  71: { code: 'UR', color: '#8A94A6', name: 'Urquiza' },
  501:{ code: 'RG', color: '#7C5CFC', name: 'Regionales' },
};
function trainLine(id) { return TRAIN_LINES[id] || { code: '?', color: '#8A94A6', name: 'Tren' }; }

const SUBTE_LINES = {
  LineaA: { letra: 'A', color: '#00AEEF' }, LineaB: { letra: 'B', color: '#EE3124' },
  LineaC: { letra: 'C', color: '#0072BC' }, LineaD: { letra: 'D', color: '#00A650' },
  LineaE: { letra: 'E', color: '#8E44AD' }, LineaH: { letra: 'H', color: '#FFD200' },
  Premetro: { letra: 'P', color: '#00A19A' },
};
function subteLine(routeId) {
  if (SUBTE_LINES[routeId]) return SUBTE_LINES[routeId];
  const l = (routeId || '').replace(/linea/i, '').slice(0, 1).toUpperCase() || '?';
  return { letra: l, color: '#8A94A6' };
}

const BUS_PALETTE = ['#E4572E','#F3A712','#2E9E5B','#1E7FD4','#7B4FB5','#D6336C','#0FA3A3','#B5651D','#5B7A2E','#3D5AA9','#C2417B','#557A95','#E8590C','#2F9E44','#1971C2','#9C36B5','#C92A2A','#0CA678','#F08C00','#4263EB','#AE3EC9','#087F5B','#5C940D','#A61E4D'];
function busColor(short) {
  let h = 5381;
  for (const ch of String(short || '')) h = (h * 33 + ch.charCodeAt(0)) % 2147483647;
  return BUS_PALETTE[((h % BUS_PALETTE.length) + BUS_PALETTE.length) % BUS_PALETTE.length];
}
const BICI_COLOR = '#0FA3A3';
const BRAND = '#242C4F';

/* ─────────── Íconos SVG ─────────── */
const SVG = {
  train: '<svg viewBox="0 0 24 24"><path d="M12 2c-4 0-8 .5-8 4v9.5A2.5 2.5 0 0 0 6.5 18L5 19.5V20h2l2-2h6l2 2h2v-.5L17.5 18a2.5 2.5 0 0 0 2.5-2.5V6c0-3.5-4-4-8-4zM7.5 15A1.5 1.5 0 1 1 9 13.5 1.5 1.5 0 0 1 7.5 15zm9 0a1.5 1.5 0 1 1 1.5-1.5 1.5 1.5 0 0 1-1.5 1.5zM18 10H6V6h12z"/></svg>',
  bus: '<svg viewBox="0 0 24 24"><path d="M4 16c0 .88.39 1.67 1 2.22V20a1 1 0 0 0 1 1h1a1 1 0 0 0 1-1v-1h8v1a1 1 0 0 0 1 1h1a1 1 0 0 0 1-1v-1.78c.61-.55 1-1.34 1-2.22V6c0-3.5-3.58-4-8-4s-8 .5-8 4zm3.5 1A1.5 1.5 0 1 1 9 15.5 1.5 1.5 0 0 1 7.5 17zm9 0a1.5 1.5 0 1 1 1.5-1.5 1.5 1.5 0 0 1-1.5 1.5zM18 11H6V6h12z"/></svg>',
  bike: '<svg viewBox="0 0 24 24"><path d="M15.5 5.5a2 2 0 1 0-2-2 2 2 0 0 0 2 2zM5 12a5 5 0 1 0 5 5 5 5 0 0 0-5-5zm0 8a3 3 0 1 1 3-3 3 3 0 0 1-3 3zm5.8-10 2.4-2.4.8.8A6 6 0 0 0 16 9v-2a4 4 0 0 1-1.6-.6l-1.9-1.9a1.4 1.4 0 0 0-1-.5 1.4 1.4 0 0 0-1 .4L7.6 7.8a1.4 1.4 0 0 0 0 2l3.2 2.7V17h2v-4.5zM19 12a5 5 0 1 0 5 5 5 5 0 0 0-5-5zm0 8a3 3 0 1 1 3-3 3 3 0 0 1-3 3z"/></svg>',
  subte: '<svg viewBox="0 0 24 24"><path d="M12 2c-4 0-8 .5-8 4v9.5A2.5 2.5 0 0 0 6.5 18L5 19.5V20h2l2-2h6l2 2h2v-.5L17.5 18a2.5 2.5 0 0 0 2.5-2.5V6c0-3.5-4-4-8-4zM7.5 15A1.5 1.5 0 1 1 9 13.5 1.5 1.5 0 0 1 7.5 15zm9 0a1.5 1.5 0 1 1 1.5-1.5 1.5 1.5 0 0 1-1.5 1.5zM18 10H6V6h12z"/></svg>',
  near: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 11l19-9-9 19-2-8-8-2z"/></svg>',
  star: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linejoin="round"><path d="M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z"/></svg>',
  map: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M1 6v16l7-4 8 4 7-4V2l-7 4-8-4-7 4z"/><path d="M8 2v16M16 6v16"/></svg>',
};
function modeSvg(mode) {
  return mode === 'bondi' ? SVG.bus : mode === 'bici' ? SVG.bike : mode === 'subte' ? SVG.subte : SVG.train;
}

/* ─────────── Utilidades ─────────── */
const $ = (sel, el) => (el || document).querySelector(sel);
const el = (tag, cls, html) => { const e = document.createElement(tag); if (cls) e.className = cls; if (html != null) e.innerHTML = html; return e; };
const esc = (s) => String(s == null ? '' : s).replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));

function distM(a, b) {
  const R = 6371000, toRad = (d) => d * Math.PI / 180;
  const dLat = toRad(b.lat - a.lat), dLon = toRad(b.lng - a.lng);
  const s = Math.sin(dLat / 2) ** 2 + Math.cos(toRad(a.lat)) * Math.cos(toRad(b.lat)) * Math.sin(dLon / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(s));
}
function etaText(secs) {
  if (secs == null) return '';
  if (secs <= 30) return 'ahora';
  if (secs < 90) return 'llegando';
  return 'en ' + Math.round(secs / 60) + ' min';
}
function distText(m) {
  if (m == null) return '';
  if (m < 1000) return 'a ' + Math.round(m) + ' m';
  return 'a ' + (m / 1000).toFixed(1).replace('.', ',') + ' km';
}
function normalize(s) {
  return String(s || '').toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g, '').replace(/[^a-z0-9]/g, '');
}
async function api(path) {
  const r = await fetch(path, { headers: { Accept: 'application/json' } });
  if (!r.ok) throw new Error('http ' + r.status);
  return r.json();
}

/* ─────────── Estado ─────────── */
const S = {
  loc: null,
  trainCat: [],
  subteCat: [],
  filter: localStorage.getItem('anden.filter') || 'todos',
  favs: JSON.parse(localStorage.getItem('anden.favs.v1') || '[]'),
  view: 'cerca',
  map: null,
};

/* Favoritos (localStorage, multi-modo) */
function favKey(f) { return f.mode + ':' + f.id; }
function isFav(mode, id) { return S.favs.some((f) => f.mode === mode && f.id === id); }
function saveFavs() { localStorage.setItem('anden.favs.v1', JSON.stringify(S.favs)); }
function toggleFav(fav) {
  const i = S.favs.findIndex((f) => f.mode === fav.mode && f.id === fav.id);
  if (i >= 0) S.favs.splice(i, 1); else S.favs.push(fav);
  saveFavs();
}

/* ─────────── Ubicación ─────────── */
function getLocation() {
  return new Promise((resolve) => {
    if (!navigator.geolocation) return resolve(null);
    navigator.geolocation.getCurrentPosition(
      (p) => resolve({ lat: p.coords.latitude, lng: p.coords.longitude }),
      () => resolve(null),
      { enableHighAccuracy: false, timeout: 8000, maximumAge: 60000 }
    );
  });
}

/* ─────────── Catálogos ─────────── */
async function loadCatalogs() {
  if (S.trainCat.length) return;
  const [tr, su] = await Promise.all([api('data/estaciones.json'), api('data/subte-estaciones.json')]);
  S.trainCat = tr.filter((e) => e.visibleEnApp && e.tieneArribosHoy);
  S.subteCat = su;
}

/* ─────────── Fuentes de datos ─────────── */
async function trainArrivals(stationId) {
  const d = await api('api/sofse?station=' + stationId);
  const now = d.timestamp || Math.floor(Date.now() / 1000);
  const out = [];
  for (const r of d.results || []) {
    const s = r.servicio, a = r.arribo;
    if (!s || !a) continue;
    const line = trainLine((s.gerencia || {}).id);
    const dest = (((s.hasta || {}).estacion || {}).nombre) ||
      (((s.ramal || {})[(s.sentido === 2 ? 'cabeceraInicial' : 'cabeceraFinal')] || {}).nombre) || '';
    const secs = a.segundos != null ? a.segundos : null;
    let loc = null;
    if (s.location && s.location.lat != null) loc = { lat: s.location.lat, lng: s.location.long };
    const route = (s.estaciones || []).map((e) => e.idPunto || e.id).filter(Boolean); // no coords aquí
    out.push({
      dest, secs, live: true, anden: (a.anden || {}).nombre || null,
      line, loc, tripStations: (s.estaciones || []),
    });
  }
  out.sort((x, y) => (x.secs ?? 1e9) - (y.secs ?? 1e9));
  return out;
}

let _subteFeed = null, _subteFeedAt = 0;
async function subteFeed() {
  if (_subteFeed && Date.now() - _subteFeedAt < 15000) return _subteFeed;
  const d = await api('api/ba?ep=subte');
  _subteFeed = d; _subteFeedAt = Date.now();
  return d;
}
async function subteArrivals(stationName) {
  const d = await subteFeed();
  const now = Math.floor(Date.now() / 1000);
  const target = normalize(stationName);
  const out = [];
  for (const ent of d.Entity || []) {
    const L = ent.Linea; if (!L) continue;
    const ests = L.Estaciones || [];
    const stop = ests.find((e) => normalize(e.stop_name) === target);
    if (!stop || !stop.arrival) continue;
    const t = stop.arrival.time; if (!t) continue;
    const secs = t - now; if (secs < -60) continue;
    const dest = (ests[ests.length - 1] || {}).stop_name || '';
    out.push({ dest, secs: Math.max(0, secs), live: true, line: subteLine(L.Route_Id) });
  }
  out.sort((a, b) => a.secs - b.secs);
  return out;
}

async function bondiArrivals(stopId) {
  const d = await api('api/oba?ep=arrivals&id=' + encodeURIComponent(stopId));
  const now = Date.now();
  const list = (((d.data || {}).entry || {}).arrivalsAndDepartures) || [];
  const out = [];
  for (const a of list) {
    const predicted = a.predicted === true && (a.predictedArrivalTime || 0) > 0;
    const ms = predicted ? a.predictedArrivalTime : a.scheduledArrivalTime;
    if (!ms) continue;
    const secs = Math.round((ms - now) / 1000);
    if (secs < -45) continue;
    let veh = null;
    const ts = a.tripStatus;
    if (ts && ts.predicted && ts.position && ts.position.lat && ts.position.lon) veh = { lat: ts.position.lat, lng: ts.position.lon };
    out.push({
      short: a.routeShortName || '', dest: a.tripHeadsign || '',
      secs: Math.max(0, secs), live: predicted, veh, tripId: a.tripId || null,
    });
  }
  out.sort((a, b) => a.secs - b.secs);
  return out;
}

async function tripShape(tripId) {
  try {
    const t = await api('api/oba?ep=trip&id=' + encodeURIComponent(tripId));
    const shapeId = (((t.data || {}).entry || {}).shapeId);
    if (!shapeId) return [];
    const sh = await api('api/oba?ep=shape&id=' + encodeURIComponent(shapeId));
    const pts = (((sh.data || {}).entry || {}).points);
    return pts ? decodePolyline(pts) : [];
  } catch (e) { return []; }
}
function decodePolyline(str) {
  let index = 0, lat = 0, lng = 0; const coords = [];
  while (index < str.length) {
    let b, shift = 0, result = 0;
    do { b = str.charCodeAt(index++) - 63; result |= (b & 0x1f) << shift; shift += 5; } while (b >= 0x20);
    lat += (result & 1) ? ~(result >> 1) : (result >> 1);
    shift = 0; result = 0;
    do { b = str.charCodeAt(index++) - 63; result |= (b & 0x1f) << shift; shift += 5; } while (b >= 0x20);
    lng += (result & 1) ? ~(result >> 1) : (result >> 1);
    coords.push([lat / 1e5, lng / 1e5]);
  }
  return coords;
}

/* ─────────── EcoBici ─────────── */
let _biciCache = null, _biciAt = 0;
async function biciStations() {
  if (_biciCache && Date.now() - _biciAt < 30000) return _biciCache;
  const [info, status] = await Promise.all([api('api/ba?ep=ecobici-info'), api('api/ba?ep=ecobici-status')]);
  const st = {};
  for (const s of (((status.data || {}).stations) || [])) st[s.station_id] = s;
  const out = [];
  for (const s of (((info.data || {}).stations) || [])) {
    const stt = st[s.station_id] || {};
    out.push({
      id: String(s.station_id), name: s.name, lat: s.lat, lng: s.lon,
      bikes: stt.num_bikes_available ?? 0, docks: stt.num_docks_available ?? 0,
      inService: (stt.status || 'IN_SERVICE') === 'IN_SERVICE' && (stt.is_renting ?? 1) !== 0,
    });
  }
  _biciCache = out; _biciAt = Date.now();
  return out;
}
function biciName(n) {
  const p = String(n || '').split('-');
  if (p.length >= 2 && /^\d/.test(p[0].trim())) return p.slice(1).join('-').trim();
  return String(n || '').trim();
}

/* ─────────── Colectivos: líneas cercanas ─────────── */
async function nearbyBondiLines(loc) {
  const d = await api(`api/oba?ep=stops-for-location&lat=${loc.lat}&lon=${loc.lng}&radius=500`);
  let stops = (((d.data || {}).list) || []).map((s) => ({ id: s.id, name: s.name, lat: s.lat, lng: s.lon }));
  stops = stops.filter((s) => s.lat).map((s) => ({ ...s, d: distM(loc, s) })).sort((a, b) => a.d - b.d).slice(0, 9);
  const now = Date.now();
  const results = await Promise.all(stops.map((s) =>
    api('api/oba?ep=arrivals&id=' + encodeURIComponent(s.id)).then((r) => ({ s, r })).catch(() => null)
  ));
  const byKey = {};
  for (const item of results) {
    if (!item) continue;
    const list = (((item.r.data || {}).entry || {}).arrivalsAndDepartures) || [];
    for (const a of list) {
      const predicted = a.predicted === true && (a.predictedArrivalTime || 0) > 0;
      const ms = predicted ? a.predictedArrivalTime : a.scheduledArrivalTime;
      if (!ms) continue;
      const secs = Math.round((ms - now) / 1000);
      if (secs < 0) continue;
      const key = (a.routeShortName || '') + '|' + (a.tripHeadsign || '');
      if (!byKey[key] || secs < byKey[key].secs) {
        byKey[key] = {
          short: a.routeShortName || '', dest: a.tripHeadsign || '',
          secs, live: predicted, stop: item.s, d: item.s.d,
        };
      }
    }
  }
  return Object.values(byKey).sort((a, b) => a.secs - b.secs);
}

/* ─────────── Router / navegación ─────────── */
function go(view, opts) {
  S.view = view;
  const params = new URLSearchParams();
  params.set('v', view);
  if (opts) for (const k in opts) if (opts[k] != null) params.set(k, opts[k]);
  location.hash = '#' + params.toString();
}
function currentParams() {
  const p = new URLSearchParams(location.hash.replace(/^#/, ''));
  return p;
}
window.addEventListener('hashchange', route);

function route() {
  destroyMap();
  const p = currentParams();
  const v = p.get('v') || 'cerca';
  // tabs / back button
  document.querySelectorAll('.tab').forEach((t) => t.classList.toggle('active', t.dataset.view === v));
  const isSub = v === 'board';
  $('#backBtn').classList.toggle('hidden', !isSub);
  if (v === 'board') return renderBoard(p);
  if (v === 'favoritos') { $('#view').scrollTop = 0; return renderFavoritos(); }
  if (v === 'mapa') return renderMapa();
  return renderCerca();
}

/* ─────────── Vista: Cerca ─────────── */
const FILTERS = [
  { key: 'todos', label: 'Todos', ico: '▦' },
  { key: 'tren', label: 'Tren', ico: '' },
  { key: 'subte', label: 'Subte', ico: '' },
  { key: 'bondi', label: 'Bondi', ico: '' },
  { key: 'bici', label: 'Bici', ico: '' },
];

async function renderCerca() {
  track('screen_view', { screen_name: 'cerca' });
  const view = $('#view');
  view.innerHTML = '';
  const chips = el('div', 'chips');
  FILTERS.forEach((f) => {
    const c = el('button', 'chip' + (S.filter === f.key ? ' active' : ''), esc(f.label));
    c.onclick = () => { S.filter = f.key; localStorage.setItem('anden.filter', f.key); renderCerca(); };
    chips.appendChild(c);
  });
  view.appendChild(chips);
  const listEl = el('div');
  view.appendChild(listEl);
  view.appendChild(footerNote());

  if (!S.loc) {
    listEl.appendChild(spinner('Buscando tu ubicación…'));
    S.loc = await getLocation();
    if (!S.loc) {
      listEl.innerHTML = '';
      listEl.appendChild(stateBox('Necesitamos tu ubicación', 'Activá la ubicación del navegador para ver el transporte cerca tuyo.', 'Reintentar', () => { S.loc = null; renderCerca(); }));
      return;
    }
  }
  await loadCatalogs();
  listEl.innerHTML = '';
  listEl.appendChild(spinner('Buscando transporte cerca tuyo…'));

  const rows = [];
  const want = (m) => S.filter === 'todos' || S.filter === m;

  const jobs = [];
  if (want('tren')) jobs.push(collectTrains(rows));
  if (want('subte')) jobs.push(collectSubte(rows));
  if (want('bondi')) jobs.push(collectBondi(rows));
  if (want('bici')) jobs.push(collectBici(rows));
  await Promise.allSettled(jobs);

  rows.sort((a, b) => (a.d ?? 1e12) - (b.d ?? 1e12));
  listEl.innerHTML = '';
  if (!rows.length) {
    listEl.appendChild(stateBox('Nada cerca ahora', 'No encontramos transporte cerca tuyo en este momento.'));
    return;
  }
  const grid = el('div', 'list');
  for (const r of rows) grid.appendChild(rowEl(r));
  listEl.appendChild(grid);
}

async function collectTrains(rows) {
  const near = S.trainCat.map((s) => ({ s, d: distM(S.loc, { lat: s.lat, lng: s.lng }) })).sort((a, b) => a.d - b.d).slice(0, 4);
  await Promise.all(near.map(async ({ s, d }) => {
    let sub = null, subCls = 'muted';
    try {
      const arr = (await trainArrivals(s.id))[0];
      if (arr) { sub = etaText(arr.secs) + (arr.dest ? ' · a ' + arr.dest : ''); subCls = 'live'; }
    } catch (e) {}
    const line = trainLine(s.gerenciaId);
    rows.push({
      mode: 'tren', id: String(s.id), title: s.nombre, d,
      badgeText: line.code, badgeColor: line.color, tag: 'Tren', tagColor: line.color,
      sub, subCls, lat: s.lat, lng: s.lng,
      open: () => go('board', { mode: 'tren', id: s.id, name: s.nombre, lat: s.lat, lng: s.lng }),
    });
  }));
}

async function collectSubte(rows) {
  const near = S.subteCat.map((s) => ({ s, d: distM(S.loc, { lat: s.lat, lng: s.lng }) })).sort((a, b) => a.d - b.d).slice(0, 4);
  await Promise.all(near.map(async ({ s, d }) => {
    let sub = null, subCls = 'muted';
    try {
      const arr = (await subteArrivals(s.name))[0];
      if (arr) { sub = etaText(arr.secs) + (arr.dest ? ' · a ' + arr.dest : ''); subCls = 'live'; }
    } catch (e) {}
    const line = subteLine(s.line);
    rows.push({
      mode: 'subte', id: s.line + '-' + s.name, title: s.name, d,
      badgeText: line.letra, badgeColor: line.color, tag: 'Subte', tagColor: line.color,
      sub, subCls, lat: s.lat, lng: s.lng,
      open: () => go('board', { mode: 'subte', id: s.line + '-' + s.name, name: s.name, line: s.line, lat: s.lat, lng: s.lng }),
    });
  }));
}

async function collectBondi(rows) {
  let lines = [];
  try { lines = await nearbyBondiLines(S.loc); } catch (e) {}
  for (const l of lines.slice(0, 8)) {
    const color = busColor(l.short);
    rows.push({
      mode: 'bondi', id: l.stop.id + '|' + l.short + '|' + l.dest, title: l.dest ? 'a ' + l.dest.replace(/^a\s+/i, '') : 'Línea ' + l.short,
      d: l.d, badgeText: l.short, badgeColor: color, tag: 'Colectivo', tagColor: color,
      sub: etaText(l.secs) + (l.live ? ' en vivo' : ' prog') + ' · ' + prettyStop(l.stop.name), subCls: l.live ? 'live' : 'prog',
      lat: l.stop.lat, lng: l.stop.lng,
      open: () => go('board', { mode: 'bondi', id: l.stop.id, name: prettyStop(l.stop.name), lat: l.stop.lat, lng: l.stop.lng }),
    });
  }
}

async function collectBici(rows) {
  let sts = [];
  try { sts = await biciStations(); } catch (e) { return; }
  const near = sts.map((s) => ({ s, d: distM(S.loc, { lat: s.lat, lng: s.lng }) })).sort((a, b) => a.d - b.d).slice(0, 4);
  for (const { s, d } of near) {
    let sub, subCls;
    if (!s.inService) { sub = 'Fuera de servicio'; subCls = 'muted'; }
    else { sub = s.bikes + (s.bikes === 1 ? ' bici · ' : ' bicis · ') + s.docks + (s.docks === 1 ? ' anclaje' : ' anclajes'); subCls = s.bikes === 0 ? 'prog' : 'live'; }
    rows.push({
      mode: 'bici', id: s.id, title: biciName(s.name), d,
      badgeSvg: SVG.bike, badgeColor: BICI_COLOR, tag: 'EcoBici', tagColor: BICI_COLOR,
      sub, subCls, lat: s.lat, lng: s.lng,
      open: () => go('board', { mode: 'bici', id: s.id, name: biciName(s.name), lat: s.lat, lng: s.lng }),
    });
  }
}

function prettyStop(n) {
  // "1606 MITRE BARTOLOME" o "359 CALLAO AV." → dejamos lo que venga; OBA ya trae muchos lindos.
  return String(n || 'Parada');
}

function rowEl(r) {
  const row = el('div', 'row');
  const badge = el('div', 'badge');
  badge.style.background = r.badgeColor;
  badge.innerHTML = r.badgeSvg || esc(r.badgeText || '');
  const main = el('div', 'row-main');
  main.appendChild(el('div', 'row-title', esc(r.title)));
  const meta = el('div', 'row-meta');
  const tag = el('span', null, esc(r.tag)); tag.style.color = r.tagColor;
  meta.appendChild(tag);
  meta.appendChild(el('span', 'dist', '· ' + distText(r.d)));
  main.appendChild(meta);
  if (r.sub) main.appendChild(el('div', 'row-sub ' + (r.subCls || 'muted'), esc(r.sub)));
  const go = el('a', 'go', '↗'); go.href = mapsHref(r);
  go.onclick = (e) => e.stopPropagation();
  row.appendChild(badge); row.appendChild(main); row.appendChild(go);
  row.onclick = r.open;
  return row;
}
function mapsHref(r) {
  return 'https://www.google.com/maps/dir/?api=1&destination=' + r.lat + ',' + r.lng + '&travelmode=walking';
}

/* ─────────── Vista: Tablero ─────────── */
async function renderBoard(p) {
  const mode = p.get('mode'), id = p.get('id'), name = p.get('name') || 'Parada';
  const lat = parseFloat(p.get('lat')), lng = parseFloat(p.get('lng'));
  const line = p.get('line');
  track('screen_view', { screen_name: 'board_' + mode });
  const view = $('#view');
  view.innerHTML = '';

  const modeName = { tren: 'Estación', subte: 'Estación de subte', bondi: 'Parada de colectivo', bici: 'Estación EcoBici' }[mode];
  const fav = { mode, id, name, lat, lng, line };
  const head = el('div', 'board-head');
  const top = el('div', 'board-head-top');
  const bIco = el('div', 'badge'); bIco.style.background = mode === 'bici' ? BICI_COLOR : BRAND; bIco.innerHTML = modeSvg(mode);
  const tt = el('div', 'row-main');
  tt.appendChild(el('div', 'board-title', esc(name)));
  tt.appendChild(el('div', 'board-sub', esc(modeName)));
  const starBtn = el('button', 'starbtn', isFav(mode, id) ? '★' : '☆');
  starBtn.style.color = isFav(mode, id) ? 'var(--minor)' : 'var(--text2)';
  starBtn.onclick = () => { toggleFav(fav); const on = isFav(mode, id); starBtn.textContent = on ? '★' : '☆'; starBtn.style.color = on ? 'var(--minor)' : 'var(--text2)'; track('toggle_fav', { mode }); };
  top.appendChild(bIco); top.appendChild(tt); top.appendChild(starBtn);
  head.appendChild(top);
  const actions = el('div', 'board-actions');
  const goBtn = el('a', 'btn btn-ghost', 'Cómo llego'); goBtn.href = 'https://www.google.com/maps/dir/?api=1&destination=' + lat + ',' + lng + '&travelmode=transit'; goBtn.target = '_blank';
  actions.appendChild(goBtn);
  head.appendChild(actions);
  view.appendChild(head);

  const hasMap = !isNaN(lat) && mode !== 'bici' && mode !== 'subte';
  let list;
  if (hasMap) {
    const body = el('div', 'board-body');
    const mm = el('div'); mm.id = 'minimap'; body.appendChild(mm);
    list = el('div', 'arr-list'); body.appendChild(list);
    view.appendChild(body);
  } else {
    list = el('div', 'arr-list'); view.appendChild(list);
  }
  view.appendChild(footerNote());
  list.appendChild(spinner('Buscando arribos…'));

  try {
    if (mode === 'tren') await boardTrain(id, { lat, lng, name }, list);
    else if (mode === 'subte') await boardSubte(name, line, list);
    else if (mode === 'bondi') await boardBondi(id, { lat, lng }, list);
    else if (mode === 'bici') await boardBici(id, list);
  } catch (e) {
    list.innerHTML = '';
    list.appendChild(stateBox('No pudimos cargar', 'Reintentá en un momento.', 'Reintentar', () => renderBoard(p)));
  }
}

function arrRow(dest, secs, meta, etaBig) {
  const a = el('div', 'arr');
  const m = el('div', 'arr-main');
  m.appendChild(el('div', 'arr-dest', esc(dest)));
  if (meta) m.appendChild(el('div', 'arr-meta', meta));
  a.appendChild(m);
  const e = el('div', 'arr-eta');
  e.innerHTML = etaBig != null ? etaBig : (secs <= 30 ? 'ahora' : Math.round(secs / 60) + ' <small>min</small>');
  a.appendChild(e);
  return a;
}
function liveDotHtml(live) { return live ? '<span class="livedot" style="display:inline-block"></span> <b style="color:var(--onTime)">En vivo</b>' : '<b style="color:var(--text2)">Programado</b>'; }

async function boardTrain(id, stop, list) {
  const arr = await trainArrivals(id);
  list.innerHTML = '';
  if (!arr.length) { list.appendChild(stateBox('Sin trenes ahora', 'No hay arribos en vivo para esta estación.')); }
  const incoming = arr.find((a) => a.loc);
  drawMiniMap(stop, incoming ? incoming.loc : null, [], (incoming ? incoming.line.color : BRAND), SVG.train);
  for (const a of arr.slice(0, 8)) {
    list.appendChild(arrRow(a.dest || 'Tren', a.secs, liveDotHtml(a.live) + (a.anden ? ' · And. ' + esc(a.anden) : '')));
  }
}
async function boardSubte(name, line, list) {
  const arr = await subteArrivals(name);
  list.innerHTML = '';
  if (!arr.length) { list.appendChild(stateBox('Sin subtes ahora', 'No hay arribos en vivo para esta estación.')); }
  for (const a of arr.slice(0, 8)) list.appendChild(arrRow('a ' + (a.dest || ''), a.secs, liveDotHtml(true)));
}
async function boardBondi(stopId, stop, list) {
  const arr = await bondiArrivals(stopId);
  list.innerHTML = '';
  if (!arr.length) { list.appendChild(stateBox('Sin colectivos ahora', 'No hay arribos informados para esta parada.')); }
  const incoming = arr.find((a) => a.veh);
  const color = incoming ? busColor(incoming.short) : BRAND;
  drawMiniMap(stop, incoming ? incoming.veh : null, [], color, SVG.bus);
  if (incoming && incoming.tripId) tripShape(incoming.tripId).then((r) => { if (r.length && S.map) drawRoute(r, color); });
  for (const a of arr.slice(0, 10)) {
    list.appendChild(arrRow((a.short ? a.short + ' · ' : '') + 'a ' + a.dest.replace(/^a\s+/i, ''), a.secs, liveDotHtml(a.live)));
  }
}
async function boardBici(id, list) {
  const sts = await biciStations();
  const s = sts.find((x) => x.id === id);
  list.innerHTML = '';
  if (!s) { list.appendChild(stateBox('Sin datos', 'No encontramos esta estación ahora.')); return; }
  const card = el('div', 'arr');
  card.innerHTML = `<div class="arr-main"><div class="arr-dest">${s.bikes} ${s.bikes === 1 ? 'bici' : 'bicis'} disponibles</div><div class="arr-meta">${s.docks} ${s.docks === 1 ? 'anclaje libre' : 'anclajes libres'}${s.inService ? '' : ' · fuera de servicio'}</div></div><div class="arr-eta" style="font-size:20px">🚲</div>`;
  list.appendChild(card);
  list.appendChild(el('div', 'footer-note', 'EcoBici no informa horario de arribo. Te mostramos la disponibilidad en vivo.'));
}

/* ─────────── Mini-mapa (Leaflet) ─────────── */
function destroyMap() { if (S.map) { S.map.remove(); S.map = null; } S._route = null; }
function osmLayer() {
  return L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', { maxZoom: 19, attribution: '© OpenStreetMap' });
}
function stopDivIcon(color) {
  return L.divIcon({ className: '', html: `<div style="width:26px;height:26px;border-radius:8px;background:#fff;border:2.5px solid ${color};display:grid;place-items:center;box-shadow:0 1px 3px rgba(0,0,0,.3)"><div style="width:9px;height:9px;border-radius:9px;background:${color}"></div></div>`, iconSize: [26, 26], iconAnchor: [13, 13] });
}
function vehDivIcon(color) {
  return L.divIcon({ className: '', html: `<div style="width:22px;height:22px;border-radius:22px;background:${color};border:2px solid #fff;box-shadow:0 0 0 6px ${color}44"></div>`, iconSize: [22, 22], iconAnchor: [11, 11] });
}
function userDivIcon() {
  return L.divIcon({ className: '', html: `<div style="width:16px;height:16px;border-radius:16px;background:#2D7DF6;border:2px solid #fff;box-shadow:0 0 0 5px #2D7DF633"></div>`, iconSize: [16, 16], iconAnchor: [8, 8] });
}
function drawMiniMap(stop, veh, route, color, ico) {
  const node = document.getElementById('minimap');
  if (!node) return;
  const map = L.map(node, { zoomControl: false, attributionControl: false, dragging: false, scrollWheelZoom: false, doubleClickZoom: false, boxZoom: false, keyboard: false, tap: false });
  S.map = map;
  osmLayer().addTo(map);
  L.marker([stop.lat, stop.lng], { icon: stopDivIcon(color) }).addTo(map);
  if (S.loc) L.marker([S.loc.lat, S.loc.lng], { icon: userDivIcon() }).addTo(map);
  const bounds = [[stop.lat, stop.lng]];
  if (veh) { L.marker([veh.lat, veh.lng], { icon: vehDivIcon(color) }).addTo(map); bounds.push([veh.lat, veh.lng]); }
  const fit = () => {
    map.invalidateSize();
    if (bounds.length > 1) map.fitBounds(bounds, { padding: [40, 40], maxZoom: 16 });
    else map.setView([stop.lat, stop.lng], 16);
  };
  fit();
  requestAnimationFrame(fit);
  setTimeout(fit, 200);
  setTimeout(() => map.invalidateSize(), 500);
}
function drawRoute(coords, color) {
  if (!S.map) return;
  if (S._route) S.map.removeLayer(S._route);
  S._route = L.polyline(coords, { color, weight: 3, opacity: .7, dashArray: '2 8', lineCap: 'round' }).addTo(S.map);
}

/* ─────────── Vista: Favoritos ─────────── */
async function renderFavoritos() {
  track('screen_view', { screen_name: 'favoritos' });
  const view = $('#view'); view.innerHTML = '';
  view.appendChild(el('div', 'section-h', 'Favoritos'));
  if (!S.favs.length) {
    view.appendChild(stateBox('Sin favoritos', 'Guardá cualquier parada (tren, subte, colectivo o bici) con la ★ desde su tablero para verla acá.'));
    view.appendChild(footerNote());
    return;
  }
  const list = el('div', 'list'); view.appendChild(list); view.appendChild(footerNote());
  for (const f of S.favs) {
    const color = f.mode === 'tren' ? BRAND : f.mode === 'subte' ? subteLine(f.line).color : f.mode === 'bici' ? BICI_COLOR : BRAND;
    const r = {
      mode: f.mode, id: f.id, title: f.name, d: S.loc ? distM(S.loc, { lat: +f.lat, lng: +f.lng }) : null,
      badgeSvg: (f.mode === 'subte' && f.line) ? null : modeSvg(f.mode),
      badgeText: (f.mode === 'subte' && f.line) ? subteLine(f.line).letra : (f.mode === 'tren' ? '' : ''),
      badgeColor: color, tag: ({ tren: 'Tren', subte: 'Subte', bondi: 'Colectivo', bici: 'EcoBici' })[f.mode], tagColor: color,
      sub: null, subCls: 'muted', lat: +f.lat, lng: +f.lng,
      open: () => go('board', { mode: f.mode, id: f.id, name: f.name, lat: f.lat, lng: f.lng, line: f.line }),
    };
    if (f.mode === 'tren' && !r.badgeText) { r.badgeSvg = SVG.train; }
    const node = rowEl(r);
    list.appendChild(node);
    // próximo arribo async
    hydrateFavSub(f, node);
  }
}
async function hydrateFavSub(f, node) {
  const sub = $('.row-title', node) && node;
  try {
    let text = null, cls = 'live', badgeLine = null;
    if (f.mode === 'tren') { const a = (await trainArrivals(f.id))[0]; if (a) text = etaText(a.secs) + (a.dest ? ' · a ' + a.dest : ''); }
    else if (f.mode === 'subte') { const a = (await subteArrivals(f.name))[0]; if (a) text = etaText(a.secs) + (a.dest ? ' · a ' + a.dest : ''); }
    else if (f.mode === 'bondi') { const a = (await bondiArrivals(f.id))[0]; if (a) { text = etaText(a.secs) + (a.live ? ' en vivo' : ' prog'); badgeLine = a.short; } }
    else if (f.mode === 'bici') { const sts = await biciStations(); const s = sts.find((x) => x.id === f.id); if (s) { text = s.bikes + ' bicis · ' + s.docks + ' anclajes'; } }
    if (text) {
      let subEl = $('.row-sub', node);
      if (!subEl) { subEl = el('div', 'row-sub live'); $('.row-main', node).appendChild(subEl); }
      subEl.className = 'row-sub ' + cls; subEl.textContent = text;
    }
    if (badgeLine) {
      const b = $('.badge', node); b.textContent = badgeLine; b.innerHTML = esc(badgeLine); b.style.background = busColor(badgeLine);
      const tg = $('.row-meta span', node); if (tg) tg.style.color = busColor(badgeLine);
    }
  } catch (e) {}
}

/* ─────────── Vista: Mapa ─────────── */
async function renderMapa() {
  track('screen_view', { screen_name: 'mapa' });
  const view = $('#view'); view.innerHTML = '';
  const wrap = el('div', 'fullmap-wrap');
  const mapNode = el('div'); mapNode.id = 'bigmap';
  wrap.appendChild(mapNode); view.appendChild(wrap);
  if (!S.loc) S.loc = await getLocation();
  const center = S.loc || { lat: -34.6037, lng: -58.3816 };
  const map = L.map(mapNode, { zoomControl: true, attributionControl: false }).setView([center.lat, center.lng], 15);
  S.map = map;
  osmLayer().addTo(map);
  if (S.loc) L.marker([S.loc.lat, S.loc.lng], { icon: userDivIcon() }).addTo(map);
  await loadCatalogs();
  if (S.loc) {
    S.trainCat.map((s) => ({ s, d: distM(S.loc, { lat: s.lat, lng: s.lng }) })).sort((a, b) => a.d - b.d).slice(0, 12).forEach(({ s }) => {
      const line = trainLine(s.gerenciaId);
      L.marker([s.lat, s.lng], { icon: stopDivIcon(line.color) }).addTo(map).on('click', () => go('board', { mode: 'tren', id: s.id, name: s.nombre, lat: s.lat, lng: s.lng }));
    });
    S.subteCat.map((s) => ({ s, d: distM(S.loc, { lat: s.lat, lng: s.lng }) })).sort((a, b) => a.d - b.d).slice(0, 12).forEach(({ s }) => {
      const line = subteLine(s.line);
      L.marker([s.lat, s.lng], { icon: stopDivIcon(line.color) }).addTo(map).on('click', () => go('board', { mode: 'subte', id: s.line + '-' + s.name, name: s.name, line: s.line, lat: s.lat, lng: s.lng }));
    });
  }
  setTimeout(() => map.invalidateSize(), 80);
}

/* ─────────── Componentes chicos ─────────── */
function spinner(msg) { const d = el('div', 'state'); d.appendChild(el('div', 'spinner')); if (msg) d.appendChild(el('div', null, esc(msg))); return d; }
function stateBox(title, msg, cta, onCta) {
  const d = el('div', 'state');
  d.appendChild(el('div', 'big', esc(title)));
  if (msg) d.appendChild(el('div', null, esc(msg)));
  if (cta) { const b = el('button', 'cta', esc(cta)); b.onclick = onCta; d.appendChild(b); }
  return d;
}
function footerNote() {
  return el('div', 'footer-note', 'Prototipo, sin garantía. Datos de Trenes Argentinos, SUBE/OneBusAway y GCBA.<br>Hecho por Alan Daitch + Claude.');
}

/* ─────────── Init ─────────── */
document.querySelectorAll('.tab').forEach((t) => { t.onclick = () => go(t.dataset.view); });
document.querySelectorAll('.tab-ico').forEach((s) => { s.innerHTML = SVG[s.dataset.ico] || ''; });
$('#backBtn').onclick = () => { if (history.length > 1) history.back(); else go('cerca'); };
initGA();
if ('serviceWorker' in navigator) window.addEventListener('load', () => navigator.serviceWorker.register('sw.js').catch(() => {}));
route();
