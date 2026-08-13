# Colectivos AMBA — catálogos y API en vivo

Fecha de generación: 2026-08-13.

## 1. Fuente GTFS estático

- Dataset: `colectivos-gtfs` (CKAN Buenos Aires Data).
- `package_show?id=colectivos-gtfs` devuelve un solo recurso ZIP.
- URL: `https://cdn.buenosaires.gob.ar/datosabiertos/datasets/transporte-y-obras-publicas/colectivos-gtfs/colectivos-gtfs.zip`
- Tamaño: 209 MB. HTTP 200.
- **No hay variante liviana "por frecuencia".** El CKAN expone un único recurso.
- **`last_modified` del recurso: 2019-08-08.** Los archivos internos datan de 2019-09-30. El GTFS está congelado en 2019.

Archivos del ZIP:

| archivo | tamaño |
|---|---|
| routes.txt | 74 KB |
| stops.txt | 3.2 MB |
| trips.txt | 31 MB |
| shapes.txt | 29 MB |
| stop_times.txt | 1.4 GB |

Se extrajeron solo `routes.txt` y `stops.txt`.

`routes.txt` NO tiene columna `route_color`. Columnas reales:
`route_id, agency_id, route_short_name, route_long_name, route_desc, route_type`.

## 2. colectivos-lineas.json

Ruta: `Anden/Resources/colectivos-lineas.json`.

Formato: `[{routeId, shortName, longName}]`. Sin `color` (el GTFS no lo trae).

- 1052 líneas.
- Tamaño: 62 KB (minificado, sin espacios).
- Mapa `route_id` -> número de línea (`shortName`) para el mapa en vivo.

### Match con vehiclePositions (CRÍTICO — cobertura baja)

Muestra en vivo (2026-08-13):

- 15.193 vehículos totales en el feed.
- 10.526 con `trip`/`route_id` asignado.
- 1.800 `route_id` únicos en el feed.
- Solo **552 de 1.800** `route_id` existen en `routes.txt`.
- A nivel vehículo: solo **31,8%** de los vehículos con viaje matchean una línea del catálogo.

Causa: el GTFS estático es de 2019 y los `route_id` del feed en vivo (ej: `819`, `2182`, `2194`) ya no existen en ese catálogo. No hay GTFS más nuevo:

- El portal nacional (`datos.transporte.gob.ar`) no publica GTFS de colectivos (solo KML de recorridos, CSV de líneas).
- No existe fuente GTFS de colectivos AMBA más fresca que la de 2019.

Implicancia para la app: para el ~32% de coches se puede mostrar el número de línea vía catálogo. Para el resto, el feed trae un `label` en el `VehicleDescriptor` (ej: `107-70`) que NO es el número de línea confiable. Recomendación: mostrar el punto GPS siempre; el número de línea, solo cuando el `route_id` matchee el catálogo.

## 3. colectivos-paradas.json

Ruta: `Anden/Resources/colectivos-paradas.json`.

Formato: `[{code, name, lat, lng}]`. `code` = `stop_code` (o `stop_id` si falta). `stop_code` presente en todas.

- Bounding box AMBA: lat -35.1..-34.3, lng -59.1..-57.9.
- 43.594 paradas totales en `stops.txt` → **42.805 dentro del bbox** (789 descartadas fuera).
- Coords redondeadas a 5 decimales. JSON minificado.
- Tamaño: **3,73 MB** (bajo el objetivo de 8 MB).

Las paradas son estables (el `stop_code` no cambió), así que sirven para la feature "cuándo llega" aunque el GTFS sea de 2019.

## 4. forecastGTFS — "cuándo llega" por parada

Endpoint:

```
GET https://apitransporte.buenosaires.gob.ar/colectivos/forecastGTFS
    ?client_id=<CLIENT_ID>
    &client_secret=<CLIENT_SECRET>
    &StopCode=<stop_code>
    &json=1
```

Parámetro clave: `StopCode` = el `code` del catálogo de paradas.

