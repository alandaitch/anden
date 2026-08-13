# Contratos de Shared/ para los feature agents

Todo es `internal`. Se importa por membership de source, no por module. No agregar `import` del core; los tipos ya están en el target. Importá solo frameworks del sistema (`SwiftUI`, `CoreLocation`, `MapKit`, `ActivityKit`).

## Models

### TrainLine (`Identifiable, Hashable`)
```swift
struct TrainLine {
    let id: Int          // == gerenciaId
    let nombre: String
    let shortCode: String  // "MI","SA","RO","BS","SM","TC","BN","UR","RG"
    let colorHex: String
    let covered: Bool      // Belgrano Norte(61)/Urquiza(71) = false
    var color: Color       // computed
}
static let all: [TrainLine]                 // 9 líneas
static let unknown: TrainLine               // id -1
static func line(id: Int) -> TrainLine      // fallback .unknown
static func line(nombre: String?) -> TrainLine  // sin acentos
```
IDs línea: 1 Sarmiento, 5 Mitre, 11 Roca, 21 Belgrano Sur, 31 San Martín, 41 Tren de la Costa, 61 Belgrano Norte, 71 Urquiza, 501 Regionales.

### Station (`Identifiable, Codable, Hashable`)
```swift
struct Station {
    let id: Int
    let nombre: String
    let lat: Double
    let lng: Double
    let linea: String?          // nullable (45 estaciones)
    let ramales: [Int]
    let ramalesOperativos: [Int]
    let gerenciaId: Int?        // nullable
    let visibleEnApp: Bool
    let enRamalPublico: Bool
    let tieneArribosHoy: Bool
    let distanciaObeliscoKm: Double
    let andenes: Int?           // nullable
    var coordinate: CLLocationCoordinate2D   // computed
    var line: TrainLine                       // computed (por gerenciaId o nombre)
}
```

### Ramal (`Identifiable, Codable, Hashable`)
```swift
struct Ramal {
    let id: Int
    let nombre: String?
    let siglas: String?
    let cabeceras: [String]
    let cabeceraInicialId: Int?
    let cabeceraFinalId: Int?
    let estaciones: Int?
    let esElectrico: Bool
    let operativo: Bool
    let toleranciaPuntualidadSegundos: Int?
    let tipoId: Int?
    var tolerancia: Int          // default 359
    var displayName: String
}
```

### Arrival (`Identifiable`) — modelo de dominio para la UI
```swift
struct Arrival {
    let id: String               // serviceId o clave derivada estable
    let serviceId: String?       // UUID del día (null en modo horario)
    let lineId: Int
    let line: TrainLine
    let ramalName: String
    let destinationName: String  // cabecera según sentido (nombreCorto)
    let originName: String
    let trackName: String?       // andén del arribo
    let scheduled: Date?
    let estimated: Date?
    let secondsUntil: Int
    let delay: DelayStatus
    let trainLocation: CLLocationCoordinate2D?  // GPS vivo (nil ~46%)
    let equipmentName: String?
    let isElectric: Bool
    let isCancelled: Bool
    let direction: Int           // 1 hacia cabecera final, 2 hacia inicial
    let stateName: String?       // ej "Partió","En Andén"
    let route: [RouteStop]
}
```
Init memberwise `internal` disponible si la UI necesita construir mocks. NO es Hashable/Equatable (contiene CLLocationCoordinate2D).

### RouteStop (`Identifiable, Hashable`)
```swift
struct RouteStop {
    let stationId: Int
    let name: String
    let order: Int
    let scheduled: Date?
    let estimated: Date?
    let trackName: String?
    let hasPassed: Bool          // llegada.real != nil
    var id: Int { order }
}
```

### ServiceAlert (`Identifiable, Hashable`)
```swift
struct ServiceAlert {
    let id: Int
    let lineId: Int?
    let ramalId: Int?
    let causeGTFS: String
    let effectGTFS: String
    let content: String
    let criticality: Int         // 1 corte, 2 demoras, 4 informativa
    let validFrom: Date?
    let validUntil: Date?
    var iconSystemName: String   // SF Symbol mapeado (efecto manda sobre causa)
}
```

