package com.alandaitch.anden.ui.colectivo

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.DirectionsBus
import androidx.compose.material.icons.rounded.Star
import androidx.compose.material.icons.rounded.StarBorder
import androidx.compose.material.icons.rounded.DirectionsTransit
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.ui.graphics.toArgb
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.alandaitch.anden.data.model.BusArrivalOba
import com.alandaitch.anden.data.model.BusLine
import com.alandaitch.anden.data.net.ApiError
import com.alandaitch.anden.data.net.ObaApi
import com.alandaitch.anden.ui.components.CountdownText
import com.alandaitch.anden.ui.components.EmptyState
import com.alandaitch.anden.ui.components.ErrorState
import com.alandaitch.anden.ui.components.GoButton
import com.alandaitch.anden.ui.components.LiveDot
import com.alandaitch.anden.ui.components.LoadingState
import com.alandaitch.anden.ui.theme.Palette
import com.alandaitch.anden.util.Formatting
import com.alandaitch.anden.util.GeoPoint
import com.alandaitch.anden.util.MapsOpener
import kotlinx.coroutines.delay
import java.time.Instant

private sealed interface ColectivoPhase {
    data object Loading : ColectivoPhase
    data object Ready : ColectivoPhase
    data object Empty : ColectivoPhase
    data class Error(val message: String) : ColectivoPhase
}

// Tablero de arribos de una parada de colectivo (OneBusAway). Auto-refresh 30s.
@Composable
fun ColectivoStopBoardScreen(stopId: String, stopName: String, stopPoint: GeoPoint?) {
    val dark = isSystemInDarkTheme()
    val context = LocalContext.current

    var arrivals by remember(stopId) { mutableStateOf<List<BusArrivalOba>>(emptyList()) }
    var phase by remember(stopId) { mutableStateOf<ColectivoPhase>(ColectivoPhase.Loading) }
    var lastUpdated by remember(stopId) { mutableStateOf<Instant?>(null) }
    var reloadKey by remember(stopId) { mutableIntStateOf(0) }

    val favs by com.alandaitch.anden.data.store.FavoritesStore.shared.itemsFlow.collectAsState()
    val isFav = favs.any { it.mode == com.alandaitch.anden.data.store.FavoriteMode.BONDI && it.refId == stopId }

    val userLoc by com.alandaitch.anden.data.location.LocationProvider.shared.location.collectAsState()
    val userGeo = userLoc?.let { GeoPoint(it.latitude, it.longitude) }
    var busRoute by remember(stopId) { mutableStateOf<List<GeoPoint>>(emptyList()) }
    val incomingTripId = arrivals.firstOrNull { it.vehicle != null }?.tripId
    LaunchedEffect(incomingTripId) {
        busRoute = incomingTripId?.let { runCatching { ObaApi.shared.tripShape(it) }.getOrDefault(emptyList()) } ?: emptyList()
    }

    LaunchedEffect(stopId, reloadKey) {
        if (arrivals.isEmpty()) phase = ColectivoPhase.Loading
        while (true) {
            try {
                val list = ObaApi.shared.stopArrivals(stopId)
                arrivals = list
                phase = if (list.isEmpty()) ColectivoPhase.Empty else ColectivoPhase.Ready
                lastUpdated = Instant.now()
            } catch (e: ApiError) {
                if (arrivals.isEmpty()) phase = ColectivoPhase.Error(e.message ?: "Revisá tu conexión e intentá de nuevo.")
            } catch (e: Exception) {
                if (arrivals.isEmpty()) phase = ColectivoPhase.Error("Revisá tu conexión e intentá de nuevo.")
            }
            delay(30_000)
        }
    }

    Box(
        Modifier
            .fillMaxSize()
            .background(Palette.background(dark))
    ) {
        LazyColumn(
            Modifier.fillMaxSize(),
            contentPadding = PaddingValues(16.dp, 12.dp, 16.dp, 32.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            item {
                ColectivoHeader(
                    stopName = stopName,
                    phase = phase,
                    lastUpdated = lastUpdated,
                    dark = dark,
                    onGo = { stopPoint?.let { MapsOpener.walk(context, it, stopName) } },
                    onTransit = { stopPoint?.let { MapsOpener.transit(context, it, stopName) } },
                    isFavorite = isFav,
                    onToggleFav = stopPoint?.let {
                        {
                            com.alandaitch.anden.data.store.FavoritesStore.shared.toggle(
                                com.alandaitch.anden.data.store.FavoriteItem.bondi(stopId, stopName, it)
                            )
                        }
                    },
                )
            }

            if (stopPoint != null && arrivals.isNotEmpty()) {
                val incoming = arrivals.firstOrNull { it.vehicle != null }
                val busColorArgb = incoming?.let {
                    com.alandaitch.anden.data.model.BusLine.color(it.lineShort).toArgb()
                } ?: 0xFF22C55E.toInt()
                item(key = "minimap") {
                    com.alandaitch.anden.ui.map.MiniMapView(
                        stop = stopPoint,
                        vehicle = incoming?.vehicle,
                        vehicleColorArgb = busColorArgb,
                        userLocation = userGeo,
                        route = busRoute,
                    )
                }
            }

            when (val p = phase) {
                is ColectivoPhase.Loading ->
                    if (arrivals.isEmpty()) item { LoadingState(message = "Buscando colectivos en esta parada…") }

                is ColectivoPhase.Empty ->
                    item {
                        EmptyState(
                            icon = Icons.Rounded.DirectionsBus,
                            title = "Sin colectivos ahora",
                            message = "No hay arribos informados para esta parada en este momento.",
                            actionTitle = "Reintentar",
                            onAction = { reloadKey++ }
                        )
                    }

                is ColectivoPhase.Error ->
                    item { ErrorState(message = p.message, onRetry = { reloadKey++ }) }

                is ColectivoPhase.Ready -> {
                    item {
                        Text(
                            "PRÓXIMOS COLECTIVOS",
                            color = Palette.textSecondary(dark),
                            fontSize = 13.sp,
                            fontWeight = FontWeight.Bold,
                            modifier = Modifier.padding(start = 4.dp)
                        )
                    }
                    items(arrivals.size, key = { arrivals[it].id }) { i ->
                        ColectivoArrivalRow(arrivals[i], dark)
                    }
                }
            }
        }
    }
}

@Composable
private fun ColectivoHeader(
    stopName: String,
    phase: ColectivoPhase,
    lastUpdated: Instant?,
    dark: Boolean,
    onGo: () -> Unit,
    onTransit: () -> Unit,
    isFavorite: Boolean = false,
    onToggleFav: (() -> Unit)? = null,
) {
    Column(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(20.dp))
            .background(Palette.surface(dark))
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Row(
            Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Box(
                Modifier
                    .size(46.dp)
                    .clip(RoundedCornerShape(12.dp))
                    .background(Palette.brand),
                contentAlignment = Alignment.Center
            ) {
                Icon(Icons.Rounded.DirectionsBus, contentDescription = null, tint = Color.White, modifier = Modifier.size(24.dp))
            }
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(
                    stopName,
                    color = Palette.textPrimary(dark),
                    fontSize = 22.sp,
                    fontWeight = FontWeight.Black,
                    maxLines = 3,
                    overflow = TextOverflow.Ellipsis
                )
                Text("Parada de colectivo", color = Palette.textSecondary(dark), fontSize = 13.sp, fontWeight = FontWeight.SemiBold)
            }
            if (onToggleFav != null) {
                IconButton(onClick = onToggleFav) {
                    Icon(
                        if (isFavorite) Icons.Rounded.Star else Icons.Rounded.StarBorder,
                        contentDescription = if (isFavorite) "Quitar de favoritos" else "Agregar a favoritos",
                        tint = if (isFavorite) Palette.minorDelay else Palette.textSecondary(dark),
                    )
                }
            }
        }

        when (phase) {
            is ColectivoPhase.Ready ->
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Box(Modifier.size(7.dp).clip(CircleShape).background(Palette.onTime))
                    Text("En vivo", color = Palette.onTime, fontSize = 13.sp, fontWeight = FontWeight.SemiBold)
                    if (lastUpdated != null) {
                        Text(
                            "· actualizado ${Formatting.clock(lastUpdated)}",
                            color = Palette.textSecondary(dark),
                            fontSize = 12.sp,
                            fontWeight = FontWeight.Medium
                        )
                    }
                }
            is ColectivoPhase.Loading ->
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    CircularProgressIndicator(Modifier.size(14.dp), strokeWidth = 2.dp, color = Palette.textSecondary(dark))
                    Text("Buscando colectivos…", color = Palette.textSecondary(dark), fontSize = 12.sp, fontWeight = FontWeight.Medium)
                }
            else -> {}
        }

        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            Box(Modifier.weight(1f)) { GoButton(onClick = onGo) }
            Row(
                Modifier
                    .weight(1f)
                    .clip(CircleShape)
                    .background(Palette.brand.copy(alpha = 0.14f))
                    .clickable(onClick = onTransit)
                    .padding(vertical = 10.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.Center
            ) {
                Icon(Icons.Rounded.DirectionsTransit, contentDescription = null, tint = Palette.brand, modifier = Modifier.size(16.dp))
                Text("  Cómo llego", color = Palette.brand, fontSize = 14.sp, fontWeight = FontWeight.Bold)
            }
        }
    }
}

