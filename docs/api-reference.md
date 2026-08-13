# API Trenes Argentinos (SOFSE) — referencia

Base: `https://api-servicios.sofse.gob.ar/v1`

Todo lo documentado acá se verificó con `curl` el **12 de agosto de 2026**.
Lo que no existe está marcado como tal. No hay documentación oficial.

---

## 1. Resumen

La API tiene dos familias de endpoints.

| Familia | Auth | Para qué sirve |
|---|---|---|
| `/arribos/*` | **No** requiere token | Arribos en vivo y horarios programados |
| `/infraestructura/*` | **Sí** requiere token | Catálogo de líneas, ramales, estaciones y alertas |
| `/auth/authorize` | — | Emite el token |

Solo existen esas tres rutas. Todo el resto devuelve 404.

### Endpoints verificados

| Método | Ruta | Auth |
|---|---|---|
| POST | `/auth/authorize` | no |
| GET | `/arribos/estacion/{id}` | no |
| GET | `/infraestructura/gerencias` | sí |
| GET | `/infraestructura/ramales` | sí |
| GET | `/infraestructura/estaciones` | sí |

### Rutas probadas que NO existen (404)

`/alertas`, `/alertas/gerencia/{id}`, `/infraestructura/alertas`, `/servicios`,
`/servicios/{uuid}`, `/posiciones`, `/posiciones/gerencia/{id}`, `/gps`, `/gpss`,
`/trenes`, `/equipos`, `/infraestructura/equipos`, `/infraestructura/formaciones`,
`/infraestructura/tramos`, `/infraestructura/andenes`, `/infraestructura/empresas`,
`/tarifas`, `/noticias`, `/avisos`, `/estado`, `/version`, `/health`, `/status`,
`/arribos/ramal/{id}`, `/infraestructura/estaciones/{id}`, `/infraestructura/ramales/{id}`,
`/infraestructura/gerencias/{id}`.

Los recursos por path-id no existen. Todo se filtra por query string.

---

## 2. Autenticación

### Cómo funciona

El token se genera con credenciales derivadas de la fecha UTC del día.
No hay usuario real. El JWT vuelve con `user.first_name = "APP-Mobile"`.