### DelayStatus (`Equatable, Hashable`) — enum
```swift
enum DelayStatus {
    case onTime
    case early(seconds: Int)
    case minor(seconds: Int)
    case major(seconds: Int)
    case noData
    case cancelled
    var label: String        // "En horario","+3 min","-2 min","Sin datos","Cancelado"
    var shortLabel: String   // "En hora","+3","-2","S/D","Canc."
    var color: Color         // Palette semántico
    var delaySeconds: Int?   // con signo; nil en noData/cancelled
}
```
Reglas: sin `estimated` -> `.noData`. delay<-60s -> `.early`. delay<=tolerancia -> `.onTime`. <=2×tolerancia -> `.minor` (ámbar). más -> `.major` (rojo).

## Networking

### SofseClient (`actor`) — `SofseClient.shared`
```swift
func arrivals(stationId: Int, limit: Int = 12, toStationId: Int? = nil, ramalId: Int? = nil) async throws -> [Arrival]
func scheduledArrivals(stationId: Int, date: Date, time: String, toStationId: Int? = nil, limit: Int = 12) async throws -> [Arrival]  // time "HH:MM"
func alerts() async throws -> [ServiceAlert]   // degrada a [] si falla auth; NUNCA tira error de auth
```
`arrivals` ya filtra los que pasaron (llegada.real) y ordena por `secondsUntil` asc. Timeout 60s. Uso: `let list = try await SofseClient.shared.arrivals(stationId: 332)`.

### TokenProvider (`actor`) — `TokenProvider.shared`
```swift
func token(force: Bool = false) async throws -> String   // JWT crudo, sin "Bearer"
static func generateCredentials(date: Date = Date()) -> (username: String, password: String)
static func expiry(of jwt: String) -> Date?
```
Cachea el JWT 24h en App Group. La UI normalmente NO lo usa directo; `SofseClient.alerts()` lo maneja solo.

### APIError (`Error, LocalizedError`)
`.invalidURL`, `.http(status:body:)`, `.unauthorized`, `.decoding(Error)`, `.transport(Error)`, `.noToken`. Tienen `errorDescription` en es-AR.

### SofseDate (parseo de fechas)
```swift
static func iso(_ s: String?) -> Date?     // ISO UTC con Z
static func alert(_ s: String?) -> Date?   // "yyyy-MM-dd HH:mm:ss" hora local BsAs
```

## Catalog

### StationCatalog (`@Observable`) — `StationCatalog.shared`
```swift
private(set) var all: [Station]
private(set) var lines: [TrainLine]        // == TrainLine.all
func station(id: Int) -> Station?
func ramal(id: Int) -> Ramal?
func search(_ query: String) -> [Station]  // substring sin acento, prioriza público+arribosHoy, solo visibleEnApp
func nearest(to: CLLocationCoordinate2D, limit: Int = 5) -> [(Station, CLLocationDistance)]  // solo enRamalPublico
static func normalize(_ s: String) -> String
```
Carga estaciones.json + lineas.json de `Bundle.main` en init. Si faltan, `all == []` (no crashea; ojo en el widget si el bundle no tiene los JSON).

## Store

### FavoritesStore (`@Observable`) — `FavoritesStore.shared`
```swift
private(set) var items: [FavoriteStation]
func isFavorite(_ stationId: Int) -> Bool
func toggle(_ stationId: Int)
func setRole(_ role: FavoriteRole, for stationId: Int)
func role(for stationId: Int) -> FavoriteRole
var favorites: [Station]                       // resueltos contra el catálogo
func contextualPrimary(now: Date = Date()) -> Station?  // home 4-12h, work 12-22h, si no el primero
```
`FavoriteStation { let stationId: Int; var role: FavoriteRole; var addedAt: Date; var id: Int }`.
`enum FavoriteRole: String, Codable { case none, home, work }`. Persiste JSON en App Group `group.com.alandaitch.anden`.

### AppSettings (`@Observable`) — `AppSettings.shared`
```swift
var notifDemorasEnabled: Bool
var seguirServicioId: String?
var onboardingDone: Bool
```
Persisten en App Group al setear.

## Theme

