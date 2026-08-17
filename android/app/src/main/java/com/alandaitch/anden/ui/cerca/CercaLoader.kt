package com.alandaitch.anden.ui.cerca

import androidx.compose.foundation.clickable
import androidx.compose.runtime.Composable
import androidx.compose.runtime.State
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import com.alandaitch.anden.data.catalog.StationCatalog
import com.alandaitch.anden.data.catalog.SubteCatalog
import com.alandaitch.anden.data.net.BaApi
import com.alandaitch.anden.data.net.SofseApi
import com.alandaitch.anden.ui.theme.BiciAccent
import com.alandaitch.anden.ui.theme.Palette
import com.alandaitch.anden.util.Formatting
import com.alandaitch.anden.util.Geo
import com.alandaitch.anden.util.GeoPoint
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.flow.StateFlow
import java.time.Instant

// Wrapper para observar un StateFlow como State en Compose sin ruido de imports.
@Composable
fun <T> StateFlow<T>.collectAsStateSafe(): State<T> = collectAsState()

// Modifier clickeable con rol de accesibilidad (descripción).
fun Modifier.clickableRole(onClick: () -> Unit, label: String): Modifier =
    this.clickable(onClick = onClick).semantics { contentDescription = label }

// Carga y ordena la lista mezclada de "Cerca". Primero base offline, luego enriquece.
class CercaLoader {
    var isLoading by mutableStateOf(false)
        private set
    var items by mutableStateOf<List<NearbyItem>>(emptyList())
        private set

    suspend fun load(point: GeoPoint) {
        isLoading = items.isEmpty()
        try {
            val base = buildBase(point)
            items = base
            val enriched = enrich(base)
            items = enriched
            // Colectivos: líneas cercanas con "cuándo llega" (OneBusAway). Degrada a vacío.
            val busItems = loadBusLines(point)
            items = (enriched + busItems).sortedBy { it.distanceMeters }
        } finally {
            isLoading = false
        }
    }

    // Filas base desde catálogos (sync) + EcoBici (red, degrada a vacío). Sin colectivos.
    private suspend fun buildBase(point: GeoPoint): List<NearbyItem> {
        val trainPairs = StationCatalog.shared.nearest(point, limit = 5)
        val subtePairs = SubteCatalog.shared.nearest(point, limit = 5)

        val biciItems: List<NearbyItem> = try {
            BaApi.shared.ecobiciStations()
                .map { it to Geo.distanceMeters(point, it.coordinate) }
                .sortedBy { it.second }
                .take(5)
                .map { (st, dist) -> biciItem(st, dist) }
        } catch (_: Exception) {
            emptyList()
        }

        val result = ArrayList<NearbyItem>()
        trainPairs.forEach { (st, dist) ->
            result.add(
                NearbyItem(
                    id = "tren-${st.id}",
                    mode = NearbyMode.TREN,
                    title = st.nombre,
                    distanceMeters = dist,
                    point = st.coordinate,
                    accent = st.line.color,
                    badge = BadgeKind.Train(st.line),
                    subtitle = null,
                    subtitleColor = Palette.textSecondaryDark,
                    nav = NearbyNav.Tren(st.id),
                )
            )
        }
        subtePairs.forEach { (st, dist) ->
            result.add(
                NearbyItem(
                    id = "subte-${st.id}",
                    mode = NearbyMode.SUBTE,
                    title = st.name,
                    distanceMeters = dist,
                    point = st.coordinate,
                    accent = st.line.color,
                    badge = BadgeKind.Subte(st.line),
                    subtitle = null,
                    subtitleColor = Palette.textSecondaryDark,
                    nav = NearbyNav.Subte(st.name, st.line.routeId),
                )
            )
        }
        result.addAll(biciItems)
        result.sortBy { it.distanceMeters }
        return result
    }

