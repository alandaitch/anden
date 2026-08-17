package com.alandaitch.anden.data.catalog

import android.content.Context
import com.alandaitch.anden.AndenApp
import com.alandaitch.anden.data.model.BusLine
import com.alandaitch.anden.data.model.BusStop
import com.alandaitch.anden.util.Geo
import com.alandaitch.anden.util.GeoPoint
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import kotlin.math.cos

// Catálogo embebido de líneas y paradas de colectivos.
// Carga colectivos-lineas.json (1052) + colectivos-paradas.json (42805) de assets.
// OJO: solo ~32% de los route_id del feed en vivo matchean el catálogo (GTFS 2019).
class ColectivoCatalog(context: Context = AndenApp.appContext) {

    val lines: List<BusLine>
    val stops: List<BusStop>

    private val lineByRouteId: Map<String, BusLine>

    @Serializable
    private data class LineDTO(val routeId: String, val shortName: String, val longName: String)

    @Serializable
    private data class StopDTO(val code: String, val name: String, val lat: Double, val lng: Double)

    init {
        val json = Json { ignoreUnknownKeys = true }
        lines = try {
            val text = context.assets.open("colectivos-lineas.json").bufferedReader().use { it.readText() }
            json.decodeFromString<List<LineDTO>>(text)
                .map { BusLine(it.routeId, it.shortName, it.longName) }
        } catch (_: Exception) {
            emptyList()
        }
        lineByRouteId = lines.associateBy { it.routeId }

        stops = try {
            val text = context.assets.open("colectivos-paradas.json").bufferedReader().use { it.readText() }
            json.decodeFromString<List<StopDTO>>(text)
                .map { BusStop(it.code, it.name, it.lat, it.lng) }
        } catch (_: Exception) {
            emptyList()
        }
    }

    // Línea por route_id. null si no matchea (esperado en ~68% de los casos).
    fun line(routeId: String): BusLine? = lineByRouteId[routeId]

    // Número de línea para mostrar. shortName si matchea, si no el propio route_id.
    fun displayLine(routeId: String): String = lineByRouteId[routeId]?.shortName ?: routeId

    // Nombre "lindo" de la parada más cercana a una coord, dentro de maxMeters.
    // Sirve para arreglar los nombres crudos de OneBusAway ("1606 MITRE BARTOLOME"
    // -> "Bartolomé Mitre 1606"). Un solo barrido lineal, sin ordenar. null si no matchea.
    fun nearestStopName(to: GeoPoint, maxMeters: Double = 40.0): String? {
        if (stops.isEmpty()) return null
        val cosLat = cos(to.lat * Math.PI / 180)
        var best: BusStop? = null
        var bestD = Double.MAX_VALUE
        for (s in stops) {
            val dLat = s.lat - to.lat
            val dLng = (s.lng - to.lng) * cosLat
            val d = dLat * dLat + dLng * dLng
            if (d < bestD) {
                bestD = d
                best = s
            }
        }
        val b = best ?: return null
        return if (Geo.distanceMeters(b.coordinate, to) <= maxMeters) b.name else null
    }

    // Paradas más cercanas, ordenadas por distancia (metros).
    // Prefiltra por distancia equirectangular barata para no medir 42805 exactas.
    fun nearbyStops(to: GeoPoint, limit: Int = 12): List<Pair<BusStop, Double>> {
        val cosLat = cos(to.lat * Math.PI / 180)
        fun approx(s: BusStop): Double {
            val dLat = s.lat - to.lat
            val dLng = (s.lng - to.lng) * cosLat
            return dLat * dLat + dLng * dLng
        }
        return stops
            .sortedBy { approx(it) }
            .take(maxOf(0, limit))
            .map { it to Geo.distanceMeters(it.coordinate, to) }
    }

    companion object {
        val shared: ColectivoCatalog by lazy { ColectivoCatalog() }
    }
}
