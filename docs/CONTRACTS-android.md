CAPA DE DATOS Andén Android — API pública para agentes de UI Compose. Package base com.alandaitch.anden. Fechas = java.time.Instant. Coordenada = util.GeoPoint(lat:Double,lng:Double). Todos los métodos de red son suspend y lanzan data.net.ApiError. Cada componente con estado tiene un singleton `.shared` que usa AndenApp.appContext (AndenApp ya registrada en el manifest; NO instanciar catálogos/stores/APIs manualmente en composables, usar .shared).

=== APP ===
class AndenApp : Application  // companion: AndenApp.instance, AndenApp.appContext: Context

=== util ===
data class GeoPoint(val lat: Double, val lng: Double)
object Geo { fun distanceMeters(a: GeoPoint, b: GeoPoint): Double }  // haversine, metros
object Text { fun normalize(s: String): String }  // sin acentos, minúscula, trim
object DelayLogic { const val DEFAULT_TOLERANCE=359; const val EARLY_THRESHOLD=60; fun status(scheduled: Instant?, estimated: Instant?, secondsUntil: Int=0, serverNow: Instant?=null, tolerance: Int=DEFAULT_TOLERANCE, isCancelled: Boolean=false): DelayStatus }
object Formatting { fun etaText(secondsUntil: Int): String; fun minutesUntil(secondsUntil: Int): Int; fun distanceText(meters: Double): String; fun clock(instant: Instant?): String }  // es-AR, zona America/Argentina/Buenos_Aires
object ArrivalGrouping { data class Group(val id: String, val ramalName: String, val direction: Int, val destinationName: String, val arrivals: List<Arrival>); fun byRamalDirection(arrivals: List<Arrival>): List<Group> }
object MapsOpener { fun walk(context: Context, to: GeoPoint, name: String); fun transit(context: Context, to: GeoPoint, name: String) }  // Intent google.navigation con fallback web maps

=== ui.theme (androidx.compose.ui.graphics.Color) ===
fun hexColor(hex: String): Color
object Palette { val onTime; val minorDelay; val majorDelay; val noData; val brand: Color (fijos). Pares claro/oscuro: backgroundLight/Dark, surfaceLight/Dark, elevatedLight/Dark, textPrimaryLight/Dark, textSecondaryLight/Dark. Helpers: fun background(dark: Boolean): Color; surface(dark); elevated(dark); textPrimary(dark); textSecondary(dark) }
// NOTA UI: no hay AndenTheme/Typography; los agentes de UI arman MaterialTheme y eligen variante clara/oscura con Palette.xxx(dark=isSystemInDarkTheme()).

=== data.model ===
data class TrainLine(id: Int, nombre: String, shortCode: String, colorHex: String, covered: Boolean) { val color: Color; companion: val all: List<TrainLine> (9), val unknown, fun line(id: Int): TrainLine, fun line(nombre: String?): TrainLine }
@Serializable data class Station(id, nombre, lat, lng, linea: String?, ramales: List<Int>, ramalesOperativos: List<Int>, gerenciaId: Int?, visibleEnApp: Boolean, enRamalPublico: Boolean, tieneArribosHoy: Boolean, distanciaObeliscoKm: Double, andenes: Int?) { val coordinate: GeoPoint; val line: TrainLine }
@Serializable data class Ramal(id, nombre: String?, siglas: String?, cabeceras: List<String>, cabeceraInicialId: Int?, cabeceraFinalId: Int?, estaciones: Int?, esElectrico: Boolean, operativo: Boolean, toleranciaPuntualidadSegundos: Int?, tipoId: Int?) { val tolerancia: Int; val displayName: String }
sealed class DelayStatus { OnTime, Early(seconds: Int), Minor(seconds: Int), Major(seconds: Int), NoData, Cancelled; val label: String; val shortLabel: String; val color: Color; val delaySeconds: Int? }
data class RouteStop(stationId: Int, name: String, order: Int, scheduled: Instant?, estimated: Instant?, trackName: String?, hasPassed: Boolean) { val id: Int }
data class Arrival(id: String, serviceId: String?, lineId: Int, line: TrainLine, ramalName: String, destinationName: String, originName: String, trackName: String?, scheduled: Instant?, estimated: Instant?, secondsUntil: Int, delay: DelayStatus, trainLocation: GeoPoint?, equipmentName: String?, isElectric: Boolean, isCancelled: Boolean, direction: Int, stateName: String?, route: List<RouteStop>)
data class ServiceAlert(id: Int, lineId: Int?, ramalId: Int?, causeGTFS: String, effectGTFS: String, content: String, criticality: Int, validFrom: Instant?, validUntil: Instant?) { val iconName: String }  // iconName = clave string (block/schedule_alert/alt_route/warning/build/...) que la UI mapea a ImageVector
data class SubteLine(routeId: String, letra: String, nombre: String, colorHex: String) { val id: String; val color: Color; companion: val all (A,B,C,D,E,H,Premetro), val unknown, fun line(routeId: String): SubteLine }
const val SUBTE_TOLERANCE = 120
data class SubteStop(stopId, name, eta: Instant, delaySeconds: Int, delay: DelayStatus) { val id: String; companion fun create(stopId, name, eta, delaySeconds, tolerance=SUBTE_TOLERANCE): SubteStop }
data class SubteTrip(line: SubteLine, direction: Int, stops: List<SubteStop>)
data class SubteArrival(line: SubteLine, direction: Int, destinationName: String, eta: Instant, secondsUntil: Int, delay: DelayStatus) { val id: String }
data class SubteAlertItem(line: SubteLine, text: String, effect: Int) { val id: String; val iconName: String; val severity: Int }
data class EcobiciStation(id: String, name, lat, lng, capacity: Int, bikesMechanical: Int, bikesEbike: Int, bikesTotal: Int, docksAvailable: Int, status: String, lastReported: Instant) { val coordinate: GeoPoint; val displayName: String }
data class BusPosition(id: String, coordinate: GeoPoint, routeId: String?, bearing: Double?, interno: String?, patente: String?)
data class BusStop(code: String, name, lat, lng) { val id: String; val coordinate: GeoPoint }
data class BusArrival(lineName: String, destino: String?, eta: Instant, secondsUntil: Int, delay: DelayStatus) { val id: String }
data class BusLine(routeId: String, shortName: String, longName: String) { val id: String; val color: Color; companion fun color(shortName: String): Color }