### Estado hoy (2026-08-13): BACKEND CAÍDO (503)

Se probaron 4 stop_codes reales del centro (cerca del Obelisco): `20178` (1144 Av. Corrientes), `20538` (1041 Lavalle), `20177` (934 Av. Corrientes), `20560` (1060 Sarmiento). Todos, y en 3 reintentos, devolvieron:

```json
HTTP 503
{ "error": "HTTP GET on resource 'http://200.61.211.220:80//WebServiceForecasts/ServiceForecasts.asmx/GetForecastsGTFS' failed: No existe ninguna ruta hasta el `host'.", "message": "" }
```

Es una caída del backend SOAP interno de BA (`200.61.211.220`), NO un problema de auth ni de parámetros: el mismo `client_id/secret` devuelve 200 en `vehiclePositions`. Reintentar más tarde.

### Schema esperado de la respuesta

`forecastGTFS` es el mismo servicio SOAP que el de subte (`/subtes/forecastGTFS`), que sí responde. Estructura verificada del sibling (ver `ba-api.md`):

```json
{ "Header": { ... },
  "Entity": [
    { "ID": "...",
      "Linea": {
        "Trip_Id": "...", "Route_Id": "...", "Direction_ID": 0,
        "start_time": "10:07:00", "start_date": "20260813",
        "Estaciones": [
          { "stop_id": "20178", "stop_name": "1144 CORRIENTES AV.",
            "arrival":   { "time": 1786627488, "delay": 180 },
            "departure": { "time": 1786627512, "delay": 204 } }
        ] } } ] }
```

- Cada `Entity` = un viaje (un coche) con sus paradas restantes.
- `arrival.time`: epoch UTC en segundos. `arrival.delay`: segundos de demora.
- Para "próximos en parada X": recorrer `Entity`, buscar `X` en `Estaciones`, juntar `arrival.time`, restar `now` → minutos.
- `Route_Id` en la respuesta permite cruzar con `colectivos-lineas.json` para el número de línea (misma limitación de cobertura del punto 2).

**No se pudo guardar un ejemplo real de colectivos por la caída del backend.** El request está verificado; la respuesta está pendiente de que BA restablezca el host.

## 5. vehiclePositions — decodificar el protobuf en Swift sin librerías

Endpoint:

```
GET https://apitransporte.buenosaires.gob.ar/colectivos/vehiclePositions
    ?client_id=...&client_secret=...
```

- HTTP 200, `Content-Type: application/x-protobuf`, ~1,5 MB.
- Es un `FeedMessage` de GTFS-realtime.
- **Sin `json=1`**: este endpoint devuelve binario.

### Wire format (varint + LEN + fixed32/64)

Cada campo arranca con un byte de tag = `(field_number << 3) | wire_type`.
Wire types usados: `0`=varint, `1`=64-bit LE, `2`=length-delimited (varint largo + bytes), `5`=32-bit LE.

### Estructura anidada (tags exactos verificados hoy)

```
FeedMessage
├─ field 1 (tag 0x0A, LEN)  header        → dentro: field1(0x0A) gtfs_version "1.0", field3(0x18) timestamp
└─ field 2 (tag 0x12, LEN)  entity  [repetido]  ← iterar sobre TODOS los 0x12 del top level
     FeedEntity
     ├─ field 1 (tag 0x0A, LEN)  id (string, ej "1")
     └─ field 4 (tag 0x22, LEN)  vehicle = VehiclePosition
          VehiclePosition
          ├─ field 1 (tag 0x0A, LEN)  trip = TripDescriptor
          │     ├─ field 1 (tag 0x0A, LEN)  trip_id    (string, ej "67955-1")
          │     ├─ field 2 (tag 0x12, LEN)  start_time (string, ej "10:12:00")
          │     ├─ field 3 (tag 0x1A, LEN)  start_date (string, ej "20260813")
          │     ├─ field 5 (tag 0x2A, LEN)  route_id   (string, ej "819")  ← ESTE es el número interno de línea
          │     └─ field 6 (tag 0x30, varint) schedule_relationship
          ├─ field 2 (tag 0x12, LEN)  position = Position
          │     ├─ field 1 (tag 0x0D, fixed32 LE)  latitude   (float32)  ← struct '<f'
          │     ├─ field 2 (tag 0x15, fixed32 LE)  longitude  (float32)  ← struct '<f'
          │     ├─ field 3 (tag 0x1D, fixed32 LE)  bearing    (float32, opcional; puede faltar)
          │     └─ field 4 (tag 0x21, 64-bit LE)   odometer   (double, opcional; IGNORAR)
          ├─ field 5 (tag 0x28, varint)  timestamp (uint64, epoch s)
          └─ field 8 (tag 0x42, LEN)  vehicle = VehicleDescriptor  ← OJO: field 8, NO field 4
                ├─ field 1 (tag 0x0A, LEN)  id            (string, ej "2240" = interno)
                ├─ field 2 (tag 0x12, LEN)  label         (string, ej "107-70")
                └─ field 3 (tag 0x1A, LEN)  license_plate (string, ej "AG648HW" = patente)
