# Expansión nacional de Andén — fuentes de datos

Todo lo de este documento se probó con `curl` el **13 de agosto de 2026**.
Cada afirmación dice si viene de una prueba real o de documentación de terceros.

---

## 1. Respuesta directa: ¿se puede cerrar el gap de Belgrano Norte y Urquiza?

**No en tiempo real. Sí en horario estático parcial.**

- Ninguna fuente pública da GPS en vivo de Belgrano Norte ni de Urquiza.
- Ferrovías y Metrovías no publican API ni GTFS.
- El Ministerio de Transporte nacional sí tiene las 45 estaciones de las dos
  líneas, con coordenadas. Confirmado hoy con `curl`.
- Ese dataset no trae horarios. Solo ubicación de estaciones.
- Conclusión: se puede agregar Belgrano Norte y Urquiza al mapa y al buscador
  de Andén. No se puede dar "próximo tren" para esas dos líneas.
- Alternativa de horario: cargar los horarios publicados en PDF por Ferrovías
  y Metrovías a mano. Es horario fijo, no ajusta por demora real.

---

## 2. El dominio `apitransporte.transporte.gob.ar` no existe

Verificado hoy con `curl` y con `dig` contra dos resolvers distintos:

```
$ dig @8.8.8.8 apitransporte.transporte.gob.ar
;; ->>HEADER<<- opcode: QUERY, status: NXDOMAIN
```

`NXDOMAIN` autoritativo. No es un bloqueo de red local. El dominio no fue
registrado nunca, o se dio de baja.

### La confusión: hay dos APIs distintas con nombre parecido

| Dominio | Quién lo opera | Alcance | Estado hoy |
|---|---|---|---|
| `apitransporte.transporte.gob.ar` | — | — | **No existe** (NXDOMAIN) |
| `apitransporte.buenosaires.gob.ar` | Gobierno de la Ciudad (GCBA) | Colectivos, subte, tránsito, ecobici de CABA | Existe. Responde 401 sin token |
| `datos.transporte.gob.ar` | Ministerio de Transporte nacional | Datasets estáticos (CSV, SHP, GeoJSON, KML) | Existe. Sin API en vivo |

"API Transporte" es un producto de la **Ciudad de Buenos Aires**, no del
Ministerio de Transporte nacional. El Ministerio nacional solo publica
datasets estáticos en `datos.transporte.gob.ar`. No tiene una API de
tiempo real propia y separada.

---

## 3. La API real de colectivos en vivo: `apitransporte.buenosaires.gob.ar`

### Verificación sin token

```
$ curl -i https://apitransporte.buenosaires.gob.ar/colectivos/vehiclePositions
HTTP/2 401
{"error": "Authentication denied."}

$ curl -i https://apitransporte.buenosaires.gob.ar/bicicletas
HTTP/2 404
No listener for endpoint: /bicicletas
```

| Endpoint probado | Código | Lectura |
|---|---|---|
| `/colectivos` | 401 | Existe. Pide auth |
| `/colectivos/vehiclePositions` | 401 | Existe. Pide auth |
| `/colectivos/tripUpdates` | 401 | Existe. Pide auth |
| `/colectivos/serviceAlerts` | 401 | Existe. Pide auth |
| `/subtes` | 401 | Existe. Pide auth |
| `/transito` | 401 | Existe. Pide auth |
| `/ecobici` | 401 | Existe. Pide auth |
| `/bicicletas` | 404 | No existe con ese nombre |
| `/trenes` | 404 | No existe |

El formato de la familia `/colectivos` es **GTFS-Realtime** (protobuf):
`vehiclePositions`, `tripUpdates`, `serviceAlerts`. Son los tres feeds
estándar de GTFS-RT, no invento de la Ciudad.

### Cómo se consigue `client_id` / `client_secret`

**No me registré. Regla dura del pedido.** Esto es lo que documenté sin
crear cuenta:

1. Formulario de alta en `https://api-transporte.buenosaires.gob.ar/`
   (confirmado: la página carga, es una app Angular llamada
   "FormularioTransporte").
2. Según fuentes de terceros (no verificado por mí con cuenta real): a los
   minutos llega un mail con `client_id` y `client_secret`.
3. Las llamadas llevan `client_id` y `client_secret` como **query string**,
   no como header. Esto es documentación de terceros, no probado hoy.
4. Contacto de soporte publicado: `apitransporte@buenosaires.gob.ar`.

### Gotcha: el propio portal dice que está "suspendido"

El dataset `api-transporte-publico` en `data.buenosaires.gob.ar` trae esta
nota, verificada hoy:

> "Se informa a los usuarios de BA DATA que todos los datasets con Formato
> API y GTFS, están suspendidos. Se encuentran en revisión y corrección."

Pero el endpoint respondió 401 con mensaje de auth normal, no con un error
de servicio caído. La nota puede estar desactualizada. No hay forma de
confirmar el estado real sin una key válida.

### Relación con "Cuándo SUBO" (la app nacional de "SUBE-GPS")

Lo que el pedido llama "SUBE-GPS" es la app nacional **Cuándo SUBO**
(Nación Servicios / Ministerio de Transporte). Combina el GPS de los
validadores SUBE a bordo con el sistema de monitoreo satelital. Cubre
más de 250 líneas en AMBA.

Según fuentes de terceros: Cuándo SUBO consume la misma **API Transporte
de la Ciudad** (`apitransporte.buenosaires.gob.ar`), no una API nacional
aparte. No hay una API pública separada de "SUBE-GPS" a nivel nacional.

### Relación con la API de SOFSE que usa Andén

**Ninguna.** Son dos sistemas sin relación:

- SOFSE (`api-servicios.sofse.gob.ar`) es de la empresa operadora de
  trenes nacional. Sin token para arribos, con token para catálogo.
- API Transporte (`apitransporte.buenosaires.gob.ar`) es de la Ciudad.
  Cubre colectivos, subte, tránsito y ecobici de CABA. Con token siempre.

No comparten auth, ni dominio, ni formato de respuesta.

---

## 4. Belgrano Norte y Urquiza en detalle

### Ferrovías (Belgrano Norte) y Metrovías (Urquiza): sin API, sin GTFS

Búsqueda hecha hoy. No encontré:

- Ningún endpoint de GTFS-RT público de ninguna de las dos empresas.
- Ningún GTFS estático publicado por Ferrovías o Metrovías.
- Ninguna sección de "desarrolladores" en `ferrovias.com.ar` ni en
  `metrovias.com.ar`.

Las apps que muestran "tiempo real" de estas líneas (Belgrano Norte
Horarios, Línea Belgrano Norte, Horarios Urquiza, belgranito.ar,
trenurquiza.com.ar) son proyectos de terceros. Revisé `belgranito.ar`
y `trenurquiza.com.ar` hoy: publican horarios fijos, sin llamada a
ninguna API en el HTML servido. Son tablas estáticas, no tiempo real.

### El Ministerio nacional SÍ tiene las estaciones (no los horarios)

Dataset `estaciones-de-trenes-y-servicios-activos-a-2022`, servido por
`ide.transporte.gob.ar` (WFS, GeoServer). Probado hoy con `curl`:

```
GET https://ide.transporte.gob.ar/geoserver/idera/ows?service=WFS&version=1.0.0
    &request=GetFeature&typeName=idera:Estacion_ffcc_serv_22.view
    &maxFeatures=927&outputFormat=csv
```

Respuesta real (recortada), confirmando cobertura de las dos líneas:

```csv
id,nam,línea,caa,long,lat
265,Retiro,Belgrano Norte,Ferrovías,-58.3741911,-34.5901392
277,Villa Rosa,Belgrano Norte,Ferrovías,-58.8715367,-34.4165742
296,Lourdes,Urquiza,Metrovías,-58.5470093,-34.5937534
```

