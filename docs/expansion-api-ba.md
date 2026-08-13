# API Transporte GCBA — expansión de Andén

Base: `https://apitransporte.buenosaires.gob.ar`
(alias histórico `api-transporte.buenosaires.gob.ar`, mismo servicio).

Todo lo marcado "verificado" se probó con `curl` el **13 de agosto de 2026**.
Distingo "verificado con curl" de "documentado / usado por terceros pero sin key".

Hoy Andén usa solo la API de SOFSE (Trenes Argentinos). Esta es OTRA API, del
Gobierno de la Ciudad. Cubre colectivos, subte, Ecobici y tránsito.

---

## 1. Resumen

La API es un gateway (MuleSoft). Requiere `client_id` + `client_secret` en el
**query string**. Sin credenciales válidas todo devuelve `401`.

### Namespaces (verificado con curl)

| Namespace | HTTP sin key | Estado |
|---|---|---|
| `/colectivos/` | 401 | Existe. Auth-gated. |
| `/subtes/` | 401 | Existe. Auth-gated. |
| `/ecobici/` | 401 | Existe. Auth-gated. |
| `/transito/` | 401 | Existe. Auth-gated. |
| `/trenes/` | 404 | **No existe** en este dominio. |
| `/metrovias/` | 404 | **No existe**. |
| `/bici/` | 404 | No existe (es `/ecobici/`). |

Nota dura: el namespace está gateado ANTES de rutear. `/colectivos/xyzNoExiste`
también da 401. Por eso `curl` sin key confirma el **namespace**, no el sub-path
exacto. Los sub-paths de abajo salen de código real de terceros que los usa
(notebooks datosgcba, pipeline ELT_GTFS) más el namespace vivo.

### Auth verificada con dos respuestas distintas

| Request | HTTP | Body |
|---|---|---|
| Sin `client_id` | 401 | `{"error": "Authentication denied."}` |
| `client_id=fake&client_secret=fake` | 401 | `{"error": "Invalid Client"}` |

Los dos mensajes distintos confirman que el gateway valida las credenciales.
La API está **viva** (no es una página de mantenimiento).

---

## 2. Tabla de endpoints

Auth = `?client_id=...&client_secret=...` en todos.
`Estado`: VERIF = namespace confirmado 401 con curl hoy; el sub-path viene de
código de terceros que lo llama en producción.

| Modo | Ruta | Método | Formato | Cobertura | Estado |
|---|---|---|---|---|---|
| Colectivos | `/colectivos/vehiclePositions` | GET | GTFS-rt protobuf (`json=0`) o JSON (`json=1`) | GPS de todas las líneas del AMBA con GPS activo | VERIF (namespace 401) + usado por ELT_GTFS |
| Colectivos | `/colectivos/vehiclePositionsSimple` | GET | JSON | idem, formato plano | VERIF (401) |
| Colectivos | `/colectivos/forecastGTFS` | GET | GTFS-rt protobuf / JSON | "cuándo llega" por viaje | VERIF (401) |
| Colectivos | `/colectivos/tripUpdates` | GET | GTFS-rt protobuf | actualización de arribos por viaje | VERIF (401) |
| Colectivos | `/colectivos/serviceAlerts` | GET | GTFS-rt protobuf | alertas de servicio | VERIF (401) |
| Colectivos | `/colectivos/oba/arrivals-and-departures-for-stop/{stopId}` | GET | JSON (OneBusAway) | "cuándo llega" por parada | VERIF (401) + usado por notebook datosgcba |
| Subte | `/subtes/forecastGTFS` | GET | GTFS-rt protobuf / JSON | arribos por estación, líneas A–H | VERIF (401) |
| Subte | `/subtes/serviceAlerts` | GET | GTFS-rt protobuf | estado de servicio / interrupciones | VERIF (401) |
| Subte | `/subtes/tripUpdates` | GET | GTFS-rt protobuf | arribos por viaje | VERIF (401) |
| Ecobici | `/ecobici/gbfs/gbfs` | GET | GBFS JSON | índice de feeds GBFS | VERIF (401) |
| Ecobici | `/ecobici/gbfs/stationInformation` | GET | GBFS JSON | estaciones (id, nombre, lat/lon, capacidad) | VERIF (401) + usado por Rmd datosgcba |
| Ecobici | `/ecobici/gbfs/stationStatus` | GET | GBFS JSON | bicis y anclajes libres en vivo | VERIF (401) |
| Ecobici | `/ecobici/gbfs/systemInformation` | GET | GBFS JSON | metadata del sistema | VERIF (401) |
| Tránsito | `/transito/v1/estacionamientos` | GET | JSON | estacionamiento medido | Documentado (namespace 401), sub-path no reprobado hoy |

Formato de colectivos confirmado por código real: el pipeline `ELT_GTFS`
(`functions.py`) llama `GET /colectivos/{endpoint}` con
`params={client_id, client_secret, json:0}` y parsea la respuesta con
`gtfs_realtime_pb2.FeedMessage()`. O sea `json=0` = protobuf GTFS-realtime,
`json=1` = JSON.

### Ejemplos de respuesta reales (recortados)

Sin key:
```json
{ "error": "Authentication denied." }
```
Key inválida:
```json
{ "error": "Invalid Client" }
```
(No tengo key, así que no puedo pegar un feed 200. Los feeds 200 son GTFS-rt
protobuf o su espejo JSON con `entity[].vehicle.position.latitude/longitude`.)

---

## 3. El caso Urquiza (clave para Andén)

Andén hoy NO da Urquiza. Confirmado por qué:

- SOFSE **lista** la línea Urquiza en su catálogo, pero con
  `estacionesEnApi: 0` y `expuestaEnGerencias: false`. O sea: la conoce pero
  **no expone estaciones ni arribos**. No sirve.