```swift
Color(hex: "#1E7FD4")                  // init desde hex
enum Palette {
    static let onTime, minorDelay, majorDelay, noData, brand: Color
    static let background, surface, elevated: Color        // dinámicos light/dark
    static let textPrimary, textSecondary: Color
    static func dynamic(light:String, dark:String) -> Color
}
enum Theme { static func color(line:) -> Color; static func color(delay:) -> Color }
Color.line(_ line: TrainLine) -> Color
Color.delay(_ status: DelayStatus) -> Color
Font.anden(_ size: CGFloat, weight: .regular) -> Font     // rounded
Font.andenCountdown(_ size: CGFloat = 56) -> Font          // rounded + monospacedDigit
someView.andenCard()                    // fondo elevado, radius 18, sombra
struct LineBadgeStyle { init(line:); background; foreground; code }
```
Fondos: dark bg #0A0C10 / surface #151A22 / elevado #1E242E; light bg #EEF1F5 / surface+elevado #FFFFFF.

## Activity

### TrainActivityAttributes (`ActivityAttributes`)
```swift
struct TrainActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var eta: Date
        var delaySeconds: Int
        var statusLabel: String
        var trackName: String?
        var isCancelled: Bool
    }
    var stationName: String
    var destinationName: String
    var lineColorHex: String
    var lineShortCode: String
}
```
El widget usa este tipo para renderizar la Live Activity y el Dynamic Island. Countdown en pantalla con `Text(timerInterval:)` sobre `state.eta`.

## Logic (helpers puros)
```swift
enum DelayLogic {
    static let defaultTolerance = 359
    static func status(scheduled: Date?, estimated: Date?, secondsUntil: Int = 0, serverNow: Date? = nil, tolerance: Int = 359, isCancelled: Bool = false) -> DelayStatus
}
enum Formatting {
    static func etaText(secondsUntil: Int) -> String       // "ahora"/"llegando"/"en X min"
    static func minutesUntil(secondsUntil: Int) -> Int
    static func distanceText(meters: Double) -> String     // "a 320 m"/"a 1,2 km"
    static func clock(_ date: Date?) -> String             // "HH:mm" hora BsAs
}
enum ArrivalGrouping {
    struct Group: Identifiable { let id: String; let ramalName: String; let direction: Int; let destinationName: String; let arrivals: [Arrival] }
    static func byRamalDirection(_ arrivals: [Arrival]) -> [Group]
}
```

## Notas de foundation
Verificaciones: xcodegen generate OK; xcodebuild Debug iPhone 17 Pro simulator = BUILD SUCCEEDED, sin warnings en Shared/. El algoritmo de credenciales se portó a Swift y se validó byte-por-byte contra docs/sofse_client.py (username MjAyNjA4MTJzb2ZzZQ== y password v%23Q1VwJ0I4VVNxFFVS5kVFBnNZpmSjQ3I4xGcSBFVwMyZ idénticos). _bootstrap.swift borrado.

Decisiones de diseño y desviaciones del plan:
- shortCodes elegidos: SA, MI, RO, BS, SM, TC, BN, UR, RG.
- DelayStatus.minor vs major: onTime <= tolerancia; minor hasta 2×tolerancia; major más allá. El plan no fijaba el corte exacto; usé la tolerancia del ramal como unidad, con default 359s.
- early: estimada < programada por >60s.
- urlencode del password replica urllib.parse.quote con safe='/' (no codifica letras/dígitos/_.-~/, sí codifica '#'->%23 y '+'->%2B). Verificado.
- Fechas: dos parsers. iso() para UTC con Z (arribos), alert() para "yyyy-MM-dd HH:mm:ss" hora local BsAs (alertas). Las fechas se decodifican como String? en los DTOs y se parsean en el mapeo, evitando dateDecodingStrategy frágil con nulls.
- Station.linea/gerenciaId/andenes son opcionales: 45 estaciones tienen linea/gerenciaId null y 4 andenes null en estaciones.json.
- cancelacion (tipo desconocido, siempre null en la muestra) se detecta por presencia via AnyJSON; isCancelled = cancelacion != nil.
- CabeceraDTO maneja nombreCorto (vivo) y nombre_corto (horario) en el mismo decoder.
- alerts() usa async let para pegarle a gerencias+ramales en paralelo y degrada a [] ante cualquier error (auth o red), como pide el plan.
- StationCatalog carga de Bundle.main y degrada a [] si faltan los JSON (relevante para el widget, cuyo target hoy no incluye Anden/Resources en project.yml; no toqué project.yml por regla).
- Todos los tipos internal; el widget los ve por source membership. No hizo falta public.
- No toqué project.yml, Anden/ ni Widget/.