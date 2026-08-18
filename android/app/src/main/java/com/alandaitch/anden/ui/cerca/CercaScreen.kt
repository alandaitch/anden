package com.alandaitch.anden.ui.cerca

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.windowInsetsTopHeight
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AltRoute
import androidx.compose.material.icons.filled.DirectionsBike
import androidx.compose.material.icons.filled.DirectionsBus
import androidx.compose.material.icons.filled.DirectionsSubway
import androidx.compose.material.icons.filled.GridView
import androidx.compose.material.icons.filled.LocationOff
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material.icons.filled.MyLocation
import androidx.compose.material.icons.filled.Train
import androidx.compose.material.icons.filled.WrongLocation
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.alandaitch.anden.data.location.LocationProvider
import com.alandaitch.anden.data.model.EcobiciStation
import com.alandaitch.anden.data.model.SubteLine
import com.alandaitch.anden.data.model.TrainLine
import com.alandaitch.anden.ui.components.EmptyState
import com.alandaitch.anden.ui.components.LineBadge
import com.alandaitch.anden.ui.components.LoadingState
import com.alandaitch.anden.ui.components.ModeIconBadge
import com.alandaitch.anden.ui.components.NearbyRow
import com.alandaitch.anden.ui.components.SubteBadge
import com.alandaitch.anden.ui.theme.Palette
import com.alandaitch.anden.ui.theme.andenColors
import com.alandaitch.anden.util.MapsOpener
import kotlin.math.roundToInt

// Pantalla principal MULTIMODAL. Chips de filtro + lista mezclada por cercanía
// combinando tren, subte, EcoBici y colectivo. Cada fila navega y trae "Ir".
@Composable
fun CercaScreen(
    onOpenTren: (Int) -> Unit,
    onOpenSubte: (stationName: String, routeId: String?) -> Unit,
    onOpenBici: (EcobiciStation) -> Unit,
    onOpenBondi: (stopId: String, stopName: String, lat: Double, lng: Double) -> Unit,
    onComoLlego: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val colors = andenColors()
    val context = LocalContext.current
    val provider = LocationProvider.shared
    val hasPermission by provider.hasPermission.collectAsStateSafe()
    val location by provider.location.collectAsStateSafe()

    val loader = remember { CercaLoader() }
    var filter by rememberSaveable { mutableStateOf(CercaFilter.TODOS) }

    // Arranca updates si hay permiso.
    LaunchedEffect(hasPermission) {
        provider.refreshPermission()
        if (hasPermission) provider.start()
    }

    // Clave estable: relanza la carga sólo cuando la ubicación cambia de verdad.
    // Se lee 'location' (State) para que la pantalla recomponga ante cada update.
    val point = location?.let { com.alandaitch.anden.util.GeoPoint(it.latitude, it.longitude) }
    val coordKey = point?.let { "${(it.lat * 1000).roundToInt()}-${(it.lng * 1000).roundToInt()}" } ?: "none"
    LaunchedEffect(coordKey) {
        if (point != null) loader.load(point)
    }

    Column(modifier = modifier.fillMaxSize().background(colors.background)) {
        Spacer(Modifier.windowInsetsTopHeight(WindowInsets.statusBars))
        header(onComoLlego = onComoLlego)
        filterChips(filter = filter, onSelect = { filter = it })

        val items = loader.items
        when {
            !hasPermission -> EmptyState(
                icon = Icons.Filled.LocationOff,
                title = "Activá tu ubicación",
                message = "Te mostramos trenes, subtes, EcoBici y colectivos cerca tuyo, ordenados por distancia. Nunca compartimos tu ubicación.",
                actionTitle = "Activar ubicación",
                onAction = {
                    provider.refreshPermission()
                    provider.start()
                },
                modifier = Modifier.padding(top = 40.dp),
            )
            point == null -> LoadingState(message = "Buscando tu ubicación…", modifier = Modifier.padding(top = 40.dp))
            loader.isLoading && items.isEmpty() -> LoadingState(message = "Buscando transporte cerca tuyo…", modifier = Modifier.padding(top = 40.dp))
            else -> {
                val filtered = filter.apply(items)
                if (filtered.isEmpty()) {
                    EmptyState(
                        icon = Icons.Filled.WrongLocation,
                        title = "Nada cerca",
                        message = filter.emptyMessage,
                        modifier = Modifier.padding(top = 40.dp),
                    )
                } else {
                    NearbyList(
                        items = filtered,
                        onGo = { item -> MapsOpener.walk(context, item.point, item.title) },
                        onOpen = { item ->
                            when (val nav = item.nav) {
                                is NearbyNav.Tren -> onOpenTren(nav.stationId)
                                is NearbyNav.Subte -> onOpenSubte(nav.stationName, nav.routeId)
                                is NearbyNav.Bici -> onOpenBici(nav.station)
                                is NearbyNav.Bondi -> onOpenBondi(nav.stopId, nav.stopName, nav.lat, nav.lng)
                            }
                        },
                    )
                }
            }
        }
    }
}

