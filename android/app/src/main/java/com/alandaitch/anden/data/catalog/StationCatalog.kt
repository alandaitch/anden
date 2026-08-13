package com.alandaitch.anden.data.catalog

import android.content.Context
import com.alandaitch.anden.AndenApp
import com.alandaitch.anden.data.model.Ramal
import com.alandaitch.anden.data.model.Station
import com.alandaitch.anden.data.model.TrainLine
import com.alandaitch.anden.util.Geo
import com.alandaitch.anden.util.GeoPoint
import com.alandaitch.anden.util.Text
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json

// Catálogo embebido de estaciones y ramales. Carga estaciones.json + lineas.json de assets.
class StationCatalog(context: Context = AndenApp.appContext) {

    val all: List<Station>
    val lines: List<TrainLine> = TrainLine.all

    private val stationsById: Map<Int, Station>
    private val ramalsById: Map<Int, Ramal>

    @Serializable
    private data class LineFile(val id: Int, val nombre: String, val ramales: List<Ramal> = emptyList())

    init {
        val json = Json { ignoreUnknownKeys = true }
        val stations: List<Station> = try {
            val text = context.assets.open("estaciones.json").bufferedReader().use { it.readText() }
            json.decodeFromString(text)
        } catch (_: Exception) {
            emptyList()
        }
        all = stations
        stationsById = stations.associateBy { it.id }

        val ramals = mutableMapOf<Int, Ramal>()
        try {
            val text = context.assets.open("lineas.json").bufferedReader().use { it.readText() }
            val files: List<LineFile> = json.decodeFromString(text)
            for (f in files) for (r in f.ramales) ramals[r.id] = r
        } catch (_: Exception) {
        }
        ramalsById = ramals
    }

    fun station(id: Int): Station? = stationsById[id]

    fun ramal(id: Int): Ramal? = ramalsById[id]

    // Substring sin acentos. Prioriza enRamalPublico y tieneArribosHoy.
    fun search(query: String): List<Station> {
        val q = normalize(query)
        if (q.isEmpty()) return emptyList()
        return all
            .filter { it.visibleEnApp && normalize(it.nombre).contains(q) }
            .sortedWith(compareByDescending<Station> {
                (if (it.enRamalPublico) 2 else 0) + (if (it.tieneArribosHoy) 1 else 0)
            }.thenBy { it.nombre.lowercase() })
    }

    // Estaciones más cercanas con servicio real, ordenadas por distancia (metros).
    fun nearest(to: GeoPoint, limit: Int = 5): List<Pair<Station, Double>> {
        return all
            .filter { it.enRamalPublico }
            .map { it to Geo.distanceMeters(it.coordinate, to) }
            .sortedBy { it.second }
            .take(limit)
    }

    companion object {
        val shared: StationCatalog by lazy { StationCatalog() }

        fun normalize(s: String): String = Text.normalize(s)
    }
}
