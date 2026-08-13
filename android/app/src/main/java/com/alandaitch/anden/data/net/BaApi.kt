package com.alandaitch.anden.data.net

import com.alandaitch.anden.BuildConfig
import com.alandaitch.anden.data.catalog.ColectivoCatalog
import com.alandaitch.anden.data.catalog.StationCatalog
import com.alandaitch.anden.data.model.BusArrival
import com.alandaitch.anden.data.model.BusPosition
import com.alandaitch.anden.data.model.EcobiciStation
import com.alandaitch.anden.data.model.SUBTE_TOLERANCE
import com.alandaitch.anden.data.model.SubteAlertItem
import com.alandaitch.anden.data.model.SubteArrival
import com.alandaitch.anden.data.model.SubteLine
import com.alandaitch.anden.data.model.SubteStop
import com.alandaitch.anden.data.model.SubteTrip
import com.alandaitch.anden.util.DelayLogic
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.withContext
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import okhttp3.HttpUrl.Companion.toHttpUrl
import okhttp3.OkHttpClient
import okhttp3.Request
import java.time.Instant
import java.util.concurrent.TimeUnit

// Cliente de la API Transporte BA (subte + EcoBici + colectivos). Auth por query string.
// Si faltan las credenciales (BuildConfig vacío) tira ApiError.NoToken.
class BaApi(
    private val client: OkHttpClient = defaultClient(),
    private val colectivoCatalog: ColectivoCatalog = ColectivoCatalog.shared
) {
    private val base = "https://apitransporte.buenosaires.gob.ar"
    private val json = Json { ignoreUnknownKeys = true }

    private val clientId = BuildConfig.BA_CLIENT_ID
    private val clientSecret = BuildConfig.BA_CLIENT_SECRET
    private val isConfigured: Boolean get() = clientId.isNotEmpty() && clientSecret.isNotEmpty()

    // MARK: - Subte: arribos en vivo

    // Todos los trenes activos con sus paradas restantes.
    suspend fun subteTrips(): List<SubteTrip> {
        val data = getString("subtes/forecastGTFS", mapOf("json" to "1"))
        val resp = decode<ForecastResponse>(data)

        val trips = mutableListOf<SubteTrip>()
        for (entity in resp.Entity ?: emptyList()) {
            val linea = entity.Linea ?: continue
            val routeId = linea.Route_Id ?: continue
            val line = SubteLine.line(routeId)
            val direction = linea.Direction_ID ?: 0

            val stops = mutableListOf<SubteStop>()
            for (e in linea.Estaciones ?: emptyList()) {
                val sid = e.stop_id ?: continue
                val epoch = e.arrival?.time ?: continue
                val eta = Instant.ofEpochSecond(epoch)
                stops.add(
                    SubteStop.create(
                        stopId = sid,
                        name = e.stop_name ?: "",
                        eta = eta,
                        delaySeconds = e.arrival?.delay ?: 0
                    )
                )
            }
            if (stops.isEmpty()) continue
            trips.add(SubteTrip(line, direction, stops))
        }
        return trips
    }

    // Lista ordenada de estaciones de una línea, derivada de sus trips. Sin trips -> [].
    suspend fun subteStations(line: SubteLine): List<String> {
        val trips = subteTrips().filter { it.line.routeId == line.routeId }
        if (trips.isEmpty()) return emptyList()

        val seen = HashSet<String>()
        val out = mutableListOf<String>()
        // El trip más largo define el orden base; los demás completan huecos.
        for (trip in trips.sortedByDescending { it.stops.size }) {
            for (stop in trip.stops) {
                val name = stop.name
                if (name.isEmpty()) continue
                val key = StationCatalog.normalize(name)
                if (seen.contains(key)) continue
                seen.add(key)
                out.add(name)
            }
        }
        return out
    }

    // Arribos para el tablero de una estación, ordenados por tiempo. Filtra los que ya pasaron.
    suspend fun subteArrivals(stationName: String): List<SubteArrival> {
        val trips = subteTrips()
        val target = StationCatalog.normalize(stationName)
        val now = Instant.now()

        val out = mutableListOf<SubteArrival>()
        for (trip in trips) {
            val stop = trip.stops.firstOrNull { StationCatalog.normalize(it.name) == target } ?: continue
            val secondsUntil = (stop.eta.epochSecond - now.epochSecond).toInt()
            if (secondsUntil < 0) continue
            val destination = trip.stops.lastOrNull()?.name ?: ""
            out.add(
                SubteArrival(
                    line = trip.line,
                    direction = trip.direction,
                    destinationName = destination,
                    eta = stop.eta,
                    secondsUntil = secondsUntil,
                    delay = stop.delay
                )
            )
        }
        return out.sortedBy { it.secondsUntil }
    }

    // MARK: - Subte: estado de servicio

    suspend fun subteAlerts(): List<SubteAlertItem> {
        val data = getString("subtes/serviceAlerts", mapOf("json" to "1"))
        val resp = decode<AlertsResponse>(data)

        val out = mutableListOf<SubteAlertItem>()
        for (entity in resp.entity ?: emptyList()) {
            val alert = entity.alert ?: continue
            val text = alert.header_text?.translation?.firstOrNull()?.text ?: ""
            if (text.isEmpty()) continue
            val routeId = alert.informed_entity?.firstOrNull()?.route_id ?: ""
            out.add(
                SubteAlertItem(
                    line = SubteLine.line(routeId),
                    text = text,
                    effect = alert.effect ?: 7
                )
            )
        }
        return out.sortedBy { it.severity }
    }

    // MARK: - EcoBici

    // Une stationInformation + stationStatus por station_id (en paralelo).
    suspend fun ecobiciStations(): List<EcobiciStation> = coroutineScope {
        val infoTask = async { getString("ecobici/gbfs/stationInformation", emptyMap()) }
        val statusTask = async { getString("ecobici/gbfs/stationStatus", emptyMap()) }
        val info = decode<GbfsInfoResponse>(infoTask.await())
        val status = decode<GbfsStatusResponse>(statusTask.await())

        val statusById = HashMap<String, GbfsStatusStation>()
        for (s in status.data?.stations ?: emptyList()) {
            s.station_id?.let { statusById[it] = s }
        }

        val out = mutableListOf<EcobiciStation>()
        for (i in info.data?.stations ?: emptyList()) {
            val id = i.station_id ?: continue
            val s = statusById[id]
            val mechanical = s?.num_bikes_available_types?.mechanical ?: 0
            val ebike = s?.num_bikes_available_types?.ebike ?: 0
            val total = s?.num_bikes_available ?: (mechanical + ebike)
            val reported = s?.last_reported?.let { Instant.ofEpochSecond(it) } ?: Instant.now()
            out.add(
                EcobiciStation(
                    id = id,
                    name = i.name ?: "",
                    lat = i.lat ?: 0.0,
                    lng = i.lon ?: 0.0,
                    capacity = i.capacity ?: 0,
                    bikesMechanical = mechanical,
                    bikesEbike = ebike,
                    bikesTotal = total,
                    docksAvailable = s?.num_docks_available ?: 0,
                    status = s?.status ?: "UNKNOWN",
                    lastReported = reported
                )
            )
        }
        out
    }

    // MARK: - Colectivos: posiciones GPS en vivo

    // Todos los colectivos con GPS (protobuf, sin json). Decodifica con GtfsRealtime.
    // Si 'near' está dado, ordena por cercanía y corta a maxCount (perf del mapa).
    suspend fun colectivoPositions(
        near: com.alandaitch.anden.util.GeoPoint? = null,
        maxCount: Int = 350
    ): List<BusPosition> {
        val data = getBytes("colectivos/vehiclePositions", emptyMap(), accept = "application/x-protobuf")
        var positions = parseVehiclePositions(data)
        if (near != null) {
            val cosLat = Math.cos(near.lat * Math.PI / 180)
            fun approx(p: BusPosition): Double {
                val dLat = p.coordinate.lat - near.lat
                val dLng = (p.coordinate.lng - near.lng) * cosLat
                return dLat * dLat + dLng * dLng
            }
            positions = positions.sortedBy { approx(it) }
        }
        if (positions.size > maxCount) positions = positions.take(maxCount)
        return positions
    }

    // MARK: - Colectivos: arribos por parada ("cuándo llega")

    // Pronóstico de una parada. OJO: hoy el backend SOAP de BA devuelve 503.
    // Detecta 503 o JSON-de-error y tira ApiError.ServiceUnavailable con mensaje claro.
    suspend fun colectivoArrivals(stopCode: String): List<BusArrival> {
        val data: String = try {
            getString("colectivos/forecastGTFS", mapOf("StopCode" to stopCode, "json" to "1"))
        } catch (e: ApiError.Http) {
            if (e.status == 503) throw ApiError.ServiceUnavailable(colectivoDownMessage)
            throw e
        }
        // El backend a veces responde 200 con un cuerpo de error JSON.
        runCatching { decode<BAErrorEnvelope>(data) }.getOrNull()?.let {
            if (it.error != null) throw ApiError.ServiceUnavailable(colectivoDownMessage)
        }
        val resp = decode<ForecastResponse>(data)
        val now = Instant.now()

        val out = mutableListOf<BusArrival>()
        for (entity in resp.Entity ?: emptyList()) {
            val linea = entity.Linea ?: continue
            val stops = linea.Estaciones ?: emptyList()
            val stop = stops.firstOrNull { it.stop_id == stopCode } ?: stops.firstOrNull() ?: continue
            val epoch = stop.arrival?.time ?: continue
            val eta = Instant.ofEpochSecond(epoch)
            val secondsUntil = (eta.epochSecond - now.epochSecond).toInt()
            if (secondsUntil < 0) continue

            val lineName = colectivoCatalog.displayLine(linea.Route_Id ?: "")
            val destino = stops.lastOrNull()?.stop_name
            val delaySeconds = stop.arrival?.delay ?: 0
            val scheduled = eta.minusSeconds(delaySeconds.toLong())
            val delay = DelayLogic.status(scheduled = scheduled, estimated = eta, tolerance = SUBTE_TOLERANCE)
            out.add(
                BusArrival(
                    lineName = lineName,
                    destino = destino,
                    eta = eta,
                    secondsUntil = secondsUntil,
                    delay = delay
                )
            )
        }
        return out.sortedBy { it.secondsUntil }
    }

    // MARK: - Red

    private suspend fun getString(path: String, flags: Map<String, String>): String =
        String(getBytes(path, flags, "application/json"), Charsets.UTF_8)

    private suspend fun getBytes(
        path: String,
        flags: Map<String, String>,
        accept: String
    ): ByteArray = withContext(Dispatchers.IO) {
        if (!isConfigured) throw ApiError.NoToken

        val urlBuilder = "$base/$path".toHttpUrl().newBuilder()
        urlBuilder.addQueryParameter("client_id", clientId)
        urlBuilder.addQueryParameter("client_secret", clientSecret)
        for ((k, v) in flags) urlBuilder.addQueryParameter(k, v)

        val req = Request.Builder()
            .url(urlBuilder.build())
            .header("Accept", accept)
            .build()

        val response = try {
            client.newCall(req).execute()
        } catch (e: Exception) {
            throw ApiError.Transport(e)
        }
        val code = response.code
        val bytes = response.body?.bytes() ?: ByteArray(0)
        response.close()

        if (code == 401 || code == 403) throw ApiError.Unauthorized
        if (code !in 200..299) throw ApiError.Http(code, String(bytes, Charsets.UTF_8))
        bytes
    }

    private inline fun <reified T> decode(data: String): T {
        return try {
            json.decodeFromString(data)
        } catch (e: Exception) {
            throw ApiError.Decoding(e)
        }
    }

    companion object {
        val shared: BaApi by lazy { BaApi() }

        private const val colectivoDownMessage =
            "El servicio de arribos de colectivos de la Ciudad no está disponible ahora. Probá más tarde."

        private fun defaultClient(): OkHttpClient = OkHttpClient.Builder()
            .callTimeout(30, TimeUnit.SECONDS)
            .connectTimeout(30, TimeUnit.SECONDS)
            .readTimeout(30, TimeUnit.SECONDS)
            .build()
    }
}