- **23 estaciones** de Belgrano Norte, columna `caa` = `Ferrovías`.
- **22 estaciones** de Urquiza, columna `caa` = `Metrovías`.
- Sin token. Formato CSV, GeoJSON, SHP, todos probados hoy.
- Metadata dice actualizado a 2022. Las estaciones no se mudan, pero no
  asumas que refleja obras nuevas.

El mismo geoserver expone la geometría de las **líneas** (no solo
estaciones) en el dataset `recorridos-de-lineas-de-transporte-rmba-jn`.
Confirmé hoy que el recorrido de Belgrano Norte está en el GeoJSON
`Ferrocarril - Líneas`. El de Urquiza no aparece en esa capa de líneas,
solo en la de estaciones.

### Qué feature se puede construir con esto

- Agregar las 45 estaciones al mapa de Andén, con ícono distinto
  ("sin datos en vivo").
- Buscador: que aparezcan al buscar "Villa Rosa" o "Lacroze", con aviso
  de que no hay arribos en vivo.
- Horario estático manual: transcribir la grilla de Ferrovías/Metrovías
  a un JSON propio. Es trabajo manual, no una fuente de datos.
- **No** hacer countdown ni demora para estas dos líneas. No hay dato
  fuente.

---

## 5. GTFS estático nacional y AMBA — qué hay y qué tan vigente está

### El portal nacional: `datos.transporte.gob.ar`

CKAN 2.7.6. Probado hoy con la API pública:

```
GET https://datos.transporte.gob.ar/api/3/action/package_list
```

Devolvió **46 datasets**. Sin token, sin límite detectado. Los relevantes
para Andén:

| Dataset | Formato | Contenido |
|---|---|---|
| `estaciones-de-trenes-y-servicios-activos-a-2022` | WFS/CSV/GeoJSON/SHP | Estaciones de **todas** las líneas de trenes, incluidas BN y Urquiza |
| `recorridos-de-lineas-de-transporte-rmba-jn` | SHP/GeoJSON/KML | Recorridos de colectivos, subte y trenes de RMBA por jurisdicción |
| `lineas-de-transporte-de-rmba` | CSV | Empresas de colectivos por jurisdicción (nacional/provincial/municipal) |
| `recorridos-de-servicios-de-colectivos-amba` | KML | Recorrido por línea de colectivo |
| `sube-*` (7 datasets) | CSV/XLSX | Estadísticas agregadas de uso. No sirven para saldo individual |
| `sistema-ferroviario-integrado-sifer` | XLSX | Subsidios, no operación |

Ninguno de estos es GTFS-RT ni tiene coordenadas de vehículos en vivo.
Son todos estáticos.

### Los tres GTFS "oficiales" están vencidos por dentro

Los tres GTFS más completos (trenes, colectivos, subte) están alojados en
`data.buenosaires.gob.ar`, no en el portal nacional. Los descargué y
abrí los tres hoy.

**Hallazgo importante: la fecha "modified" del portal miente.** Los tres
dicen `modified: 2026-07-01` en el catálogo. Pero el `calendar.txt` de
adentro tiene vigencias vencidas hace años:

| GTFS | "Modified" del portal | Vigencia real (`calendar`/`feed_info`) | Gap |
|---|---|---|---|
| `trenes-gtfs` | 2026-07-01 | 2020-02-01 a 2020-04-30 | **+6 años vencido** |
| `colectivos-gtfs` | 2026-07-01 | Solo fechas de 2019 (`calendar_dates`) | **+6 años vencido** |
| `subte-gtfs` | 2026-07-01 | 2014-05-01 a 2019-12-31 | **+6 años vencido** |

El "modified" del portal es solo un re-publicado del archivo, no una
actualización de contenido. **No uses el `calendar` de estos GTFS para
horarios reales.** Sirven para topología: estaciones, paradas, recorridos,
formas de línea. Eso cambia poco. Los horarios de adentro, no sirven.