```

### Correcciones a supuestos previos

- `entity.vehicle` = FeedEntity field **4**, tag **0x22** ✓ (confirmado).
- `VehicleDescriptor` (id/label/patente) vive en VehiclePosition field **8** (tag **0x42**), NO en field 4. El supuesto original ("vehicle id if there") apuntaba mal al slot.
- En Position, ojo con `0x21` (field 4, odometer, double 8 bytes): no es bearing. Bearing es `0x1D` (field 3, float32) y a veces no viene.
- `route_id` = TripDescriptor field 5, tag `0x2A`, string ✓ (confirmado, ej "819").

### Pseudocódigo Swift (sin dependencias)

```swift
// 1. Parser genérico de wire format sobre [UInt8]/Data con un cursor.
//    readVarint() -> UInt64 ; readTag() -> (field: Int, wire: Int)
// 2. Recorrer el top level. Por cada tag con field==2 && wire==2:
//    leer length (varint), tomar ese subrango = FeedEntity.
// 3. Dentro del FeedEntity, buscar field==4 && wire==2 = VehiclePosition (subrango).
// 4. Dentro de VehiclePosition:
//    - field 1 (LEN) = TripDescriptor: buscar field 5 (LEN) = route_id (String(bytes:.utf8)).
//    - field 2 (LEN) = Position: field 1 (0x0D) 4 bytes LE -> Float(bitPattern:) = lat;
//                                 field 2 (0x15) 4 bytes LE -> lng;
//                                 field 3 (0x1D) 4 bytes LE -> bearing (si aparece).
//    - field 5 (varint) = timestamp.
//    - field 8 (LEN) = VehicleDescriptor: field 1 = interno, field 2 = label, field 3 = patente.
// 5. Float LE: UInt32(bytes little-endian) -> Float(bitPattern:). Data ya viene LE.
```

Los campos LEN pueden aparecer en cualquier orden y algunos faltar: no asumir posición fija, siempre leer por tag y saltar los tags desconocidos según su wire type.

## Riesgos y limitaciones

1. **Cobertura de línea baja (~32%)**: el GTFS es de 2019; la mayoría de los `route_id` en vivo no están en el catálogo. No hay fuente más nueva.
2. **forecastGTFS caído hoy (503)**: backend SOAP de BA sin ruta al host. Request verificado, respuesta real pendiente.
3. **Sin colores de línea**: `routes.txt` no trae `route_color`. Definir paleta propia en la app.
4. **Paradas 2019**: los `stop_code` son estables; alguna parada pudo cambiar, pero sirve como catálogo base.
5. **Tamaño paradas 3,73 MB**: aceptable embebido. Si molesta, filtrar a un bbox más chico (CABA + primer cordón).
