package com.alandaitch.anden.data.net

import com.alandaitch.anden.data.model.BusArrivalOba
import com.alandaitch.anden.data.model.BusLineNearby
import com.alandaitch.anden.util.Geo
import com.alandaitch.anden.util.GeoPoint
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeoutOrNull
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import okhttp3.HttpUrl.Companion.toHttpUrl
import okhttp3.OkHttpClient
import okhttp3.Request
import java.time.Instant
import java.util.concurrent.TimeUnit

// Cliente OneBusAway de cuandosubo (SUBE). Da arribos de colectivo en vivo.
// key=web es una key PÚBLICA de la webapp, no un secreto. Se embebe.
class ObaApi(
    private val client: OkHttpClient = defaultClient()
) {
    private val base = "https://cuandosubo.sube.gob.ar/onebusaway-api-webapp/api/where"
    private val key = "web"
    private val json = Json { ignoreUnknownKeys = true }

    // "Líneas cercanas con cuándo llega" (algoritmo de 4 pasos):
    // 1) paradas alrededor del usuario. 2) arribos de las maxStops más cercanas en
    // paralelo (timeout 15s). 3) agrupar por (línea + destino), próximo arribo futuro.
    // 4) ordenar por minutos.
    suspend fun nearbyBusLines(
        near: GeoPoint,
        radius: Int = 500,
        maxStops: Int = 10
    ): List<BusLineNearby> {
        val stops = nearbyStops(near, radius)
            .sortedBy { Geo.distanceMeters(near, GeoPoint(it.lat ?: 0.0, it.lon ?: 0.0)) }
            .take(maxStops)
        if (stops.isEmpty()) return emptyList()

        val now = Instant.now().epochSecond

        val perStop: List<List<BusLineNearby>> = withTimeoutOrNull(15_000) {
            coroutineScope {
                stops.map { stop ->
                    async {
                        val sid = stop.id ?: return@async emptyList<BusLineNearby>()
                        val lat = stop.lat ?: 0.0
                        val lon = stop.lon ?: 0.0
                        val name = stop.name ?: "Parada"
                        val arrivals = try {
                            stopArrivalsRaw(sid)
                        } catch (_: Exception) {
                            emptyList()
                        }
                        arrivals.mapNotNull { a ->
                            val short = a.routeShortName ?: return@mapNotNull null
                            val predicted = a.predicted == true && (a.predictedArrivalTime ?: 0L) > 0L
                            val millis = if (predicted) a.predictedArrivalTime!! else (a.scheduledArrivalTime ?: return@mapNotNull null)
                            val etaSec = millis / 1000
                            val secondsUntil = (etaSec - now).toInt()
                            if (secondsUntil < 0) return@mapNotNull null
                            BusLineNearby(
                                lineShort = short,
                                headsign = a.tripHeadsign ?: "",
                                eta = Instant.ofEpochSecond(etaSec),
                                secondsUntil = secondsUntil,
                                isLive = predicted,
                                stopName = name,
                                stopId = sid,
                                stopLat = lat,
                                stopLng = lon
                            )
                        }
                    }
                }.awaitAll()
            }
        } ?: emptyList()

        // Agrupar por (línea + destino): próximo arribo futuro (menor secondsUntil).
        val byGroup = HashMap<String, BusLineNearby>()
        for (list in perStop) {
            for (item in list) {
                val gkey = "${item.lineShort}|${item.headsign}"
                val prev = byGroup[gkey]
                if (prev == null || item.secondsUntil < prev.secondsUntil) {
                    byGroup[gkey] = item
                }
            }
        }
        return byGroup.values.sortedBy { it.secondsUntil }
    }

    // Arribos de una parada (para el tablero). Ordenados por tiempo, futuros.
    suspend fun stopArrivals(stopId: String): List<BusArrivalOba> {
        val now = Instant.now().epochSecond
        return stopArrivalsRaw(stopId).mapNotNull { a ->
            val short = a.routeShortName ?: return@mapNotNull null
            val predicted = a.predicted == true && (a.predictedArrivalTime ?: 0L) > 0L
            val millis = if (predicted) a.predictedArrivalTime!! else (a.scheduledArrivalTime ?: return@mapNotNull null)
            val etaSec = millis / 1000
            val secondsUntil = (etaSec - now).toInt()
            // Tolerancia -45s (paridad con iOS): no ocultar el coche justo al llegar.
            if (secondsUntil < -45) return@mapNotNull null
            BusArrivalOba(
                lineShort = short,
                headsign = a.tripHeadsign ?: "",
                eta = Instant.ofEpochSecond(etaSec),
                secondsUntil = maxOf(0, secondsUntil),
                isLive = predicted,
                vehicle = liveVehicle(a),
                tripId = a.tripId
            )
        }.sortedBy { it.secondsUntil }
    }

    // Traza del recorrido del viaje del coche: trip -> shapeId -> shape (polyline).
    // Devuelve [] ante cualquier falla. Se cachea por tripId.
    private val shapeCache = java.util.concurrent.ConcurrentHashMap<String, List<GeoPoint>>()
    suspend fun tripShape(tripId: String): List<GeoPoint> {
        shapeCache[tripId]?.let { return it }
        val shapeId = try {
            decode<ObaResponse<ObaTripData>>(get("trip/$tripId.json", emptyMap())).data?.entry?.shapeId
        } catch (_: Exception) { null } ?: return emptyList()
        if (shapeId.isEmpty()) return emptyList()
        val points = try {
            decode<ObaResponse<ObaShapeData>>(get("shape/$shapeId.json", emptyMap())).data?.entry?.points
        } catch (_: Exception) { null } ?: return emptyList()
        val coords = decodePolyline(points)
        shapeCache[tripId] = coords
        return coords
    }

    // Decodifica una polyline codificada de Google en coordenadas.
    private fun decodePolyline(encoded: String): List<GeoPoint> {
        val out = ArrayList<GeoPoint>()
        var index = 0
        var lat = 0
        var lng = 0
        while (index < encoded.length) {
            var shift = 0
            var result = 0
            while (true) {
                val b = encoded[index++].code - 63
                result = result or ((b and 0x1F) shl shift)
                shift += 5
                if (b < 0x20) break
            }
            lat += if (result and 1 != 0) (result shr 1).inv() else result shr 1
            shift = 0
            result = 0
            while (true) {
                val b = encoded[index++].code - 63
                result = result or ((b and 0x1F) shl shift)
                shift += 5
                if (b < 0x20) break
            }
            lng += if (result and 1 != 0) (result shr 1).inv() else result shr 1
            out.add(GeoPoint(lat / 1e5, lng / 1e5))
        }
        return out
    }

    // Posición GPS del coche SOLO si OBA la da en vivo (tripStatus.predicted).
    // Prefiere position (proyectada al recorrido); si viene inválida (0,0 o nula),
    // cae al último GPS crudo. Valida cada candidato por separado, no solo presencia.
    private fun liveVehicle(a: ObaArrival): GeoPoint? {
        val ts = a.tripStatus ?: return null
        if (ts.predicted != true) return null
        return validCoord(ts.position) ?: validCoord(ts.lastKnownLocation)
    }

    private fun validCoord(c: ObaCoord?): GeoPoint? {
        val lat = c?.lat ?: return null
        val lon = c?.lon ?: return null
        if (lat == 0.0 || lon == 0.0) return null
        return GeoPoint(lat, lon)
    }

    // MARK: - Endpoints crudos

    private suspend fun nearbyStops(near: GeoPoint, radius: Int): List<ObaStop> {
        val data = get(
            "stops-for-location.json",
            mapOf("lat" to near.lat.toString(), "lon" to near.lng.toString(), "radius" to radius.toString())
        )
        return decode<ObaResponse<ObaListData<ObaStop>>>(data).data?.list ?: emptyList()
    }

    private suspend fun stopArrivalsRaw(stopId: String): List<ObaArrival> {
        val data = get("arrivals-and-departures-for-stop/$stopId.json", emptyMap())
        return decode<ObaResponse<ObaEntryData>>(data).data?.entry?.arrivalsAndDepartures ?: emptyList()
    }

    // MARK: - Red

    private suspend fun get(path: String, params: Map<String, String>): String = withContext(Dispatchers.IO) {
        val urlBuilder = "$base/$path".toHttpUrl().newBuilder()
        urlBuilder.addQueryParameter("key", key)
        for ((k, v) in params) urlBuilder.addQueryParameter(k, v)

        val req = Request.Builder().url(urlBuilder.build()).header("Accept", "application/json").build()
        val response = try {
            client.newCall(req).execute()
        } catch (e: Exception) {
            throw ApiError.Transport(e)
        }
        val code = response.code
        val body = response.body?.string() ?: ""
        response.close()
        if (code == 401 || code == 403) throw ApiError.Unauthorized
        if (code !in 200..299) throw ApiError.Http(code, body)
        body
    }

    private inline fun <reified T> decode(data: String): T {
        return try {
            json.decodeFromString(data)
        } catch (e: Exception) {
            throw ApiError.Decoding(e)
        }
    }

    companion object {
        val shared: ObaApi by lazy { ObaApi() }

        private fun defaultClient(): OkHttpClient = OkHttpClient.Builder()
            .callTimeout(15, TimeUnit.SECONDS)
            .connectTimeout(15, TimeUnit.SECONDS)
            .readTimeout(15, TimeUnit.SECONDS)
            .build()
    }
}