=== data.net ===
sealed class ApiError : Exception { InvalidUrl, Http(status: Int, body: String?), Unauthorized, Decoding(error: Throwable), Transport(error: Throwable), NoToken, ServiceUnavailable(info: String?) }  // .message ya en español
object SofseDate { fun iso(s: String?): Instant?; fun alert(s: String?): Instant? }
class TokenProvider { companion val shared; suspend fun token(force: Boolean=false): String; companion fun generateCredentials(now=UTC): Credentials(username,password); fun expiry(jwt: String): Long? }  // token crudo sin Bearer, cache 24h
class SofseApi { companion val shared; suspend fun arrivals(stationId: Int, limit: Int=12, toStationId: Int?=null, ramalId: Int?=null): List<Arrival>; suspend fun scheduledArrivals(stationId: Int, date: Instant, time: String, toStationId: Int?=null, limit: Int=12): List<Arrival>; suspend fun alerts(): List<ServiceAlert> }  // arrivals sin token, alerts con token; alerts degrada a [] ante fallo
class BaApi { companion val shared; suspend fun subteTrips(): List<SubteTrip>; suspend fun subteStations(line: SubteLine): List<String>; suspend fun subteArrivals(stationName: String): List<SubteArrival>; suspend fun subteAlerts(): List<SubteAlertItem>; suspend fun ecobiciStations(): List<EcobiciStation>; suspend fun colectivoPositions(near: GeoPoint?=null, maxCount: Int=350): List<BusPosition>; suspend fun colectivoArrivals(stopCode: String): List<BusArrival> }  // auth por BuildConfig.BA_CLIENT_ID/SECRET; sin key lanza ApiError.NoToken; colectivoArrivals lanza ApiError.ServiceUnavailable si 503/backend caído
object GtfsRealtime { fun parseVehiclePositions(data: ByteArray): List<BusPosition> }  // + top-level fun parseVehiclePositions(data: ByteArray): List<BusPosition>

=== data.catalog (todos con companion val shared) ===
class StationCatalog { val all: List<Station>; val lines: List<TrainLine>; fun station(id: Int): Station?; fun ramal(id: Int): Ramal?; fun search(query: String): List<Station>; fun nearest(to: GeoPoint, limit: Int=5): List<Pair<Station,Double>>; companion fun normalize(s: String): String }
data class SubteStation(name: String, line: SubteLine, lat: Double, lng: Double, aliases: List<String>) { val id: String; val coordinate: GeoPoint }
class SubteCatalog { val all: List<SubteStation>; fun nearest(to: GeoPoint, limit: Int=5): List<Pair<SubteStation,Double>>; fun station(name: String): SubteStation? }
class ColectivoCatalog { val lines: List<BusLine>; val stops: List<BusStop>; fun line(routeId: String): BusLine?; fun displayLine(routeId: String): String; fun nearbyStops(to: GeoPoint, limit: Int=12): List<Pair<BusStop,Double>> }
// nearest/nearbyStops devuelven Pair<modelo, distanciaMetros> ordenado ascendente.

=== data.store (companion val shared) ===
class AppSettings { var notifDemorasEnabled: Boolean; var seguirServicioId: String?; var onboardingDone: Boolean }  // getters/setters persisten en SharedPreferences
enum class FavoriteRole { NONE, HOME, WORK }
@Serializable data class FavoriteStation(stationId: Int, role: FavoriteRole=NONE, addedAtEpoch: Long) { val id: Int }
class FavoritesStore { val itemsFlow: StateFlow<List<FavoriteStation>>; val items: List<FavoriteStation>; fun isFavorite(stationId: Int): Boolean; fun toggle(stationId: Int); fun setRole(role: FavoriteRole, stationId: Int); fun role(stationId: Int): FavoriteRole; val favorites: List<Station>; fun contextualPrimary(now: Instant=now): Station? }  // observar itemsFlow con collectAsState()

=== data.location ===
class LocationProvider { companion val shared; val location: StateFlow<Location?>; val hasPermission: StateFlow<Boolean>; val point: GeoPoint?; fun computePermission(): Boolean; fun refreshPermission(); fun start(minTimeMs: Long=5000, minDistanceM: Float=20f); fun stop(); fun lastKnown(): Location? }  // android.location.LocationManager, sin Play services. La UI pide ACCESS_FINE/COARSE_LOCATION, luego refreshPermission()+start(). location es android.location.Location; usar .point para GeoPoint.