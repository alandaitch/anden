package com.alandaitch.anden.data.catalog

import android.content.Context
import com.alandaitch.anden.AndenApp
import com.alandaitch.anden.data.model.SubteLine
import com.alandaitch.anden.util.Geo
import com.alandaitch.anden.util.GeoPoint
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json

// Estación de subte del catálogo (subte-estaciones.json).
data class SubteStation(
    val name: String,
    val line: SubteLine,
    val lat: Double,
    val lng: Double,
    val aliases: List<String>
) {
    val id: String get() = "${line.routeId}-$name"
    val coordinate: GeoPoint get() = GeoPoint(lat, lng)
}

// Catálogo embebido de estaciones de subte (108).
// Sirve para geolocalizar estaciones y cruzar con el forecast (que trae stop_name).
class SubteCatalog(context: Context = AndenApp.appContext) {

    val all: List<SubteStation>

    // Índice por nombre normalizado (nombre + aliases) -> estación.
    private val byNormalizedName: Map<String, SubteStation>

    @Serializable
    private data class StationDTO(
        val name: String,
        val line: String,
        val lat: Double,
        val lng: Double,
        val aliases: List<String>? = null
    )

    init {
        val json = Json { ignoreUnknownKeys = true }
        val dtos: List<StationDTO> = try {
            val text = context.assets.open("subte-estaciones.json").bufferedReader().use { it.readText() }
            json.decodeFromString(text)
        } catch (_: Exception) {
            emptyList()
        }
        all = dtos.map {
            SubteStation(
                name = it.name,
                line = SubteLine.line(it.line),
                lat = it.lat,
                lng = it.lng,
                aliases = it.aliases ?: emptyList()
            )
        }
        val index = mutableMapOf<String, SubteStation>()
        for (st in all) {
            val keys = listOf(st.name) + st.aliases
            for (k in keys) {
                val norm = StationCatalog.normalize(k)
                if (index[norm] == null) index[norm] = st
            }
        }
        byNormalizedName = index
    }

    // Estaciones más cercanas, ordenadas por distancia (metros).
    fun nearest(to: GeoPoint, limit: Int = 5): List<Pair<SubteStation, Double>> {
        return all
            .map { it to Geo.distanceMeters(it.coordinate, to) }
            .sortedBy { it.second }
            .take(maxOf(0, limit))
    }

    // Estación por nombre, matcheando nombre normalizado + aliases. null si no matchea.
    fun station(name: String): SubteStation? = byNormalizedName[StationCatalog.normalize(name)]

    companion object {
        val shared: SubteCatalog by lazy { SubteCatalog() }
    }
}