    // Colectivos: líneas cercanas con "cuándo llega" (OneBusAway de cuandosubo).
    // Una fila por (línea + destino), con la parada del próximo arribo. Degrada a vacío.
    private suspend fun loadBusLines(point: GeoPoint): List<NearbyItem> {
        val lines = try {
            com.alandaitch.anden.data.net.ObaApi.shared.nearbyBusLines(point)
        } catch (_: Exception) {
            emptyList()
        }
        // Cache por parada: cruza la coord de OneBusAway al nombre lindo del catálogo.
        val nameCache = HashMap<String, String>()
        fun prettyStop(line: com.alandaitch.anden.data.model.BusLineNearby): String {
            nameCache[line.stopId]?.let { return it }
            val clean = com.alandaitch.anden.data.catalog.ColectivoCatalog.shared
                .nearestStopName(line.coordinate) ?: line.stopName
            nameCache[line.stopId] = clean
            return clean
        }
        return lines.map { line ->
            val dist = Geo.distanceMeters(point, line.coordinate)
            val eta = Formatting.etaText(line.secondsUntil)
            val estado = if (line.isLive) "en vivo" else "prog"
            val stopName = prettyStop(line)
            val title = Formatting.busDestination(line.lineShort, line.headsign)
            NearbyItem(
                id = "bondi-${line.stopId}-${line.lineShort}-${line.headsign}",
                mode = NearbyMode.BONDI,
                title = title,
                distanceMeters = dist,
                point = line.coordinate,
                accent = com.alandaitch.anden.data.model.BusLine.color(line.lineShort),
                badge = BadgeKind.BusLine(line.lineShort),
                subtitle = "$eta $estado · $stopName",
                subtitleColor = if (line.isLive) Palette.onTime else Palette.minorDelay,
                nav = NearbyNav.Bondi(line.stopId, stopName, line.coordinate.lat, line.coordinate.lng),
            )
        }
    }

    private fun biciItem(st: com.alandaitch.anden.data.model.EcobiciStation, dist: Double): NearbyItem {
        val inService = st.status == "IN_SERVICE"
        val subtitle: String
        val color: androidx.compose.ui.graphics.Color
        if (!inService) {
            subtitle = "Fuera de servicio"
            color = Palette.noData
        } else {
            val bikes = "${st.bikesTotal} ${if (st.bikesTotal == 1) "bici" else "bicis"}"
            val docks = "${st.docksAvailable} ${if (st.docksAvailable == 1) "anclaje" else "anclajes"}"
            subtitle = "$bikes · $docks"
            color = when {
                st.bikesTotal == 0 -> Palette.majorDelay
                st.bikesTotal <= 2 -> Palette.minorDelay
                else -> Palette.onTime
            }
        }
        return NearbyItem(
            id = "bici-${st.id}",
            mode = NearbyMode.BICI,
            title = st.displayName,
            distanceMeters = dist,
            point = st.coordinate,
            accent = BiciAccent,
            badge = BadgeKind.Bike,
            subtitle = subtitle,
            subtitleColor = color,
            nav = NearbyNav.Bici(st),
        )
    }

    // Enriquece con el próximo arribo (tren y subte). Cada fuente degrada por separado.
    private suspend fun enrich(base: List<NearbyItem>): List<NearbyItem> = coroutineScope {
        val updates = HashMap<String, Pair<String, androidx.compose.ui.graphics.Color>>()

        // Tren: una llamada liviana por estación, en paralelo.
        val trainDeferred = base.filter { it.mode == NearbyMode.TREN }.map { item ->
            async {
                val nav = item.nav as NearbyNav.Tren
                val arrival = try {
                    SofseApi.shared.arrivals(nav.stationId, limit = 1).firstOrNull()
                } catch (_: Exception) {
                    null
                }
                if (arrival != null) {
                    item.id to ("${Formatting.etaText(arrival.secondsUntil)} · a ${arrival.destinationName}" to Palette.onTime)
                } else {
                    null
                }
            }
        }
        trainDeferred.awaitAll().filterNotNull().forEach { updates[it.first] = it.second }

        // Subte: UNA sola llamada a subteTrips() y cruce por nombre normalizado.
        try {
            val trips = BaApi.shared.subteTrips()
            val now = Instant.now()
            base.filter { it.mode == NearbyMode.SUBTE }.forEach { item ->
                val nav = item.nav as NearbyNav.Subte
                val target = StationCatalog.normalize(nav.stationName)
                var bestSecs = Int.MAX_VALUE
                var bestDest = ""
                for (trip in trips) {
                    if (nav.routeId != null && !trip.line.routeId.equals(nav.routeId, ignoreCase = true)) continue
                    val stop = trip.stops.firstOrNull { StationCatalog.normalize(it.name) == target } ?: continue
                    val secs = (stop.eta.epochSecond - now.epochSecond).toInt()
                    if (secs in 0 until bestSecs) {
                        bestSecs = secs
                        bestDest = trip.stops.lastOrNull()?.name ?: ""
                    }
                }
                if (bestSecs != Int.MAX_VALUE) {
                    val dest = if (bestDest.isEmpty()) "" else " · a $bestDest"
                    updates[item.id] = ("${Formatting.etaText(bestSecs)}$dest" to Palette.onTime)
                }
            }
        } catch (_: Exception) {
            // Subte sin datos: se deja la fila sin mini-dato.
        }

        base.map { item ->
            val upd = updates[item.id]
            if (upd != null) item.copy(subtitle = upd.first, subtitleColor = upd.second) else item
        }
    }
}
