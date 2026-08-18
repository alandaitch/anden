package com.alandaitch.anden.ui.board

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.AltRoute
import androidx.compose.material.icons.filled.DirectionsWalk
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.filled.StarBorder
import androidx.compose.material.icons.filled.Train
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.alandaitch.anden.data.catalog.StationCatalog
import com.alandaitch.anden.data.model.Arrival
import com.alandaitch.anden.data.net.ApiError
import com.alandaitch.anden.data.net.SofseApi
import androidx.compose.ui.graphics.toArgb
import com.alandaitch.anden.data.store.FavoriteItem
import com.alandaitch.anden.data.store.FavoriteMode
import com.alandaitch.anden.data.store.FavoritesStore
import com.alandaitch.anden.ui.cerca.collectAsStateSafe
import com.alandaitch.anden.ui.components.ArrivalRow
import com.alandaitch.anden.ui.components.EmptyState
import com.alandaitch.anden.ui.components.ErrorState
import com.alandaitch.anden.ui.components.LineBadge
import com.alandaitch.anden.ui.components.LiveDot
import com.alandaitch.anden.ui.components.LoadingState
import com.alandaitch.anden.ui.theme.Palette
import com.alandaitch.anden.ui.theme.andenCard
import com.alandaitch.anden.ui.theme.andenColors
import com.alandaitch.anden.util.Formatting
import com.alandaitch.anden.util.MapsOpener
import kotlinx.coroutines.delay
import java.time.Instant

private enum class BoardPhase { LOADING, LIVE, EMPTY, ERROR, UNAVAILABLE, SERVICE_DOWN }

// Tablero de arribos de una estación. Carga en vivo, auto-refresh cada 25s.
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun StationBoardScreen(stationId: Int, onBack: () -> Unit, modifier: Modifier = Modifier) {
    val colors = andenColors()
    val context = LocalContext.current
    val station = remember(stationId) { StationCatalog.shared.station(stationId) }

    val favs by FavoritesStore.shared.itemsFlow.collectAsStateSafe()
    val isFavorite = favs.any { it.mode == FavoriteMode.TREN && it.refId == stationId.toString() }

    var arrivals by remember(stationId) { mutableStateOf<List<Arrival>>(emptyList()) }
    var phase by remember(stationId) { mutableStateOf(BoardPhase.LOADING) }
    var errorMsg by remember(stationId) { mutableStateOf<String?>(null) }
    var lastUpdated by remember(stationId) { mutableStateOf<Instant?>(null) }
    var reload by remember(stationId) { mutableIntStateOf(0) }

    LaunchedEffect(stationId, reload) {
        if (station == null) {
            phase = BoardPhase.ERROR
            errorMsg = "No encontramos esta estación."
            return@LaunchedEffect
        }
        if (!station.line.covered) {
            phase = BoardPhase.UNAVAILABLE
            return@LaunchedEffect
        }
        suspend fun run() {
            if (arrivals.isEmpty()) phase = BoardPhase.LOADING
            try {
                val res = SofseApi.shared.arrivals(stationId)
                arrivals = res
                lastUpdated = Instant.now()
                phase = if (res.isEmpty()) BoardPhase.EMPTY else BoardPhase.LIVE
            } catch (e: ApiError.ServiceUnavailable) {
                if (arrivals.isEmpty()) {
                    phase = BoardPhase.SERVICE_DOWN
                    errorMsg = e.message
                }
            } catch (e: Exception) {
                if (arrivals.isEmpty()) {
                    phase = BoardPhase.ERROR
                    errorMsg = e.message ?: "Revisá tu conexión e intentá de nuevo."
                }
            }
        }
        run()
        while (true) {
            delay(25_000)
            run()
        }
    }

    Scaffold(
        modifier = modifier.fillMaxSize(),
        containerColor = colors.background,
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        station?.nombre ?: "Estación",
                        color = colors.textPrimary,
                        fontWeight = FontWeight.SemiBold,
                        fontSize = 16.sp,
                        maxLines = 1,
                    )
                },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Volver", tint = colors.textPrimary)
                    }
                },
                actions = {
                    if (station != null) {
                        IconButton(onClick = { MapsOpener.walk(context, station.coordinate, station.nombre) }) {
                            Icon(Icons.Filled.DirectionsWalk, contentDescription = "Cómo llegar a la estación", tint = colors.textSecondary)
                        }
                        IconButton(onClick = { FavoritesStore.shared.toggle(FavoriteItem.train(station)) }) {
                            Icon(
                                if (isFavorite) Icons.Filled.Star else Icons.Filled.StarBorder,
                                contentDescription = if (isFavorite) "Quitar de favoritos" else "Agregar a favoritos",
                                tint = if (isFavorite) Palette.minorDelay else colors.textSecondary,
                            )
                        }
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = colors.background),
            )
        },
    ) { inner ->
        LazyColumn(
            modifier = Modifier.fillMaxSize().padding(inner),
            contentPadding = PaddingValues(start = 16.dp, end = 16.dp, top = 8.dp, bottom = 32.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            if (station != null) {
                item(key = "header") {
                    Header(station = station, phase = phase, lastUpdated = lastUpdated)
                }
                if (arrivals.isNotEmpty()) {
                    item(key = "minimap") {
                        com.alandaitch.anden.ui.map.MiniMapView(
                            stop = station.coordinate,
                            vehicle = arrivals.firstOrNull { it.trainLocation != null }?.trainLocation,
                            vehicleColorArgb = station.line.color.toArgb(),
                        )
                    }
                }
            }
            when (phase) {
                BoardPhase.LOADING -> if (arrivals.isEmpty()) item(key = "loading") {
                    LoadingState(
                        message = "Buscando trenes en ${station?.nombre ?: "la estación"}…",
                        modifier = Modifier.padding(top = 32.dp),
                    )
                } else itemsArrivals(arrivals)

                BoardPhase.UNAVAILABLE -> item(key = "unavailable") {
                    EmptyState(
                        icon = Icons.Filled.Warning,
                        title = "Línea no disponible",
                        message = "Esta línea no está en la fuente de datos en vivo. La operan otras empresas que no publican arribos.",
                        modifier = Modifier.padding(top = 32.dp),
                    )
                }

                BoardPhase.SERVICE_DOWN -> item(key = "service") {
                    EmptyState(
                        icon = Icons.Filled.Warning,
                        title = "Servicio no disponible",
                        message = errorMsg ?: "La fuente de datos no responde ahora. Probá de nuevo en un rato.",
                        actionTitle = "Reintentar",
                        onAction = { reload++ },
                        modifier = Modifier.padding(top = 32.dp),
                    )
                }

                BoardPhase.EMPTY -> item(key = "empty") {
                    EmptyState(
                        icon = Icons.Filled.Train,
                        title = "Sin trenes ahora",
                        message = "No hay arribos en vivo para esta estación en este momento.",
                        actionTitle = "Reintentar",
                        onAction = { reload++ },
                        modifier = Modifier.padding(top = 32.dp),
                    )
                }

                BoardPhase.ERROR -> item(key = "error") {
                    ErrorState(
                        message = errorMsg ?: "Revisá tu conexión e intentá de nuevo.",
                        onRetry = { reload++ },
                        modifier = Modifier.padding(top = 32.dp),
                    )
                }

                BoardPhase.LIVE -> itemsArrivals(arrivals)
            }
        }
    }
}