// Fila de un arribo de colectivo: badge de línea + destino + countdown + VIVO/prog.
@Composable
private fun ColectivoArrivalRow(arrival: BusArrivalOba, dark: Boolean) {
    val color = BusLine.color(arrival.lineShort)
    Row(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(Palette.surface(dark))
            .padding(vertical = 12.dp, horizontal = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        ColectivoBusBadge(arrival.lineShort, color)
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(
                Formatting.busDestination(arrival.lineShort, arrival.headsign),
                color = Palette.textPrimary(dark),
                fontSize = 16.sp,
                fontWeight = FontWeight.SemiBold,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                if (arrival.isLive) {
                    LiveDot(active = true, color = Palette.onTime, size = 6.dp)
                    Text("En vivo", color = Palette.onTime, fontSize = 12.sp, fontWeight = FontWeight.SemiBold)
                } else {
                    Text("Programado", color = Palette.textSecondary(dark), fontSize = 12.sp, fontWeight = FontWeight.Medium)
                }
                arrival.eta?.let {
                    Text("· ${Formatting.clock(it)}", color = Palette.textSecondary(dark), fontSize = 12.sp, fontWeight = FontWeight.Medium)
                }
            }
        }
        CountdownText(secondsUntil = arrival.secondsUntil, big = false)
    }
}

// Badge cuadrado de línea de colectivo (color determinístico de BusLine).
@Composable
private fun ColectivoBusBadge(lineName: String, color: Color) {
    Box(
        Modifier
            .size(38.dp)
            .clip(RoundedCornerShape(10.dp))
            .background(color),
        contentAlignment = Alignment.Center
    ) {
        Text(
            lineName,
            color = Color.White,
            fontSize = 15.sp,
            fontWeight = FontWeight.Black,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.padding(horizontal = 2.dp)
        )
    }
}