// MARK: - DTOs OneBusAway

@Serializable
private data class ObaResponse<T>(val data: T? = null)

@Serializable
private data class ObaListData<T>(val list: List<T>? = null)

@Serializable
private data class ObaEntryData(val entry: ObaEntry? = null)

@Serializable
private data class ObaEntry(val arrivalsAndDepartures: List<ObaArrival>? = null)

@Serializable
private data class ObaStop(
    val id: String? = null,
    val code: String? = null,
    val name: String? = null,
    val lat: Double? = null,
    val lon: Double? = null
)

@Serializable
private data class ObaArrival(
    val routeShortName: String? = null,
    val tripHeadsign: String? = null,
    val predicted: Boolean? = null,
    val predictedArrivalTime: Long? = null,
    val scheduledArrivalTime: Long? = null,
    val distanceFromStop: Double? = null,
    val stopId: String? = null,
    val tripId: String? = null,
    val tripStatus: ObaTripStatus? = null
)

@Serializable
private data class ObaTripData(val entry: ObaTripEntry? = null)

@Serializable
private data class ObaTripEntry(val shapeId: String? = null)

@Serializable
private data class ObaShapeData(val entry: ObaShapeEntry? = null)

@Serializable
private data class ObaShapeEntry(val points: String? = null)

// Estado del viaje del coche. position siempre viene, pero es GPS real
// solo cuando predicted == true (si no, es una interpolación por horario).
@Serializable
private data class ObaTripStatus(
    val predicted: Boolean? = null,
    val position: ObaCoord? = null,
    val lastKnownLocation: ObaCoord? = null,
    val vehicleId: String? = null
)

@Serializable
private data class ObaCoord(
    val lat: Double? = null,
    val lon: Double? = null
)