private fun androidx.compose.foundation.lazy.LazyListScope.itemsArrivals(arrivals: List<Arrival>) {
    items(arrivals, key = { it.id }) { arrival ->
        ArrivalRow(arrival = arrival)
    }
}

@Composable
private fun Header(
    station: com.alandaitch.anden.data.model.Station,
    phase: BoardPhase,
    lastUpdated: Instant?,
) {
    val colors = andenColors()
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .andenCard(corner = 20.dp)
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Row(verticalAlignment = Alignment.Top) {
            LineBadge(line = station.line, size = 52.dp)
            Spacer(Modifier.width(12.dp))
            Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(
                    station.nombre,
                    color = colors.textPrimary,
                    fontWeight = FontWeight.Black,
                    fontSize = 26.sp,
                    maxLines = 2,
                )
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(station.line.nombre, color = station.line.color, fontWeight = FontWeight.SemiBold, fontSize = 14.sp)
                    val andenes = station.andenes
                    if (andenes != null && andenes > 0) {
                        Text("·", color = colors.textSecondary, fontSize = 13.sp)
                        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(3.dp)) {
                            Icon(Icons.AutoMirrored.Filled.AltRoute, contentDescription = null, tint = colors.textSecondary, modifier = Modifier.size(12.dp))
                            Text("$andenes andenes", color = colors.textSecondary, fontWeight = FontWeight.Medium, fontSize = 13.sp)
                        }
                    }
                }
            }
        }
        StatusBar(phase = phase, lastUpdated = lastUpdated)
    }
}

@Composable
private fun StatusBar(phase: BoardPhase, lastUpdated: Instant?) {
    val colors = andenColors()
    when (phase) {
        BoardPhase.LIVE -> Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            LiveDot(active = true, color = Palette.onTime, size = 7.dp)
            Text("En vivo", color = Palette.onTime, fontWeight = FontWeight.SemiBold, fontSize = 13.sp)
            if (lastUpdated != null) {
                Text("· actualizado ${Formatting.clock(lastUpdated)}", color = colors.textSecondary, fontWeight = FontWeight.Medium, fontSize = 12.sp)
            }
        }
        BoardPhase.LOADING -> Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            CircularProgressIndicator(color = colors.textSecondary, strokeWidth = 2.dp, modifier = Modifier.size(14.dp))
            Text("Buscando trenes…", color = colors.textSecondary, fontWeight = FontWeight.Medium, fontSize = 12.sp)
        }
        else -> Spacer(Modifier.size(0.dp))
    }
}