### `trenes-gtfs`: 27 rutas, todas SOFSE. Ni BN ni Urquiza

```
$ cat trenes-gtfs/agency.txt
agency_id,agency_name,agency_url,...
TrenesArgentinos,Trenes Argentinos,https://www.trenesargentinos.gob.ar,...
```

27 rutas en `routes.txt`. Las 27 son ramales de SOFSE (Sarmiento, Mitre,
Roca, Belgrano Sur, San Martín, Tren de la Costa). **No hay ninguna ruta
de Belgrano Norte ni de Urquiza.** Coincide con lo que ya sabía Andén.

### `colectivos-gtfs`: mucho más grande de lo que parece por el nombre

Este es el hallazgo más útil del día para la parte de colectivos. Aunque
está alojado en el portal de la Ciudad, **es de alcance nacional**:

- 209 MB, 1.052 rutas, 43.594 paradas, 436.407 filas de `stop_times`.
- `agency_url` de cada empresa apunta a `argentina.gob.ar/cnrt`
  (Comisión Nacional de Regulación del Transporte — organismo
  **nacional**, no de la Ciudad).
- Rango geográfico real (medido hoy sobre `stops.txt`): latitud
  -35.18 a -34.04, longitud -60.97 a -57.73. Cubre Buenos Aires
  provincia mucho más allá de CABA: aparecen San Francisco Solano,
  Burzaco, Adrogué, Glew.
- Tiene horarios reales por parada en `stop_times.txt` (no solo
  frecuencias), aunque el `calendar_dates` es de 2019.

Es la fuente estática más completa de colectivos AMBA que encontré.
Sirve para recorridos y paradas. No sirve para el horario exacto.

### `subte-gtfs`: incluye Premetro, pero es de 2018-2020

```
$ cat subte-gtfs/routes.txt
route_id,...,route_short_name,...,route_type
LineaA,...,A,...,1
...
LineaH,...,H,...,1
PM-Civico,...,PM-C,...,0
PM-Savio,...,PM-S,...,0
```

Las 6 líneas de subte (A-E, H) y las 2 ramas de **Premetro** (PM-Civico,
PM-Savio) están. `feed_info.txt` dice `feed_end_date: 20191231`. Los
archivos internos tienen fechas de modificación de 2018 a 2020. Sirve
para topología de estaciones y líneas. No para horarios ni frecuencias
actuales.

### Cobertura consolidada por modo

| Modo | Fuente estática con curl hoy | Vigencia de horarios | Tiempo real |
|---|---|---|---|
| Trenes SOFSE (7 líneas) | `trenes-gtfs` + API SOFSE (ya en Andén) | API SOFSE: hoy. GTFS: vencido | Sí, vía API SOFSE |
| Belgrano Norte | Dataset de estaciones nacional | No hay fuente de horario | No |
| Urquiza | Dataset de estaciones nacional | No hay fuente de horario | No |
| Subte + Premetro | `subte-gtfs` | Vencido (2019) | No confirmado (requiere key de API Transporte) |
| Colectivos AMBA | `colectivos-gtfs` (1.052 rutas) | Vencido (2019) | No confirmado (requiere key de API Transporte) |
| Ecobici | — | — | Endpoint existe (`/ecobici`, 401). No probado con key |

---

## 6. SUBE: saldo y tarifas

### No hay API pública de saldo

Búsqueda hecha hoy. No existe un endpoint documentado ni oficial para
consultar saldo de una tarjeta SUBE por número. Los canales oficiales
son todos de cara a persona, no de API:

| Canal | Cómo funciona |
|---|---|
| Web `argentina.gob.ar/sube` → "Mi SUBE" | Login con PIN de 4 dígitos. Sin API pública detrás |
| Teléfono 0800-777-7823 | IVR, lee el saldo por voz |
| WhatsApp +54 9 11 6677-7823 | Bot que responde al mandar el número de tarjeta |
| Terminales automáticas | Apoyar la tarjeta físicamente |

