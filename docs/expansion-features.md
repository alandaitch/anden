# Expansión de Andén: features de alto impacto

Investigación para la v2/v3 de Andén. Fecha: 13 de agosto de 2026.

Alcance: qué sumar más allá de trenes SOFSE, con qué dato real,
y si hace falta backend propio. Todo lo marcado "verificado hoy" se probó
con `curl` el 13-ago-2026 desde esta máquina.

Este documento no repite la investigación ya hecha. Para competencia
internacional, ver [`features-mundo.md`](features-mundo.md).
Para el ecosistema argentino de trenes, ver [`features-argentina.md`](features-argentina.md).
Para límites técnicos de iOS sin servidor, ver [`ios-tech.md`](ios-tech.md).
Para la API de SOFSE, ver [`api-reference.md`](api-reference.md).

---

## Resumen: Top 12 priorizado

Orden por impacto × factibilidad sin backend propio.

| # | Feature | Impacto | Esfuerzo | Backend / datos nuevos | Sección |
|---|---|---|---|---|---|
| 1 | Ecobici en la app: bicis y anclajes libres cerca | Alto | Bajo | No. GBFS público en vivo | [§1](#1-multimodal-una-sola-vista-para-tren--subte--colectivo--ecobici) |
| 2 | Subte embebido: horario + red + estado por línea | Alto | Bajo | No. GTFS de 44 KB | [§1](#1-multimodal-una-sola-vista-para-tren--subte--colectivo--ecobici) |
| 3 | Estaciones accesibles + bocas con ascensor/escalera/rampa | Alto | Bajo | No. Dataset estático real | [§4](#4-accesibilidad-ascensores-escaleras-y-estaciones-accesibles) |
| 4 | Colectivo: horario teórico + salto directo a Cuándo SUBO | Alto | Medio | No para horario. Vivo depende de terceros | [§2](#2-cuándo-llega-el-bondi-en-la-parada-más-cercana) |
| 5 | "Cerca de mí" multimodal, sin ruteo completo | Alto | Medio | No | [§1](#1-multimodal-una-sola-vista-para-tren--subte--colectivo--ecobici) |
| 6 | Live Activity de viaje completo, multi-etapa | Alto | Medio | No | [§7](#7-live-activity-del-commute-completo--widgets--watch--carplay--siri--standby) |
| 7 | Get-off alert para el tren | Alto | Medio | No | [§3](#3-get-off-alert--acompañante-de-viaje-activo) |
| 8 | Reportes comunitarios vía CloudKit | Alto | Medio | Sí, pero de Apple. No hay servidor propio | [§5](#5-comunidad-reportes-crowdsourced-sin-backend-propio) |
| 9 | Puntualidad histórica guardada en el dispositivo | Medio-alto | Bajo | No | [§6](#6-puntualidad-histórica-por-línea-y-ramal) |
| 10 | Widget multimodal por parada (tren+bondi+subte+Ecobici) | Medio-alto | Bajo | No | [§7](#7-live-activity-del-commute-completo--widgets--watch--carplay--siri--standby) |
| 11 | Siri / App Intents multimodal | Medio | Bajo | No | [§7](#7-live-activity-del-commute-completo--widgets--watch--carplay--siri--standby) |
| 12 | Andén Plus: sostenibilidad sin ads intrusivos | Medio | Bajo | No | [§8](#8-monetización-suave) |

Trip planning completo (ruteo automático multimodal) queda **fuera** del Top 12.
Ver por qué en [§1.2](#12-cómo-llego-trip-planning-client-side-es-factible).

CarPlay queda **fuera** del Top 12. Ver por qué en [§7.4](#74-carplay-por-qué-no-conviene-priorizarlo).

---

## 1. Multimodal: una sola vista para tren + subte + colectivo + Ecobici

### 1.1 Qué fuentes hay hoy (verificado hoy)

| Modo | Fuente | Auth | Tipo | Estado verificado |
|---|---|---|---|---|
| Tren | `api-servicios.sofse.gob.ar` | No | Vivo | 200 OK. Ya integrado en Andén |
| Ecobici | `buenosaires.publicbikesystem.net/customer/gbfs/v3.0/*` | No | Vivo, GBFS 3.0 | 200 OK. `ttl` 14-30 s |
| Subte | `cdn.buenosaires.gob.ar/.../subte-gtfs-zip.zip` | No | Estático | 200 OK. 44.907 bytes |
| Subte (estado en vivo) | GCBA API Transporte | Sí (client_id) | Vivo | **Suspendido** desde el portal oficial |
| Colectivo (horario) | `cdn.buenosaires.gob.ar/.../colectivos-gtfs.zip` | No | Estático | 200 OK. 209 MB, sin cambios desde 2019 |
| Colectivo (horario liviano) | `.../colectivos-gtfs-frequency.zip` | No | Estático, por frecuencia | 200 OK. 13,7 MB, sin cambios desde 2019 |
| Colectivo (vivo) | GCBA API Transporte | Sí (client_id) | Vivo, protobuf GTFS-RT | **Suspendido**. `401 Authentication denied` sin key |
| Colectivo (vivo, alternativa) | Cualbondi (`api.cualbondi.com.ar`) | — | — | **Muerta**. `410 Gone` en HTTP, TLS roto en HTTPS |
| Colectivo (vivo, oficial nacional) | Cuándo SUBO (`cuandosubo.sube.gob.ar`) | — | Solo app/web | App real, sin API pública documentada |

Gotcha de auth encontrado hoy: `/colectivos/vehiclePositions` de la API de
GCBA devuelve `{"error":"Authentication denied."}` con 401. La puerta de
auth está viva. El dato de fondo está marcado como suspendido por la
Ciudad desde el 17-jun-2026: *"todos los datasets con Formato API y GTFS
están suspendidos. Se encuentran en revisión y corrección."*

Registro para pedir `client_id`/`client_secret`, cuando reabra:
`buenosaires.gob.ar/desarrollourbano/transporte/apitransporte`.

Descubrimiento de la URL real de GBFS de Ecobici: **no** está en
`gbfs.buenosaires.gob.ar` (ese host no resuelve). Está en el catálogo
oficial de MobilityData (`systems.csv`), apuntando a la plataforma PBSC:

```
https://buenosaires.publicbikesystem.net/customer/gbfs/v3.0/gbfs.json
```

Feeds hijos: `station_information`, `station_status` (bicis y anclajes
libres por estación, actualiza cada 14-30 s), `system_regions`,
`vehicle_types`, `geofencing_zones`. Sin token. CORS no verificado hoy,
probar desde el simulador antes de asumirlo.

### 1.2 "Cómo llego": ¿trip planning client-side es factible?

Depende de qué tan completo lo quieras.

**Ruteo completo automático (origen → destino, con transbordos)**: factible
en teoría con el algoritmo RAPTOR. No necesita preprocesamiento pesado del
lado servidor, corre sobre el horario estático directo. Pero:

- El GTFS de colectivos pesa 209 MB completo, o 13,7 MB en versión por
  frecuencia (sin horario exacto por parada, solo intervalos).
- Ninguno de los dos se actualizó desde 2019. El dato de recorridos puede
  estar desactualizado. Cambios de recorrido no se reflejan.
- Hace falta una capa de transbordo a pie: matriz de distancia entre
  paradas cercanas, o cálculo Haversine al vuelo.
- Combinar 3 fuentes con 3 formatos de ID de parada distintos (SOFSE usa
  IDs propios, subte y colectivo usan `stop_id` de GTFS) pide una capa de
  normalización propia.

Esto es varias semanas de trabajo. **Esfuerzo alto, factibilidad media**,
sin backend propio (todo corre local). Candidato a v3, no a v2.

**MVP realista para v2: "cerca de mí" sin ruteo.** No calcules la mejor
combinación. Mostrá, en una sola pantalla, todo lo que hay caminable desde
la ubicación del usuario: próximo tren, próximo subte (con estado por
línea si la API de GCBA reabre), Ecobici con bicis libres, y horario
teórico de colectivo. El usuario ya sabe su combinación habitual. Solo
necesita el estado de las 2 a 4 paradas que usa todos los días.

Este patrón ya lo validan DB Navigator (widget "Pendler": trayecto fijo,
no búsqueda) y Renfe Cercanías ("tren habitual del usuario"), documentados
en `features-mundo.md`. Aplicado a 3 modos en vez de 1, es el mismo
principio.

Dato de contexto: existe una encuesta oficial de viajes multimodales,
`viajes-etapas-transporte-publico` (2019-2024) en el portal de GCBA. Sirve
para decidir qué combinaciones tren+subte+colectivo priorizar en el
onboarding, no la exploré hoy en detalle.

### 1.3 Ideas concretas

1. **Ecobici cerca de la estación de tren.** En el tablero de estación,
   mostrar la estación de Ecobici más cercana con bicis y anclajes libres.
   Impacto alto, esfuerzo bajo, sin backend. Dato ya verificado hoy
   (ejemplo real: estación "002 - Retiro I", a metros de Retiro).
2. **Subte embebido como cuarto modo.** Sumar catálogo de líneas y
   estaciones de subte (44 KB, trivial de embeber) con horario de
   apertura/cierre. Sin vivo hasta que reabra la API de GCBA, mostrar
   "horario programado" con el mismo patrón que Andén ya usa para el
   modo horario de SOFSE. Impacto alto, esfuerzo bajo, sin backend.
3. **Colectivo: parada más cercana, horario por frecuencia.** Usar el
   GTFS liviano (13,7 MB) para mostrar "cada X minutos, aprox." en la
   parada más cercana. Aclarar que es teórico y de 2019, no vivo. Impacto
   medio (sin vivo, no es la killer feature todavía), esfuerzo medio.
4. **"Cerca de mí" unificado, sin ruteo.** Una pantalla con las próximas
   salidas de los 4 modos disponibles a pie desde la ubicación actual.
   Impacto alto, esfuerzo medio, sin backend.
5. **Trip planning completo.** Documentado como v3. Esfuerzo alto,
   factibilidad media, sin backend pero con mucho trabajo de datos.

---

## 2. "Cuándo llega el bondi" en la parada más cercana

Es, según el pedido, la feature más usada en Buenos Aires. La investigación
de hoy confirma por qué nadie de afuera la resuelve bien todavía.

### 2.1 El bloqueo: la fuente oficial en vivo está fuera

Tres caminos probados hoy, los tres cerrados o débiles:

1. **API oficial de GCBA** (`api-transporte.buenosaires.gob.ar`): viva a
   nivel de servidor (responde 401, no timeout), pero el propio portal de
   datos abiertos avisa que **todos los datasets de colectivos con formato
   API y GTFS-RT están suspendidos**, en revisión desde junio 2026.
2. **Cualbondi**, la alternativa histórica de terceros: **muerta**.
   `http://api.cualbondi.com.ar/lineasFull` devuelve `410 Gone`.
   `https://cualbondi.com.ar` falla el handshake TLS. El proyecto parece
   discontinuado o migrado sin aviso público encontrado hoy.
3. **Cuándo SUBO** (`cuandosubo.sube.gob.ar`), la app oficial nacional:
   sigue activa, cubre 290+ líneas y ~18.000 unidades en el AMBA, con dato
   de validadores SUBE + GPS satelital. Es la que de verdad tiene el dato
   en vivo hoy. No tiene API pública documentada.

### 2.2 Camino realista hoy

- **Corto plazo**: horario teórico por frecuencia (GTFS de 13,7 MB) más un
  botón "abrir en Cuándo SUBO" con deep link o `openURL` a la app oficial,
  filtrado por la parada que el usuario ya está mirando. No es la
  experiencia soñada, pero es honesta y usable ya.
- **Mediano plazo**: pedir `client_id`/`client_secret` de la API de GCBA
  ahora, para tener acceso apenas reabra. El registro es gratis y rápido
  (`buenosaires.gob.ar/desarrollourbano/transporte/apitransporte`).
- **Riesgoso, no recomendado para v2**: reverse-engineering de Cuándo SUBO,
  al estilo de cómo la comunidad reversó el algoritmo de auth de SOFSE
  (documentado en `api-reference.md`). Es un camino que existe, es zona
  legal más gris que la de SOFSE (que sí tiene endpoint sin token), y
  pide tiempo de ingeniería que hoy no se puede presupuestar sin probar.

### 2.3 Ideas

1. Horario por frecuencia embebido + deep link a Cuándo SUBO. Impacto
   alto, esfuerzo medio, sin backend.
2. Registro anticipado en la API de GCBA, con arquitectura ya lista para
   cuando reabra (mismo patrón de token cacheado que ya usa `TokenProvider`
   para SOFSE). Impacto alto cuando reabra, esfuerzo bajo hoy.
3. Explorar reverse-engineering de Cuándo SUBO como spike de investigación
   aparte, no como compromiso de roadmap. Esfuerzo desconocido hasta
   probar.

---

## 3. Get-off alert + acompañante de viaje activo

Moovit lo llama "Get Off Alert". Transit lo lleva más lejos con el modo GO
(alertas por etapa, detección de caminar/esperar/viajar). Ambos ya están
descriptos en detalle en `features-mundo.md`.

### 3.1 Qué ya permite el dato de Andén

El tren ya trae `servicio.location` (posición GPS en vivo) y
`servicio.estaciones` (recorrido completo con orden). Con eso alcanza para
calcular "faltan N paradas" o "estás a M metros", sin mapa complejo.
Ya HACER LUEGO según el ranking de `features-mundo.md` (puesto 6, impacto
alto, factibilidad media).

### 3.2 Ideas para extender a subte y colectivo

1. **Get-off alert en tren, ahora.** Es el único modo con posición GPS
   confiable disponible hoy. Impacto alto, esfuerzo medio, sin backend.
2. **Get-off alert en subte**: bloqueado hasta que la API de GCBA reabra
   con posición de trenes de subte. Sin eso, solo se puede avisar por
   conteo de estaciones a horario programado, con margen de error alto en
   hora pico. Impacto medio si sale con este límite, esfuerzo medio.
3. **Modo GO estilo Transit** (alertas por etapa: salí ya / apurate /
   bajate): pide motion detection (`CMMotionActivityManager`) más máquina
   de estados de viaje persistente. Ninguno de los dos pide backend. Es
   más lógica que infraestructura. Impacto alto, esfuerzo alto. Candidato
   a v2 avanzada, no al primer corte.

---

## 4. Accesibilidad: ascensores, escaleras y estaciones accesibles

### 4.1 Datos reales encontrados (verificados hoy)

Dos datasets estáticos de SBASE (operador de subte), descargables sin
token, con contenido real hoy mismo:

**`estaciones-accesibles.csv`** — accesibilidad por estación:

```
long;lat;linea;estacion;escaleras_mecanicas;ascensores
-58,43642853;-34,61827997;A;ACOYTE;2;2
```

Separador `;`, decimales con coma. Formato europeo, distinto al resto de
los datasets de GCBA. Casteá con cuidado.

**`bocas-de-subte.csv`** — accesibilidad por **entrada**, más granular:

```
long,lat,id,linea,estacion,...,escalera_p,escalera_m,ascensor,rampa,salvaescal,calle,altura,...
```

Separador `,`, decimales con punto. Trae booleanos por entrada:
escalera peatonal, escalera mecánica, ascensor, rampa, salvaescaleras.
Más la dirección exacta de la boca (calle y altura). Esto responde
"¿qué entrada de esta estación tiene ascensor?", no solo "¿la estación
es accesible?".

### 4.2 El límite: no hay estado en vivo público

Ninguno de los dos datasets dice si el ascensor **funciona hoy**. Ese dato
existe (SBASE/Emova lo gestiona) pero solo por teléfono: CAU 0800-333-6682,
lunes a viernes de 8 a 20. No hay API pública encontrada para estado en
vivo de ascensores y escaleras. Cualquier feature de "estado en vivo" acá
depende de reporte comunitario (ver §5), no de una fuente oficial.

### 4.3 Ideas

1. **Filtro "solo estaciones accesibles" + capa de accesibilidad en el
   mapa de subte.** Con datos estáticos ya verificados. Impacto alto para
   quien lo necesita, esfuerzo bajo, sin backend.
2. **Detalle de accesibilidad por boca, no solo por estación.** Mostrar
   qué entrada exacta conviene según ascensor/escalera/rampa disponible.
   Diferencial real: ningún competidor relevado en `features-mundo.md`
   baja a este nivel de detalle. Impacto alto, esfuerzo bajo, sin backend.
3. **Estado en vivo de ascensores por reporte comunitario**, con aviso
   explícito de que no es dato oficial. Depende de §5. Impacto medio-alto,
   esfuerzo medio, backend = CloudKit.
4. Ser honesto en la UI: "estado en vivo no disponible, datos de SBASE"
   con el 0800 a mano, para el caso urgente. Impacto medio, esfuerzo
   mínimo, sin backend.

---

## 5. Comunidad: reportes crowdsourced sin backend propio

### 5.1 La opción CloudKit

CloudKit es la infraestructura de Apple para apps sin servidor propio.
Tiene base de datos **pública**, compartida entre todos los usuarios de
la app, pensada justo para este caso: contenido visible para todos, tipo
reporte comunitario.

Ventajas concretas:

- No hay servidor que Alan tenga que correr ni mantener. Es "backend",
  pero es el de Apple.
- Cuota gratuita generosa para apps chicas y medianas. Sin costo
  esperable al tamaño de Andén hoy.
- Auth resuelta: cada usuario ya tiene su Apple ID / iCloud. No hace
  falta sistema de cuentas propio.
- Encaja con la arquitectura actual: Andén ya usa App Group para
  compartir datos entre app y widget. CloudKit se integra con
  Core Data (Core Data + CloudKit) sobre el mismo patrón.

Límites reales:

- La base pública no admite zonas custom. Todo vive en la zona default.
  Sin suscripciones granulares por zona, hay que usar `CKQueryOperation`
  para traer datos.
- Requiere que el usuario tenga iCloud activo. Como Andén es solo iOS,
  esto no excluye una plataforma entera (no hay versión Android).
- Pensado para volumen chico-mediano por registro. No es una base de
  analytics masiva. Para reportes de demora/andén/seguridad, el volumen
  esperado entra cómodo.

### 5.2 P2P: por qué no aplica acá

`MultipeerConnectivity` (P2P nativo de Apple) conecta dispositivos
**cercanos entre sí**, por Bluetooth o Wi-Fi directo, en un radio de
metros. Sirve para "compartí este archivo con quien tenés al lado", no
para "alguien reportó una demora en Once y quiero verla yo en Constitución
20 minutos después". La topología no calza con el caso de uso. Descartar
P2P para esto.

### 5.3 Riesgos de moderación y spam

Sin backend propio, no hay lógica de servidor para filtrar contenido
malicioso antes de que llegue a otros usuarios. Mitigaciones posibles,
todas del lado cliente o de reglas de CloudKit:

- Rate limit por usuario: máximo N reportes por hora, calculado local y
  reforzado con un contador en el registro CloudKit del propio usuario.
- Ventana de vigencia corta: un reporte de demora expira solo a los 20-30
  minutos. Limita el daño de un reporte falso.
- Voto de confirmación entre usuarios ("¿seguís viendo esto?"), sin
  identidad expuesta.
- CloudKit Console permite moderación manual básica (borrar registros
  reportados) sin necesitar un panel de admin propio.

### 5.4 Ideas

1. **Reporte de demora/andén/seguridad por estación, vía CloudKit
   público**, con expiración corta y rate limit local. Impacto alto,
   esfuerzo medio, backend = CloudKit (no propio).
2. **Reporte de estado de ascensor/escalera de subte**, mismo mecanismo,
   cubre el hueco de §4.2. Impacto medio-alto, esfuerzo medio, backend
   = CloudKit.
3. **Voto de verificación cruzada** entre reportes, sin cuenta ni perfil
   visible. Impacto medio (calidad del dato), esfuerzo medio, backend =
   CloudKit.

---

## 6. Puntualidad histórica por línea y ramal

Ya está en el ranking de `features-mundo.md` (puesto 11: impacto medio,
factibilidad media). Esta sección lo concreta con los datos que Andén ya
tiene a mano.

Andén ya calcula demora en vivo con `estimada - programada`
(`api-reference.md`, sección 7). Guardar ese cálculo localmente, cada vez
que la app hace una consulta, arma un historial propio sin pedir nada
nuevo a la API.

### Ideas

1. **Guardar delta real vs. programado por servicio consultado**, en un
   store local (SwiftData o Core Data), con línea, ramal y franja horaria.
   Impacto medio-alto, esfuerzo bajo: es guardar un dato que ya se calcula.
   Sin backend.
2. **Vista "puntualidad por franja horaria"** en la pantalla de la línea:
   % de cumplimiento (usando `ramal.tolerancia` como umbral, ya
   documentado) por hora del día, construido con el historial propio.
   Impacto medio-alto, esfuerzo medio, sin backend.
3. **Aclarar que es dato propio, no oficial.** El historial solo cubre
   lo que los usuarios de Andén consultaron. Sesgo de muestra real, hay
   que decirlo en la UI. Sin esto, es una promesa que el dato no sostiene.
4. Extender a subte cuando el modo horario esté embebido (§1), y a
   colectivo si algún día hay vivo (§2). Depende de esas dos secciones.

---

## 7. Live Activity del commute completo + widgets + Watch + CarPlay + Siri + StandBy

Los límites técnicos duros (qué se puede sin servidor push) ya están
resueltos en `ios-tech.md`. Esta sección aplica esos límites al caso
multi-etapa y multimodal, más lo nuevo (CarPlay).

### 7.1 Live Activity multi-etapa

Citymapper cambia el contenido del Live Activity según la etapa del viaje
(caminando → esperando → viajando → bajando), documentado en
`features-mundo.md`. Con lo que ya permite `ios-tech.md` (Live Activity
local, `Text(timerInterval:)`, sin push), esto es una máquina de estados
en el cliente, no una feature nueva de iOS:

- Etapa 1, caminando a la estación: distancia y tiempo estimado.
- Etapa 2, en la estación: countdown del próximo tren (lo que Andén ya
  hace).
- Etapa 3, viajando: paradas restantes, con el get-off alert de §3.
- Etapa 4 (si el usuario configuró un trayecto con transbordo): repetir
  para el segundo tramo.

Impacto alto, esfuerzo medio (lógica de estados, no infraestructura),
sin backend. El `update()` sigue atado a que la app corra en foreground o
en un `BGAppRefreshTask`, con el mismo mejor-esfuerzo ya documentado.

### 7.2 Widgets multimodales por parada

Hoy el widget de Andén es de tren. Extenderlo a mostrar, para una parada
"favorita" que puede ser de cualquier modo, el próximo arribo de ese modo.
Mismo mecanismo de `TimelineProvider` ya documentado, sin costo nuevo de
backend. Impacto medio-alto, esfuerzo bajo.

### 7.3 Apple Watch

`ios-tech.md` ya lo resuelve: desde iOS 18 / watchOS 11, el Live Activity
aparece solo en el Smart Stack del reloj, sin watch app dedicada. Ese
veredicto no cambia con multimodal. **No hacer** watch app propia.

### 7.4 CarPlay: por qué no conviene priorizarlo

Investigado hoy en detalle, con resultado poco favorable:

- Para tener ícono en CarPlay, Apple exige pedir un **entitlement**
  específico, aprobado caso por caso, no automático.
- El entitlement te encierra en **una sola categoría** de plantillas:
  navegación, EV charging, parking, comunicación, etc. No hay categoría
  "transporte público" ni "transit" en la lista relevada hoy.
- La categoría más cercana, "Navigation", está pensada para navegación
  turn-by-turn manejando. Un usuario mirando el próximo tren no encaja
  bien en ese uso ni en esas plantillas.
- Aprobación no garantizada, sin plazo público. Es esfuerzo alto con
  resultado incierto, y el ajuste conceptual (¿quién chequea el tren
  mientras maneja?) es débil.

**Impacto bajo-medio, esfuerzo alto, factibilidad baja.** Queda fuera del
Top 12. Revisar si Apple suma categoría de transporte público más
adelante.

### 7.5 Siri / App Intents multimodal

`ios-tech.md` ya marca esto como HACER LUEGO para tren
(`NextTrainIntent`). Extender el mismo patrón a subte, colectivo (horario)
y Ecobici es agregar más `AppIntent`s sobre el mismo mecanismo, sin
backend nuevo. Impacto medio, esfuerzo bajo.

### 7.6 StandBy

Ya HACER, automático, según `ios-tech.md`: cualquier widget
`systemSmall` aparece solo en StandBy. Extender a multimodal no pide
trabajo extra más allá de tener el widget multimodal de §7.2.

---

## 8. Monetización suave

Comparables reales de la categoría, sin arruinar la promesa central de
Andén ("sin login, sin fricción", ya declarada en `features-argentina.md`):

- **Citymapper CLUB**: paga solo saca los anuncios. US$ 1,49/mes o
  US$ 9,99/año. Las features de ruteo, tiempo real y navegación siguen
  gratis para todos. Modelo freemium con ads, no features tras paywall.
- **Transit App**: el modo GO y el crowdsourcing son gratis. La
  monetización no está en trabar funciones core.

### Ideas para Andén

1. **"Andén Plus" sin ads, nunca hubo ads que sacar.** En vez de eso,
   ofrecer extras que no tocan el uso diario esencial: más de un
   favorito con contexto, widgets adicionales, temas de color por línea,
   historial de puntualidad extendido. Impacto medio, esfuerzo bajo, sin
   backend (compra vía StoreKit, local).
2. **Tip jar único**, sin suscripción. Más simple de implementar y de
   explicar. Impacto medio, esfuerzo mínimo, sin backend.
3. **Nunca cobrar por el dato base**: countdown, demora, andén, alertas.
   Es el corazón de la promesa contra la app oficial de 1,8 estrellas
   (`features-argentina.md`). Cobrar ahí rompe la ventaja competitiva.
4. Nada de ads intrusivos ni de vender datos de ubicación. No hay
   evidencia en la categoría de que eso retenga usuarios, y sí hay
   evidencia (reviews citadas en `features-argentina.md`) de que la
   fricción ahuyenta.

---

## 9. Data-source resiliente: GTFS estático embebido como fallback universal

Andén ya aplica este patrón a trenes: catálogo embebido al arrancar,
modo horario de SOFSE como fallback cuando no hay vivo
(`PLAN.md`, regla de datos). La investigación de hoy da el tamaño real
de extender el mismo patrón a los otros tres modos.

| Modo | Fuente estática | Tamaño verificado | Última actualización | Recomendación |
|---|---|---|---|---|
| Tren | Catálogo propio (`estaciones.json`) + modo horario SOFSE | ya embebido | — | ya HACER, sin cambios |
| Subte | `subte-gtfs-zip.zip` | 44.907 bytes | feb-2023 | embeber completo, trivial |
| Ecobici | GBFS `station_information` | liviano (JSON, sin medir hoy el peso exacto) | vivo | no hace falta fallback estático: si el feed cae, ocultar el modo, no inventar datos |
| Colectivo (liviano) | `colectivos-gtfs-frequency.zip` | 13,7 MB | ago-2019 | embeber con aviso de antigüedad, o descargar on-demand la primera vez |
| Colectivo (completo) | `colectivos-gtfs.zip` | 209 MB | oct-2019 | **no embeber**. Pesa demasiado para el binario de la app |

Patrón recomendado, igual al que ya usa Andén para trenes:

1. Embeber el catálogo estático liviano (subte siempre, colectivo en
   versión frecuencia) en el bundle de la app.
2. Nunca pegarle a `/infraestructura` ni a GCBA en runtime para catálogo.
   Igual regla que ya aplica a SOFSE.
3. Cuando el vivo no está (GCBA suspendido, Ecobici sin respuesta), caer
   al dato estático con la fecha de corte visible. Nunca a pantalla
   vacía. Mismo principio ya validado en `features-mundo.md`
   ("viudez de datos").
4. Refrescar los datasets estáticos con un job aparte (no en el cliente),
   igual que Andén ya hace con `estaciones.json`/`lineas.json`.
5. Para colectivo completo (209 MB): si algún día hace falta ruteo real
   (§1.2, v3), procesarlo server-side una vez y distribuir un subset
   liviano propio, no el ZIP crudo.

---

## Riesgos generales

1. **La API de colectivos de GCBA está suspendida hoy**, con fecha de
   reapertura sin anunciar (última modificación del aviso: 17-jun-2026).
   Cualquier feature de colectivo en vivo depende de esto. No prometer
   fecha.
2. **Cualbondi está muerta** (`410 Gone`). No es una alternativa viable
   hoy, a pesar de historial previo como referencia de la categoría.
3. **El GTFS de colectivos no se actualiza desde 2019.** Recorridos y
   frecuencias pueden estar desactualizados. Mostrarlo como "teórico",
   nunca como tiempo real.
4. **No hay estado en vivo público de ascensores y escaleras del subte.**
   Cualquier feature de accesibilidad "en vivo" depende de reporte
   comunitario, no de una fuente oficial verificada.
5. **CloudKit no es "sin backend" en sentido estricto.** Es backend de
   Apple, sin servidor que Alan corra. Comunicarlo así al usuario si se
   pregunta, para no generar falsa expectativa de "todo es P2P".
6. **CarPlay no tiene categoría de transporte público clara.** Pedir el
   entitlement sin esa categoría es esfuerzo alto con encaje conceptual
   débil. No es un blocker técnico, es una mala apuesta de producto.
7. **Todos los límites de `ios-tech.md` siguen aplicando** al escenario
   multimodal: sin push real, sin actualización garantizada en
   background, cuenta free limitada a 7 días. Extender a 4 modos no
   destraba ninguno de esos límites.

---

## Fuentes

Verificado con `curl` el 13-ago-2026 desde esta máquina:

- Ecobici GBFS 3.0 (vivo, sin token):
  [`buenosaires.publicbikesystem.net/customer/gbfs/v3.0/gbfs.json`](https://buenosaires.publicbikesystem.net/customer/gbfs/v3.0/gbfs.json)
- Catálogo GBFS oficial (para encontrar la URL real de Ecobici BA):
  [MobilityData/gbfs — `systems.csv`](https://github.com/MobilityData/gbfs/blob/master/systems.csv)
- GCBA API Transporte, endpoint de colectivos (401 sin key):
  `apitransporte.buenosaires.gob.ar/colectivos/vehiclePositions`
- Dataset "API Transporte Público" (aviso oficial de suspensión):
  [`data.buenosaires.gob.ar/dataset/api-transporte-publico`](https://data.buenosaires.gob.ar/dataset/api-transporte-publico)
- Colectivos GTFS estático (209 MB):
  [`data.buenosaires.gob.ar/dataset/colectivos-gtfs`](https://data.buenosaires.gob.ar/dataset/colectivos-gtfs)
- Colectivos GTFS por frecuencia (13,7 MB):
  [`data.buenosaires.gob.ar/dataset/colectivos-gtfs-frequency`](https://data.buenosaires.gob.ar/dataset/colectivos-gtfs-frequency)
- Subte GTFS estático (44 KB):
  [`data.buenosaires.gob.ar/dataset/subte-gtfs`](https://data.buenosaires.gob.ar/dataset/subte-gtfs)
- Subte: estaciones accesibles y bocas con accesibilidad por entrada:
  [`data.buenosaires.gob.ar/dataset/subte-estaciones`](https://data.buenosaires.gob.ar/dataset/subte-estaciones) ·
  [`data.buenosaires.gob.ar/dataset/bocas-subte`](https://data.buenosaires.gob.ar/dataset/bocas-subte)
- Cualbondi, verificado muerto hoy: `api.cualbondi.com.ar` (410 / TLS roto)
- Cuándo SUBO, app oficial nacional de colectivos en vivo:
  [`cuandosubo.sube.gob.ar`](https://cuandosubo.sube.gob.ar/) ·
  [nota LA NACION](https://www.lanacion.com.ar/buenos-aires/esta-es-la-app-que-te-dice-en-tiempo-real-cuando-llega-tu-colectivo-nid27022026/)
- Accesibilidad en el subte, contexto (LA NACION, sobre plan de renovación):
  [nota](https://www.lanacion.com.ar/sociedad/estos-son-los-planes-para-renovar-los-accesos-al-subte-que-no-funcionan-nid05062025/)
- RAPTOR (algoritmo de ruteo sin preprocesamiento), referencia técnica:
  [planarnetwork/raptor](https://github.com/planarnetwork/raptor) ·
  [gtfs.org — Using Data](https://gtfs.org/resources/using-data/)
- CloudKit, base pública sin servidor propio:
  [Apple Developer — CloudKit](https://developer.apple.com/documentation/cloudkitjs/cloudkit.database) ·
  [No-Backend iOS Development with Core Data and CloudKit](https://www.keremcanyesildag.com/blog/no-backend-ios-development/)
- CarPlay, proceso de entitlement y categorías:
  [Apple Developer — Requesting CarPlay Entitlements](https://developer.apple.com/documentation/carplay/requesting-carplay-entitlements)
- Citymapper CLUB, monetización de referencia:
  [Citymapper — CLUB features are now available to all](https://citymapper.com/news/2589/citymapper-club-features-are-now-available-to-all)
- Trafi, modelo de licenciamiento B2B/B2G:
  [Sifted — Has Trafi cracked mobility-as-a-service](https://sifted.eu/articles/trafi-series-b)