@Composable
private fun header(onComoLlego: () -> Unit) {
    val colors = andenColors()
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(start = 16.dp, end = 12.dp, top = 8.dp, bottom = 4.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text("Cerca", color = colors.textPrimary, fontWeight = FontWeight.Black, fontSize = 30.sp, modifier = Modifier.weight(1f))
        Box(
            modifier = Modifier
                .size(40.dp)
                .clip(CircleShape)
                .background(colors.brand.copy(alpha = 0.14f))
                .clickableRole(onComoLlego, "Cómo llego"),
            contentAlignment = Alignment.Center,
        ) {
            Icon(Icons.Filled.AltRoute, contentDescription = "Cómo llego", tint = colors.brand, modifier = Modifier.size(20.dp))
        }
    }
}

@Composable
private fun filterChips(filter: CercaFilter, onSelect: (CercaFilter) -> Unit) {
    // Los 5 filtros entran distribuidos, sin scroll horizontal (antes Bondi quedaba tapado).
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 8.dp),
        horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        for (f in CercaFilter.entries) {
            FilterChip(f = f, selected = f == filter, onClick = { onSelect(f) }, modifier = Modifier.weight(1f))
        }
    }
}

@Composable
private fun FilterChip(f: CercaFilter, selected: Boolean, onClick: () -> Unit, modifier: Modifier = Modifier) {
    val colors = andenColors()
    Row(
        modifier = modifier
            .clip(CircleShape)
            .background(if (selected) colors.brand else colors.surface)
            .border(0.5.dp, if (selected) Color.Transparent else colors.textSecondary.copy(alpha = 0.18f), CircleShape)
            .clickableRole(onClick, f.title)
            .padding(horizontal = 4.dp, vertical = 8.dp),
        horizontalArrangement = Arrangement.spacedBy(3.dp, Alignment.CenterHorizontally),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(f.icon, contentDescription = null, tint = if (selected) Color.White else colors.textSecondary, modifier = Modifier.size(13.dp))
        Text(f.title, color = if (selected) Color.White else colors.textSecondary, fontWeight = FontWeight.Bold, fontSize = 11.sp, maxLines = 1)
    }
}

@Composable
private fun NearbyList(
    items: List<NearbyItem>,
    onGo: (NearbyItem) -> Unit,
    onOpen: (NearbyItem) -> Unit,
) {
    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(start = 16.dp, end = 16.dp, top = 4.dp, bottom = 24.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        items(items, key = { it.id }) { item ->
            NearbyRow(
                title = item.title,
                modeLabel = item.mode.label,
                modeColor = item.accent,
                distanceMeters = item.distanceMeters,
                accent = item.accent,
                subtitle = item.subtitle,
                subtitleColor = item.subtitleColor,
                onGo = { onGo(item) },
                onClick = { onOpen(item) },
                leading = { NearbyLeading(item.badge) },
            )
        }
    }
}

