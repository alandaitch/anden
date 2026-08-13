# API Transporte Buenos Aires (Ciudad) — referencia para Andén

Base: `https://apitransporte.buenosaires.gob.ar`
Auth: query string `?client_id=<id>&client_secret=<secret>`. Key gratis en `api-transporte.buenosaires.gob.ar`.
Verificado en vivo el 13-ago-2026 con key real. La key vive en `Anden/Resources/Secrets.plist` (gitignored), leída por `BASecrets`.

## Subte — arribos en vivo ✅
`GET /subtes/forecastGTFS?client_id=..&client_secret=..&json=1` → 200, JSON ~42 KB.

```json
{ "Header": {...},
  "Entity": [
    { "ID": "LineaA_A11",
      "Linea": {
        "Trip_Id": "A11", "Route_Id": "LineaA", "Direction_ID": 1,
        "start_time": "10:07:00", "start_date": "20260813",
        "Estaciones": [
          { "stop_id": "1059N", "stop_name": "San Pedrito",
            "arrival":   { "time": 1786627488, "delay": 180 },
            "departure": { "time": 1786627512, "delay": 204 } }
        ] } } ] }
```

- Cada `Entity` = un tren (viaje) con sus estaciones restantes.
- `Route_Id`: `LineaA`..`LineaE`, `LineaH`. `Direction_ID`: 0/1.
- `arrival.time`: epoch UTC (segundos). `arrival.delay`: segundos de demora.
- Trae `stop_name` inline → NO hace falta catálogo para el tablero.
- Para "próximos en estación X": recorré todas las `Entity`, buscá X en `Estaciones`, juntá `arrival.time`.
- Ojo: solo aparecen las líneas con trenes activos en ese momento (puede faltar C/H/Premetro). Mostrar "sin servicio ahora" si no hay data.

## Subte — estado de servicio ✅
`GET /subtes/serviceAlerts?client_id=..&client_secret=..&json=1` → 200, GTFS-rt JSON.

```json
{ "entity": [
  { "id": "Alert_LineaD",
    "alert": {
      "informed_entity": [{ "route_id": "LineaD" }],
      "cause": 2, "effect": 7,
      "header_text": { "translation": [{ "text": "Estación Tribunales cerrada por obras.", "language": "es" }] } } } ] }
```
- `effect` (GTFS-rt): 1 NO_SERVICE, 2 REDUCED_SERVICE, 4 SIGNIFICANT_DELAYS, 6 DETOUR, 7 OTHER_EFFECT, 8 STOP_MOVED...
- Texto en `header_text.translation[0].text`.

## EcoBici — GBFS ✅
`GET /ecobici/gbfs/stationInformation?client_id=..&client_secret=..` → 393 estaciones.
```json
{ "data": { "stations": [
  { "station_id": "2", "name": "002 - Retiro I", "lat": -34.5924, "lon": -58.3747,
    "capacity": 40, "address": "AV. ...", "groups": ["RETIRO"] } ] } }
```
`GET /ecobici/gbfs/stationStatus?client_id=..&client_secret=..` → estado en vivo.
```json
{ "data": { "stations": [
  { "station_id": "2", "num_bikes_available": 0, "num_docks_available": 39,
    "num_bikes_available_types": { "mechanical": 0, "ebike": 0 },
    "status": "IN_SERVICE", "last_reported": 1786627406 } ] } }
```
Join `stationStatus` con `stationInformation` por `station_id`.

## Colectivos (próxima ola)
`GET /colectivos/vehiclePositions` → 200, GTFS-rt **protobuf** (~1,5 MB). `&json=1` → JSON ~9,3 MB (pesado).
`GET /colectivos/vehiclePositionsSimple&json=1` → **500** (bug del server, no usar).
Requiere parsear protobuf o manejar 9 MB + catálogo de paradas (GTFS). Se difiere.

## Colores oficiales de subte (SBASE)
A `#00AEEF` · B `#EE3124` · C `#0072BC` · D `#00A650` · E `#8E44AD` · H `#FFD200` · Premetro `#00A19A`.