Ninguno de estos cuatro es apto para integrar en Andén. Todos requieren
el número de tarjeta física de cada usuario, no hay endpoint anónimo.

### Tarifas

No encontré dataset ni API de tarifas vigentes. Ni en
`datos.transporte.gob.ar` (0 resultados buscando "tarifa") ni como
página fija en `argentina.gob.ar`. Las tarifas se publican por
resolución y cambian seguido. Para mostrarlas en Andén, hay que
cargarlas a mano y tener un proceso de actualización manual.

---

## 7. Alertas oficiales y estado del servicio

### `trenesargentinos.gob.ar` redirige

```
$ curl -I https://www.trenesargentinos.gob.ar/
HTTP/1.1 301
Location: https://www.argentina.gob.ar/trenes-argentinos-operaciones
```

Ese redirect encadena hasta `argentina.gob.ar/transporte/trenes-argentinos`.
Es una página institucional. No tiene RSS ni feed de alertas. Las alertas
reales de SOFSE ya las cubre Andén vía `/infraestructura/gerencias` y
`/infraestructura/ramales` (ver `api-reference.md`, sección 8).

### Redes sociales: no hay atajo confiable

Probé `nitter.net/TrenesArg` hoy: devolvió 200 pero body vacío (0 bytes).
Las instancias públicas de Nitter son inestables, no sirven como fuente
de producción. No hay RSS oficial de @TrenesArg. Leer redes sociales de
forma automática necesita la API oficial de X, de pago, o scraping
frágil. No lo recomiendo para Andén.

### Conclusión de alertas

La única fuente de alertas confiable y ya probada sigue siendo la API de
SOFSE que Andén ya usa. Para Belgrano Norte, Urquiza y colectivos, no
encontré ningún feed de alertas público y estable.

---

## 8. Recetas: qué agregar y con qué costo

| Feature | Fuente | Costo | Esfuerzo |
|---|---|---|---|
| Estaciones de Belgrano Norte y Urquiza en el mapa | WFS nacional (sin token) | Ninguno | Bajo. Descargar CSV una vez, embeber como JSON |
| Buscador incluye BN y Urquiza | Mismo dataset | Ninguno | Bajo |
| Horario fijo de BN y Urquiza | Transcripción manual de PDFs de Ferrovías/Metrovías | Trabajo manual | Medio. Sin fuente que mantenerlo actualizado sola |
| Colectivos: recorridos y paradas en el mapa | `colectivos-gtfs` (sin token) | Ninguno | Medio. 209 MB, hay que filtrar por zona |
| Colectivos en tiempo real ("cuándo llega") | API Transporte GCBA, con `client_id`/`client_secret` | Registro (no hecho, por regla dura) | Alto. Requiere alta + probar vehiclePositions real |
| Subte + Premetro en tiempo real | Misma API Transporte GCBA | Igual que arriba | Alto |
| Saldo SUBE en la app | No existe fuente pública | — | No viable |
| Tarifas vigentes | No existe fuente pública | — | Carga manual, mantenimiento manual |

---

## Fuentes

- Todos los endpoints con `curl` desde esta máquina, 13-ago-2026.
- `datos.transporte.gob.ar` — API CKAN 3, sin token.
- `data.buenosaires.gob.ar` — API CKAN 3, sin token.
- `ide.transporte.gob.ar` — GeoServer WFS, sin token.
- `apitransporte.buenosaires.gob.ar` — probado sin token, solo para
  confirmar existencia de endpoints (401/404).
- Documentación de terceros sobre alta de `client_id`/`client_secret`:
  búsqueda web, no verificada con cuenta propia.
- GTFS descargados y abiertos hoy: `trenes-gtfs.zip` (1,9 MB),
  `colectivos-gtfs.zip` (209 MB), `subte-gtfs.zip` (45 KB, contiene
  un zip anidado de 196 KB).