@Composable
private fun NearbyLeading(badge: BadgeKind) {
    when (badge) {
        is BadgeKind.Train -> LineBadge(line = badge.line, size = 40.dp)
        is BadgeKind.Subte -> SubteBadge(line = badge.line, size = 40.dp)
        BadgeKind.Bike -> ModeIconBadge(icon = Icons.Filled.DirectionsBike, fill = com.alandaitch.anden.ui.theme.BiciAccent)
        BadgeKind.Bus -> ModeIconBadge(icon = Icons.Filled.DirectionsBus, fill = Palette.brand)
        is BadgeKind.BusLine -> BusLineBadge(lineShort = badge.lineShort)
    }
}

// Badge cuadrado con el número de línea de colectivo (color determinístico).
@Composable
private fun BusLineBadge(lineShort: String) {
    Box(
        modifier = Modifier
            .size(40.dp)
            .clip(androidx.compose.foundation.shape.RoundedCornerShape(10.dp))
            .background(com.alandaitch.anden.data.model.BusLine.color(lineShort)),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            lineShort,
            color = Color.White,
            fontWeight = FontWeight.Black,
            fontSize = 15.sp,
            maxLines = 1,
            modifier = Modifier.padding(horizontal = 2.dp),
        )
    }
}

// ---- Modelo de fila y filtros ----

enum class NearbyMode(val label: String) { TREN("Tren"), SUBTE("Subte"), BICI("EcoBici"), BONDI("Colectivo") }

sealed interface BadgeKind {
    data class Train(val line: TrainLine) : BadgeKind
    data class Subte(val line: SubteLine) : BadgeKind
    data object Bike : BadgeKind
    data object Bus : BadgeKind
    data class BusLine(val lineShort: String) : BadgeKind
}

sealed interface NearbyNav {
    data class Tren(val stationId: Int) : NearbyNav
    data class Subte(val stationName: String, val routeId: String?) : NearbyNav
    data class Bici(val station: EcobiciStation) : NearbyNav
    data class Bondi(val stopId: String, val stopName: String, val lat: Double, val lng: Double) : NearbyNav
}

data class NearbyItem(
    val id: String,
    val mode: NearbyMode,
    val title: String,
    val distanceMeters: Double,
    val point: com.alandaitch.anden.util.GeoPoint,
    val accent: Color,
    val badge: BadgeKind,
    val subtitle: String?,
    val subtitleColor: Color,
    val nav: NearbyNav,
)

enum class CercaFilter(val title: String, val icon: ImageVector) {
    TODOS("Todos", Icons.Filled.GridView),
    TREN("Tren", Icons.Filled.Train),
    SUBTE("Subte", Icons.Filled.DirectionsSubway),
    BONDI("Bondi", Icons.Filled.DirectionsBus),
    BICI("Bici", Icons.Filled.DirectionsBike);

    val emptyMessage: String
        get() = when (this) {
            TODOS -> "No encontramos transporte cerca tuyo ahora."
            TREN -> "No hay estaciones de tren con servicio cerca tuyo."
            SUBTE -> "No hay estaciones de subte cerca tuyo."
            BICI -> "No hay estaciones de EcoBici cerca tuyo."
            BONDI -> "No hay paradas de colectivo cerca tuyo."
        }

    // Aplica el filtro. En TODOS capea colectivos a 6 para no inundar.
    fun apply(items: List<NearbyItem>): List<NearbyItem> = when (this) {
        TODOS -> {
            var bondiSeen = 0
            items.filter { item ->
                if (item.mode != NearbyMode.BONDI) return@filter true
                bondiSeen += 1
                bondiSeen <= 6
            }
        }
        TREN -> items.filter { it.mode == NearbyMode.TREN }
        SUBTE -> items.filter { it.mode == NearbyMode.SUBTE }
        BICI -> items.filter { it.mode == NearbyMode.BICI }
        BONDI -> items.filter { it.mode == NearbyMode.BONDI }
    }
}
