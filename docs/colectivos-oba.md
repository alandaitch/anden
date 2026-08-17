# Colectivos "cuándo llega" — API OneBusAway (cuandosubo/SUBE)

Fuente que SÍ funciona para arribos de colectivo en vivo (reemplaza la API de la Ciudad, que estaba caída/incompleta). Es la misma que usa la webapp oficial `cuandosubo.sube.gob.ar`. Verificado en vivo hoy.

- **Base**: `https://cuandosubo.sube.gob.ar/onebusaway-api-webapp/api/where`
- **Key**: `web` (query param `?key=web`). Es una key PÚBLICA de la webapp (sale del cliente), no un secreto personal. Se puede embeber en la app. Con `key=org.onebusaway.iphone` o `key=TEST` da 401.
- Cobertura: TODO el país (AMBA incluido). Formato JSON estándar OneBusAway REST v1.
- IDs con prefijo de agencia: `14_2032012` = agencia 14, stop 2032012. `5_1437` = ruta.

## Endpoints

### Líneas cercanas — `routes-for-location`
`GET /routes-for-location.json?key=web&lat=-34.6037&lon=-58.3816&radius=600`
→ `data.list: [{ id, shortName, longName, ... }]`. Ej: 96 líneas cerca del Obelisco (132A, 98F, 6A...). Da las líneas, sin horarios.

### Paradas cercanas — `stops-for-location`
`GET /stops-for-location.json?key=web&lat=..&lon=..&radius=300`
→ `data.list: [{ id, code, name, lat, lon, direction, routeIds:[...] }]`.

### Cuándo llega (por parada) — `arrivals-and-departures-for-stop` ✅ EL BUENO
`GET /arrivals-and-departures-for-stop/{stopId}.json?key=web`
→ `data.entry.arrivalsAndDepartures: [ {...} ]`. Campos de cada arribo:
- `routeShortName` (nº de línea, "8C"), `routeLongName`, `routeId`
- `tripHeadsign` (destino, "a La Boca")
- `predicted` (bool: hay dato en vivo), `predictedArrivalTime` (ms epoch, 0 si no hay)
- `scheduledArrivalTime` (ms epoch, siempre presente)
- `distanceFromStop` (metros; negativo = ya pasó), `numberOfStopsAway`
- `tripStatus` (posición del coche en el recorrido), `stopId`
Minutos = `((predicted? predictedArrivalTime : scheduledArrivalTime)/1000 - now)/60`. VIVO si `predicted`.

Verificado: parada 14_2032012 (Yrigoyen 1132) devolvió 8A→Aeroparque en 16 min VIVO, 8C→La Boca prog, etc.

## Cómo armar "LÍNEAS cercanas con cuándo llega" (lo que pide la UI)
1. `stops-for-location` alrededor del usuario (radius ~500 m).
2. Para las ~8-12 paradas más cercanas, `arrivals-and-departures-for-stop`.
3. Juntar todos los arribos, agrupar por `routeShortName` + `tripHeadsign`.
4. Por cada (línea, destino) quedarse con el próximo arribo futuro (descartar los de `distanceFromStop<0` / minutos<0 salvo "llegando").
5. Ordenar por minutos. Cada fila = línea + destino + "en X min" (VIVO/prog) + parada (nombre + coord para "Ir").

## Notas
- Puede tirar 0 arribos en paradas tranquilas o de madrugada: probar varias paradas.
- Hacer las llamadas por parada en paralelo (con límite) y timeout ~15 s.
- Rate limit no medido; cachear ~30 s y no spamear.