Algoritmo verificado (viene del APK oficial, publicado por [ariedro/api-trenes](https://github.com/ariedro/api-trenes)):

1. `username = base64("YYYYMMDDsofse")` con la fecha **UTC** de hoy.
2. `password` se deriva del `username` en 6 pasos:
   `base64` → `cifra(0)` → `invertir` → `base64` → `cifra(1)` → `invertir` → `urlencode`.

Tabla de sustitución. `cifra(0)` usa la primera salida, `cifra(1)` la segunda.

| Entra | cifra(0) | cifra(1) |
|---|---|---|
| `a` | `#t` | `#j` |
| `e` | `#x` | `#p` |
| `i` | `#f` | `#w` |
| `o` | `#l` | `#8` |
| `u` | `#7` | `#0` |
| `=` | `#g` | `#v` |

### POST /auth/authorize

Body **JSON obligatorio**. Form-encoded devuelve `400 Debe especificar el usuario`.

```
POST /v1/auth/authorize
Content-Type: application/json

{"username":"MjAyNjA4MTJzb2ZzZQ==","password":"..."}
```

Respuesta:

```json
{"token":"eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."}
```

Payload del JWT:

```json
{"sub":0,"token_type":"bearer",
 "user":{"id":0,"first_name":"APP-Mobile","last_name":"Externa"},
 "iat":1786567356,"exp":1786653756}
```

**Vigencia: 24 horas exactas** (`exp - iat = 86400`).

### Cómo mandar el token

Header `Authorization` con el JWT **crudo**.

```
Authorization: eyJhbGciOi...
```

**Gotcha grave**: el prefijo `Bearer ` rompe la request. Devuelve `403 Forbidden`.

### Códigos de error de auth

| Situación | Código | Body |
|---|---|---|
| Sin header `Authorization` | 401 | `{"status":401,"message":"Unauthorized"}` |
| Token inválido, vencido o con `Bearer ` | 403 | `{"status":403,"message":"Forbidden"}` |
| Credenciales mal formadas | 401 | `{"code":401,"message":"Usuario incorrecto"}` |

Implementá reintento: ante 401 o 403, regenerá el token y repetí una vez.

---

## 3. GET /arribos/estacion/{id}

Devuelve los servicios que pasan por una estación. **No requiere token.**

### Parámetros

| Parámetro | Tipo | Efecto verificado |
|---|---|---|
| `id` (path) | int | ID de estación. Obligatorio |
| `cantidad` | int | Corta la lista. Si supera el total, no agrega nada |
| `hasta` | int | ID de estación destino. Filtra a servicios que llegan ahí |
| `ramal` | int | Filtra por ID de ramal |
| `sentido` | int | `1` = hacia cabecera final. `2` = hacia cabecera inicial |
| `fecha` | `YYYY-MM-DD` | Solo con `hora`. Cambia a modo horario |
| `hora` | `HH:MM` | Solo con `fecha`. Cambia a modo horario |
| `paraApp` | bool | **Sin efecto observable** |
| `tipoBusqueda` | any | **Sin efecto observable** |

Ejemplo real de filtrado, estación 332 (Retiro Mitre):

```
sin filtro          -> total 14
?hasta=389          -> total 6
?ramal=5            -> total 6
?ramal=9            -> total 5
?sentido=1          -> total 14
?sentido=0          -> total 0
```

### Gotchas de parámetros

- `sentido=0` y `sentido=-1` devuelven `results: []`. Solo valen `1` y `2`.
- `fecha` sola se ignora. `hora` sola se ignora. Hacen falta las dos juntas.
- Formatos `DD-MM-YYYY` y `YYYY/MM/DD` **cambian de modo pero devuelven horas `null`**. Usá siempre ISO.
- `hora` se interpreta en hora local de Buenos Aires (UTC−3). Las respuestas vienen en UTC con sufijo `Z`.
- Un ID inexistente devuelve **200 con `results: []`**, no 404. No sirve para validar IDs.
- `/arribos/estacion` sin ID devuelve 200 con `{"status":"Espacho inexistente"}`.

### Modo VIVO (sin `fecha`+`hora`)

Envoltorio:

```json
{"timestamp": 1786568212, "results": [ {"arribo": {...}, "servicio": {...}} ], "total": 14}
```

`timestamp` es epoch en segundos, UTC. Es el reloj del servidor. Usalo como "ahora".

Ejemplo recortado de un elemento:

```json
{
 "arribo": {
  "orden": 55,
  "nombre": "3 de Febrero",
  "idElemento": 1,
  "idPunto": 36,
  "parada": true,
  "programada": true,
  "segundos": 0,
  "anden": {"id": 1126, "nombre": "1"},
  "equipo": {"id": 269, "gpss": ["20055","20054","261","113"], "nombre": "M28", "esElectrico": 1},
  "llegada": {
    "programada": "2026-08-12T20:53:30.000Z",
    "estimada":   "2026-08-12T20:55:58.000Z",
    "real":       "2026-08-12T20:55:37.000Z",
    "distancia": 79.7, "velocidad": 29,
    "latitud": -34.5722699, "longitud": -58.4258703, "referencia": 6744
  },
  "salida": {
    "programada": "2026-08-12T20:54:00.000Z",
    "estimada":   "2026-08-12T20:56:28.000Z",
    "real":       "2026-08-12T20:56:44.000Z",
    "inArea": true, "distancia": 179.9, "velocidad": 30
  }
 },
 "servicio": {
  "id": "c055a8f1-3122-4960-b1fd-858050c077f8",
  "numero": 3418,
  "sentido": 2,
  "oculto": false,
  "cancelacion": null,
  "leyenda": null,
  "location": {"lat": -34.582649, "long": -58.387333},
  "gerencia": {"id": 5, "nombre": "Mitre"},
  "ramal": {"id": 7, "nombre": "Retiro-Mitre", "tolerancia": 359,
            "cabeceraInicial": {"id": 332, "nombre": "Retiro (LGM)", "nombreCorto": "Retiro (LGM)"},
            "cabeceraFinal":   {"id": 273, "nombre": "Bmé. Mitre",   "nombreCorto": "Mitre"}},
  "tipo": {"id": 1, "nombre": "Normal", "programado": true,
           "clasificacion": {"id": 1, "nombre": "Pasajeros"}, "subclasificacion": 1},
  "desde": {"estacion": {...}, "punto": {...}, "estado": {"id": 35, "nombre": "Partió"}},
  "hasta": {"estacion": {...}, "punto": {...}},
  "estaciones": [ {...}, {...} ]
 }
}
```

#### Campos clave

- `servicio.id` — UUID del servicio del día. Sirve de clave estable para diffear entre polls.
- `servicio.location` — **posición GPS del tren en vivo**. Es lo que dibuja el tren en el mapa.
- `servicio.estaciones` — recorrido completo. Cada punto trae `idElemento` (ID de estación), `nombre`, `orden`, `anden`, `llegada`, `salida`.
- `servicio.desde.estado` — estado del servicio en su origen.
- `arribo.segundos` — segundos hasta el arribo, contados desde `timestamp`.
- `arribo.equipo.gpss` — IDs de los equipos GPS a bordo.
- `ramal.tolerancia` — umbral de puntualidad en segundos. 359 en ramales urbanos. 959 y 1259 en larga distancia.

#### Valores enumerados observados

Muestra de 263 servicios en 45 estaciones.

`servicio.desde.estado`:

| id | nombre | frec. |
|---|---|---|
| 10 | Programado | 44 |
| 20 | Confirmado | 88 |
| 25 | En Andén | 37 |
| 30 | Demorado | 2 |
| 35 | Partió | 92 |

`servicio.tipo`: `1 Normal` (240), `4 Semi Rapido` (5), `7 Directo` (18).

`salida.enAnden` es un string humano: `"DENTRO DEL ANDEN dist: 61"`.

#### Campos que faltan seguido

Sobre 263 servicios muestreados:

| Campo | Ausente |
|---|---|
| `llegada.estimada` | 62% |
| `servicio.location` | 46% |
| `arribo.anden` | 6% |
| `equipo.gpss` | 5% |

`cancelacion` y `leyenda` vinieron `null` en los 263. No pude observar su forma poblada.
Tratalos como opcionales de tipo desconocido.

### Modo HORARIO (con `fecha` **y** `hora`)

Otro esquema. Es la tabla programada, no el vivo.

```
GET /arribos/estacion/332?hasta=389&fecha=2026-08-13&hora=08:00&cantidad=2
```

Diferencias contra el modo vivo:

- **No** trae `location`, `equipo`, `estado`, `real`, `estimada`, `velocidad`, `distancia`.
- `servicio.id` es `null`.
- Aparece `servicio.horaSalida: {"hours": 8, "minutes": 10}`.
- `ramal` trae `siglas` y los nombres de cabecera usan `nombre_corto` (snake_case), no `nombreCorto`.
- `arribo.segundos` se cuenta desde la `hora` pedida, no desde ahora.
- `anden.id` y `anden.nombre` suelen venir `null`.

Acepta fechas pasadas y devuelve datos. Fechas muy futuras devuelven `total: 0`.

**Gotcha de nombres**: el mismo concepto cambia de caso entre modos.
Modo vivo usa `nombreCorto`. Modo horario usa `nombre_corto`. Parseá los dos.

---

## 4. GET /infraestructura/gerencias

Requiere token. Devuelve las 7 líneas operadas por SOFSE **con sus alertas**.

| Parámetro | Efecto |
|---|---|
| `idEmpresa` | Solo `1` devuelve datos. Cualquier otro valor devuelve `[]`. Omitirlo equivale a `idEmpresa=1` |

```json
[{"id": 11, "id_empresa": 1, "nombre": "Roca",
  "estado": {"id": 13, "mensaje": "Alertas por ramal", "color": "#435a6c"},
  "alerta": [ {...} ]}]
```

IDs: `1` Sarmiento, `5` Mitre, `11` Roca, `21` Belgrano Sur, `31` San Martín,
`41` Tren de la Costa, `501` Regionales.

**Gotcha**: `estado.color` es el color del **estado de servicio**, no el color de la línea.
Los 7 devolvieron el mismo `#435a6c`. No lo uses como color de marca.

**Gotcha grave**: este endpoint **no lista Belgrano Norte (61) ni Urquiza (71)**.
Esas dos gerencias aparecen solo en `/infraestructura/ramales`. Ver sección 8.

---

## 5. GET /infraestructura/ramales

Requiere token.

| Parámetro | Efecto |
|---|---|
| `idGerencia` | Filtra por línea. Devuelve solo ramales de esa gerencia |
| (sin params) | **Devuelve 29 ramales, más que la suma de las 7 gerencias (27)** |

Llamarlo sin `idGerencia` es la única forma de ver los ramales 61 y 71.

```json
{
 "id": 17,
 "nombre": "Constitución-Alejandro Korn",
 "siglas": "AK",
 "id_gerencia": 11,
 "id_estacion_inicial": 93,
 "id_estacion_final": 13,
 "estaciones": 15,
 "operativo": 1,
 "es_electrico": 1,
 "tipo_id": 1,
 "puntualidad_tolerancia": 359,
 "publico": true,
 "orden_ramal": 1,
 "mostrar_en_panel_cumplimiento": true,
 "cabecera_inicial": {"id": 93, "nombre": "Constitución", "siglas": "PC", "nombre_corto": "Plaza C."},
 "cabecera_final":   {"id": 13, "nombre": "Alejandro Korn", "siglas": "AK", "nombre_corto": "A. Korn"},
 "alerta": null
}
```

Notas:

- `cabecera_*.visibilidad` viene como **string con JSON adentro**. Hay que parsearlo dos veces.
- `alerta` es `null` o un objeto. En `/gerencias` el mismo campo es un **array**. Esquema inconsistente.
- `tipo_id`: `1` urbano, `2` regional, `3` larga distancia. Correlaciona con `puntualidad_tolerancia`.
- Los parámetros `idRamal` e `id` se **ignoran**. Siempre devuelve la lista completa.

---

## 6. GET /infraestructura/estaciones

Requiere token. Es la fuente del catálogo, **con coordenadas**.

| Parámetro | Efecto |
|---|---|
| `nombre` | Búsqueda por **substring**, insensible a mayúsculas y acentos |
| `idRamal` | Estaciones del ramal, en orden |
| `idGerencia` | Estaciones de la línea |
| (sin params) | Devuelve `[]` |

```json
{
 "nombre": "Retiro (LGM)",
 "id_estacion": "332",
 "id_tramo": "1",
 "orden": "1",
 "id_referencia": "3653",
 "latitud": "-34.5909122",
 "longitud": "-58.3750538",
 "referencia_orden": "1",
 "radio": "",
 "andenes_habilitados": "8",
 "visibilidad": {"totem": 1, "app_mobile": 1},
 "incluida_en_ramales": [141, 151, 9, 5, 7, 171],
 "operativa_en_ramales": [141, 151, 9, 5, 7, 171]
}
```

Notas:

- **Todos los valores numéricos son strings.** `id_estacion`, `latitud`, `longitud`, `orden`. Casteá.
- `radio` suele venir string vacío.
- `nombre` es substring, no prefijo: `nombre=ez` matchea `Ezeiza`, `Suárez` y `Nuñez`.
- **Gotcha**: `nombre` combinado con `idRamal` no intersecta. `?idRamal=9&nombre=retiro` devuelve `Retiro (LSM)`, que no está en el ramal 9.
- `idEstacion` **no** es un parámetro válido. Devuelve `[]`.
- `incluida_en_ramales` incluye ramales que **no** aparecen en `/infraestructura/ramales` (larga distancia y ramales fuera de servicio).

---

## 7. Cómo calcular demora

Hay campo de hora estimada real. Se llama `estimada` y está en `llegada` y en `salida`.

### Fórmula

```
demoraSegundos = epoch(arribo.llegada.estimada) - epoch(arribo.llegada.programada)
```

Verificado en vivo, estación 1 (3 de Febrero), `timestamp` 1786567982:

| Servicio | programada | estimada | demora |
|---|---|---|---|
| 3418 | 20:53:30Z | 20:56:12Z | +162 s |
| 3411 | 20:59:30Z | 21:01:38Z | +128 s |
| 3620 | 21:02:30Z | 21:02:26Z | −4 s |
| 3613 | 21:05:30Z | ausente | sin dato |

La demora puede ser negativa. El tren viene adelantado.

### Si falta `estimada`

Pasa en el 62% de los casos. Significa que no hay predicción en vivo: el tren
todavía no salió o no reporta GPS. **No asumas 0 de demora.** Mostrá "sin datos".

Cómo detectarlo rápido, sin parsear fechas:

```
epoch(llegada.programada) - timestamp  ==  segundos   ->  NO hay dato en vivo
```

Cuando hay estimada, `segundos ≈ epoch(estimada) - timestamp` (±1 s).
Cuando no la hay, `segundos` cae de nuevo al horario programado.

### ¿Es demora "oficial"?

Usá `servicio.ramal.tolerancia`, en segundos.

```
enHorario = demoraSegundos <= tolerancia
```

Vale 359 s (≈6 min) en ramales urbanos, 959 s en Once-Bragado, 1259 s en Retiro-Junín.

### Tren que ya pasó

Cuando existe `llegada.real`, el arribo ya ocurrió y `segundos` vale 0.
La demora consumada es `real - programada`. Filtralos de la lista de próximos arribos.

### Zona horaria

Todas las fechas de respuesta son UTC con sufijo `Z`. Buenos Aires es UTC−3 fijo,
sin horario de verano. `timestamp` es epoch UTC.

---

## 8. Alertas

**No hay endpoint de alertas.** Todas las rutas `/alertas*` devuelven 404.

Las alertas viajan **embebidas** en otros dos endpoints:

| Fuente | Campo | Tipo | Alcance |
|---|---|---|---|
| `/infraestructura/gerencias` | `alerta` | **array** | Alertas de línea (`ramal_id: null`) |
| `/infraestructura/ramales` | `alerta` | **objeto o null** | Alerta del ramal |

Para juntar todas hay que pegarle a los dos. El tipo del campo cambia entre uno y otro.

### Esquema del objeto alerta

```json
{
 "id": 96073,
 "linea_id": 11,
 "ramal_id": 15,
 "estacion_id": null,
 "sentido": null,
 "causa_gtfs": "ACCIDENT",
 "efecto_gtfs": "SIGNIFICANT_DELAYS",
 "icono_fontawesome": null,
 "contenido": "El servicio Bosques-T restablece su recorrido completo con demoras y cancelaciones tras colisión con persona en Florencio Varela.",
 "habilitado": 1,
 "vigencia_desde": "2026-08-12 16:46:00",
 "vigencia_hasta": null,
 "criticidad_orden": 2,
 "criticidad_color_fondo": "#dff0d8",
 "criticidad_color_texto": "#3c763d"
}
```

### Valores observados hoy (20 alertas)

`causa_gtfs`: `OTHER_CAUSE`, `ACCIDENT`, `TECHNICAL_PROBLEM`.
`efecto_gtfs`: `OTHER_EFFECT`, `SIGNIFICANT_DELAYS`, `NO_SERVICE`.

Son los enums de **GTFS-realtime Service Alerts**. Mapealos a íconos propios.

`criticidad_orden`: `1` corte total, `2` demoras/cancelaciones, `4` informativa.
Ordená la lista por este campo ascendente.

### Gotchas de alertas

- `vigencia_*` viene `"YYYY-MM-DD HH:MM:SS"` en **hora local**, sin `Z` y sin `T`. Distinto del resto de la API, que usa ISO UTC. No lo parsees con el mismo decoder.
- `vigencia_hasta: null` significa "hasta nuevo aviso".
- Las 6 alertas de gerencia de hoy eran el **mismo texto** sobre CUD y SUBE, repetido por línea. Deduplicá por `contenido` antes de mostrar.
- `criticidad_color_fondo` de hoy era verde (`#dff0d8`) incluso para `criticidad_orden: 4`. Los colores del backend no comunican gravedad. Usá `criticidad_orden`.
- `icono_fontawesome` viene `null` en la mitad de los casos.
- `estacion_id` vino `null` en las 20. No pude verificar alertas por estación.
- Alertas de tren puntual llegan con `sentido` seteado: *"El tren de las 17:50 hs partiendo desde Maipú hacia Delta ha sido cancelado."*

---

## 9. Rate limits y red

No detecté rate limiting.

- 60 requests concurrentes (10 hilos) a `/arribos/estacion/1` → **60× HTTP 200 en 1,2 s**.
- No hay headers `X-RateLimit-*`, ni `Retry-After`, ni 429.
- Aun así, dejá `sleep 0.2` entre requests masivos. No hay contrato público.

Headers de respuesta:

```
Server: nginx
Access-Control-Allow-Origin: *
ETag: W/"26cf-C5p+vLQ6fHIKrwG7z4AITiz7vxc"
Strict-Transport-Security: max-age=15552000; includeSubDomains
```

- CORS abierto. Se puede llamar desde el navegador.
- Hay `ETag`. Se puede usar `If-None-Match` para ahorrar transferencia.
- **No hay `Cache-Control`.**
- Los payloads de `/arribos` son pesados: ~10 KB con `cantidad=1`, y hasta cientos de KB sin filtro, porque cada servicio repite el recorrido completo. Sufrí timeouts a 40 s con estaciones grandes. Poné timeout ≥ 60 s y reintento.
- Para listas de arribos, pedí siempre `cantidad`. Baja mucho el payload.

---

## 10. Cobertura real

- **360 estaciones** en `docs/estaciones.json`, las 360 con coordenadas.
- **262** pertenecen a alguno de los 29 ramales públicos.
- **238** devolvieron al menos un arribo el 12-ago-2026 a las 17:45 ART.
- 356 vienen de la API SOFSE. 4 (`6` Adela, `48` Buenos Aires, `230` Lezama, `275` Monasterio) existen solo en el GTFS: la API las referencia como cabecera pero no las indexa ni les da arribos.

### Líneas que la API NO cubre

`/infraestructura/ramales` lista el ramal **61 Retiro-Villa Rosa (Belgrano Norte)** y el
**71 Lacroze-Lemos (Urquiza)**. Pero:

- `/infraestructura/estaciones?idRamal=61` → `[]`
- `/infraestructura/estaciones?idRamal=71` → `[]`
- `/infraestructura/estaciones?idGerencia=61` → `[]`
- `/infraestructura/estaciones?idGerencia=71` → `[]`
- Buscar `Villa Rosa`, `Lacroze`, `Grand Bourg`, `Boulogne`, `Lemos`, `Campo de Mayo` → `[]`

**Belgrano Norte y Urquiza no tienen ni una estación en esta API.** Las opera Ferrovías y
Metrovías, no SOFSE. La app no puede dar arribos de esas dos líneas.

### Validación de coordenadas

Crucé las 360 contra el GTFS estático de Trenes Argentinos
(`data.buenosaires.gob.ar/dataset/trenes-gtfs`, descargado hoy).

- Los `stop_id` del GTFS **son** los `id_estacion` de SOFSE. El join es por ID, no por nombre.
- 248 estaciones coinciden por ID.
- Distancia media entre ambas fuentes: **33 m**. Mediana 20 m. Máximo 259 m (Zeballos).
- Ninguna supera 1 km.

Las coordenadas de la API son confiables. No hace falta el GTFS para geolocalizar.

---

## 11. Ramales fantasma

Las estaciones declaran ramales que `/infraestructura/ramales` no lista.
Ejemplo: la estación 1 (3 de febrero) trae `incluida_en_ramales: [7, 9, 141, 151, 171]`,
pero los ramales 141, 151 y 171 no existen en la lista de ramales.

Detecté 22 de estos IDs: 23, 31, 43, 59, 63, 73, 75, 76, 101, 103, 105, 141, 151,
161, 171, 181, 503, 505, 507, 515, 519, 523, 525, 601, 603, 605, 607, 609.

Dos de ellos sí tienen nombre en el GTFS: `43` = Roca / Plaza Constitución - Cañuelas (Pza),
`63` = Belgrano Sur / Apeadero Km 12 - Libertad. El resto no tiene nombre en ninguna fuente.

Están volcados en `lineas.json`, campo `ramalesNoListados`, con la gerencia inferida
por mayoría a partir de las estaciones que los declaran.

**Filtrar por uno de estos ramales devuelve vacío.** `?ramal=43` en Constitución → `total: 0`.
Son ramales históricos, de larga distancia o fuera de servicio.

### Usá `operativa_en_ramales`, no `incluida_en_ramales`

El objeto estación trae los dos arrays. Solo el segundo sirve para la UI.

```
estación 1 (3 de febrero)
  incluida_en_ramales:  [7, 9, 141, 151, 171]
  operativa_en_ramales: [7, 9]
```

`incluida_en_ramales` es histórico. `operativa_en_ramales` es lo que corre hoy.
Para "¿qué ramales paran acá?", usá `operativa_en_ramales`.

---

## 12. Receta mínima para la app

1. Al arrancar, cargá `estaciones.json` y `lineas.json` embebidos. No pegues a `/infraestructura` en runtime.
2. Refrescá el catálogo con un job aparte, no en el cliente.
3. Para arribos, usá `/arribos/estacion/{id}?cantidad=N`. Sin token.
4. Para alertas, pedí token y llamá a `/infraestructura/gerencias` + `/infraestructura/ramales`. Cacheá 5 minutos.
5. Guardá el token 24 h. Regeneralo ante 401 o 403.
6. Calculá demora con `estimada - programada`. Si falta `estimada`, mostrá "sin datos".
7. Dibujá el tren con `servicio.location`. Está ausente el 46% de las veces.

---

## Fuentes

- API verificada con `curl` el 12-ago-2026 desde esta máquina.
- Algoritmo de auth: [ariedro/api-trenes](https://github.com/ariedro/api-trenes) (`auth.js`, `config.js`), extraído del APK oficial.
- Documentación comunitaria de endpoints: [trenes.sofse.apidocs.ar](https://trenes.sofse.apidocs.ar/) (Enzo Notario).
- GTFS estático: [Buenos Aires Data — Trenes: GTFS](https://data.buenosaires.gob.ar/dataset/trenes-gtfs).