// MARK: - DTOs forecastGTFS

@Serializable
private data class ForecastResponse(val Entity: List<ForecastEntity>? = null)

@Serializable
private data class ForecastEntity(val Linea: ForecastLinea? = null)

@Serializable
private data class ForecastLinea(
    val Trip_Id: String? = null,
    val Route_Id: String? = null,
    val Direction_ID: Int? = null,
    val Estaciones: List<ForecastStop>? = null
)

@Serializable
private data class ForecastStop(
    val stop_id: String? = null,
    val stop_name: String? = null,
    val arrival: ForecastTime? = null
)

@Serializable
private data class ForecastTime(val time: Long? = null, val delay: Int? = null)

// Cuerpo de error que el gateway de BA devuelve cuando el backend SOAP cae.
@Serializable
private data class BAErrorEnvelope(val error: String? = null)

// MARK: - DTOs serviceAlerts

@Serializable
private data class AlertsResponse(val entity: List<AlertEntity>? = null)

@Serializable
private data class AlertEntity(val alert: AlertBody? = null)

@Serializable
private data class AlertBody(
    val informed_entity: List<InformedEntity>? = null,
    val cause: Int? = null,
    val effect: Int? = null,
    val header_text: TranslatedText? = null
)

@Serializable
private data class InformedEntity(val route_id: String? = null)

@Serializable
private data class TranslatedText(val translation: List<Translation>? = null)

@Serializable
private data class Translation(val text: String? = null, val language: String? = null)

// MARK: - DTOs EcoBici GBFS

@Serializable
private data class GbfsInfoResponse(val data: GbfsInfoData? = null)

@Serializable
private data class GbfsInfoData(val stations: List<GbfsInfoStation>? = null)

@Serializable
private data class GbfsInfoStation(
    val station_id: String? = null,
    val name: String? = null,
    val lat: Double? = null,
    val lon: Double? = null,
    val capacity: Int? = null
)

@Serializable
private data class GbfsStatusResponse(val data: GbfsStatusData? = null)

@Serializable
private data class GbfsStatusData(val stations: List<GbfsStatusStation>? = null)

@Serializable
private data class GbfsStatusStation(
    val station_id: String? = null,
    val num_bikes_available: Int? = null,
    val num_docks_available: Int? = null,
    val num_bikes_available_types: GbfsBikeTypes? = null,
    val status: String? = null,
    val last_reported: Long? = null
)

@Serializable
private data class GbfsBikeTypes(val mechanical: Int? = null, val ebike: Int? = null)