- En esta API del GCBA, `/trenes/` y `/metrovias/` dan **404**. No hay feed de
  trenes acá.
- La Urquiza la opera Metrovías, igual que el subte. Pero es un **ferrocarril**,
  no está en el namespace `/subtes/`. El feed `/subtes/forecastGTFS` cubre las
  líneas de subte A–H (y típicamente el Premetro como línea del sistema SBASE).
  **No pude confirmar con curl que Urquiza esté en el feed de subtes** (hace
  falta key para leer el contenido). Hay que verificarlo con una key real:
  pedir `/subtes/forecastGTFS` y buscar route/agency Urquiza.

Conclusión honesta: la Urquiza en tiempo real **no está garantizada** por
ninguna de las dos APIs públicas probadas hoy. Plan: al conseguir key, leer
`/subtes/serviceAlerts` y `/subtes/forecastGTFS` y confirmar si aparece.
Si no aparece, Urquiza queda como GTFS estático (recorrido + horarios), sin vivo.

### Premetro

Mismo criterio: probablemente dentro del sistema SBASE en `/subtes/` (línea P /
E2). No confirmado sin key. Verificar leyendo el feed.

---

## 4. GTFS estático (paradas, recorridos, horarios)

Estado **crítico y verificado hoy**: los datasets GTFS del portal
`data.buenosaires.gob.ar` están **SUSPENDIDOS**. La página dice literal:
"todos los datasets con Formato API y GTFS están suspendidos. Se encuentran en
revisión y corrección."

| Dataset | URL | Estado hoy |
|---|---|---|
| Colectivos: GTFS | `data.buenosaires.gob.ar/dataset/colectivos-gtfs` | SUSPENDIDO |
| Subte: GTFS | `data.buenosaires.gob.ar/dataset/subte-gtfs` | SUSPENDIDO |
| Trenes: GTFS | `data.buenosaires.gob.ar/dataset/trenes-gtfs` | SUSPENDIDO (asumido, mismo aviso global) |
| Colectivos: GTFS Frequency | `data.buenosaires.gob.ar/dataset/colectivos-gtfs-frequency` | SUSPENDIDO |

OJO: el GTFS **estático** está caído, pero la API **realtime** (`/colectivos/`,
`/subtes/`) responde 401 (viva). Son dos sistemas separados.

### Fallback nacional (verificado hoy)

`datos.transporte.gob.ar` (Secretaría de Transporte) tiene:
- "Recorridos de Líneas de Transporte RMBA" (shapefile + otros formatos) —
  descargable.
- "Líneas y Empresas de transporte urbano RMBA - SUBE" (CSV).

No son GTFS limpio. No encontré un GTFS ferroviario con Urquiza ahí. Sirve para
recorridos/geometría, no para horarios GTFS estándar.

---

## 5. Cómo se sacan las keys

- Registro: `https://www.buenosaires.gob.ar/form/formulario-de-registro-api-transporte`
  (link sacado del propio código de datosgcba).
- Portal: `https://www.buenosaires.gob.ar/desarrollourbano/transporte/apitransporte`
- Doc: `.../apitransporte/api-doc`
- Contacto: `apitransporte@buenosaires.gob.ar`
- Entregan un par `client_id` + `client_secret`. Se mandan por query string.
- Es gratis y abierto al público (Google y Moovit consumen esta API).
- Rate limits / términos de uso: **no verificados** (no me registré). Hay que
  leerlos en el portal al pedir la key.

**No me registré** (sin permiso). Documenté el flujo, probé los endpoints sin
key y confirmé 401. Falta: completar el formulario para obtener el par de
credenciales.

---

## 6. Qué desbloquea para Andén

Andén hoy = solo trenes SOFSE. Con esta API suma:

1. **Subte en vivo.** `/subtes/forecastGTFS` da "cuándo llega" por estación,
   líneas A–H. Es el salto más grande. Andén pasa de trenes a trenes+subte.
2. **Estado del subte.** `/subtes/serviceAlerts` da interrupciones y demoras.
   Banner de servicio por línea. Bajo esfuerzo, alto impacto.
3. **Colectivos "cuándo llega".** `/colectivos/oba/arrivals-and-departures-for-stop/{stopId}`
   da arribos por parada. Es el caso de uso más pedido en CABA/AMBA.
4. **Mapa de colectivos en vivo.** `/colectivos/vehiclePositions` da GPS de toda
   flota con equipo activo. Pantalla de mapa con bondis moviéndose.
5. **Ecobici.** `/ecobici/gbfs/stationStatus` + `stationInformation` dan bicis y
   anclajes libres por estación. Feature independiente y liviana (GBFS estándar,
   sin protobuf). Buen primer paso para probar la key.
6. **Urquiza (condicional).** Si aparece en `/subtes/*`, Andén cierra el hueco
   que SOFSE no cubre. Hay que confirmarlo con key.

Prioridad sugerida por esfuerzo/impacto:
- Rápido y seguro: Ecobici (GBFS JSON, sin protobuf).
- Alto impacto: subte forecast + serviceAlerts.
- Medio: colectivos por parada (OBA JSON).
- Más pesado: mapa de colectivos (parsear GTFS-rt protobuf).

### Deuda técnica a resolver antes

- Conseguir `client_id`/`client_secret` (Alan completa el formulario).
- Parsear GTFS-realtime protobuf en Swift (los colectivos vienen así por
  default; `json=1` evita el protobuf pero conviene medir peso/latencia).
- GTFS estático suspendido: para nombres de paradas/recorridos de colectivos hay
  que esperar que vuelva el dataset o usar los recorridos nacionales (shapefile).
- Confirmar Urquiza y Premetro leyendo el feed con key real.
