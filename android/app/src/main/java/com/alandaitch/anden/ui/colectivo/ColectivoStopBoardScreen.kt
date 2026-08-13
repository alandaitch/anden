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
import androidx.compose.material.icons.rounded.DirectionsTransit
import androidx.compose.material.icons.rounded.SignalWifiOff
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
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
import com.alandaitch.anden.data.catalog.ColectivoCatalog
import com.alandaitch.anden.data.model.BusArrival
import com.alandaitch.anden.data.model.BusLine
import com.alandaitch.anden.data.model.BusStop
import com.alandaitch.anden.data.net.ApiError
import com.alandaitch.anden.data.net.BaApi
import com.alandaitch.anden.ui.components.CountdownText
import com.alandaitch.anden.ui.components.DelayPill
import com.alandaitch.anden.ui.components.EmptyState
import com.alandaitch.anden.ui.components.ErrorState
import com.alandaitch.anden.ui.components.GoButton
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
    data class Unavailable(val message: String) : ColectivoPhase
    data class Error(val message: String) : ColectivoPhase
}

// Tablero de arribos de una parada de colectivo. Auto-refresh 30s.
@Composable
fun ColectivoStopBoardScreen(stopCode: String) {
    val dark = isSystemInDarkTheme()
    val context = LocalContext.current

    val stop: BusStop? = remember(stopCode) {
        ColectivoCatalog.shared.stops.firstOrNull { it.code == stopCode }
    }
    val stopName = stop?.name ?: "Parada $stopCode"
    val stopPoint: GeoPoint? = stop?.coordinate

    var arrivals by remember(stopCode) { mutableStateOf<List<BusArrival>>(emptyList()) }
    var phase by remember(stopCode) { mutableStateOf<ColectivoPhase>(ColectivoPhase.Loading) }
    var lastUpdated by remember(stopCode) { mutableStateOf<Instant?>(null) }
    var reloadKey by remember(stopCode) { mutableIntStateOf(0) }

    LaunchedEffect(stopCode, reloadKey) {
        if (arrivals.isEmpty()) phase = ColectivoPhase.Loading
        while (true) {
            try {
                val list = BaApi.shared.colectivoArrivals(stopCode)
                arrivals = list
                phase = if (list.isEmpty()) ColectivoPhase.Empty else ColectivoPhase.Ready
                lastUpdated = Instant.now()
            } catch (e: ApiError.ServiceUnavailable) {
                arrivals = emptyList()
                phase = ColectivoPhase.Unavailable(
                    e.info ?: "El servicio de arribos de colectivos de la Ciudad no responde ahora."
                )
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
                    stopCode = stopCode,
                    phase = phase,
                    lastUpdated = lastUpdated,
                    dark = dark,
                    onGo = { stopPoint?.let { MapsOpener.walk(context, it, stopName) } },
                    onTransit = { stopPoint?.let { MapsOpener.transit(context, it, stopName) } }
                )
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

                is ColectivoPhase.Unavailable ->
                    item {
                        Column(
                            Modifier.fillMaxWidth(),
                            horizontalAlignment = Alignment.CenterHorizontally
                        ) {
                            EmptyState(
                                icon = Icons.Rounded.SignalWifiOff,
                                title = "Arribos no disponibles",
                                message = p.message,
                                actionTitle = "Reintentar",
                                onAction = { reloadKey++ }
                            )
                            if (stopPoint != null) {
                                Box(Modifier.padding(top = 4.dp)) {
                                    GoButton(onClick = { MapsOpener.walk(context, stopPoint, stopName) })
                                }
                            }
                        }
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
    stopCode: String,
    phase: ColectivoPhase,
    lastUpdated: Instant?,
    dark: Boolean,
    onGo: () -> Unit,
    onTransit: () -> Unit
) {
    Column(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(20.dp))
            .background(Palette.surface(dark))
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            Box(
                Modifier
                    .size(46.dp)
                    .clip(RoundedCornerShape(12.dp))
                    .background(Palette.brand),
                contentAlignment = Alignment.Center
            ) {
                Icon(Icons.Rounded.DirectionsBus, contentDescription = null, tint = Color.White, modifier = Modifier.size(24.dp))
            }
            Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(
                    stopName,
                    color = Palette.textPrimary(dark),
                    fontSize = 22.sp,
                    fontWeight = FontWeight.Black,
                    maxLines = 3,
                    overflow = TextOverflow.Ellipsis
                )
                Text("Parada $stopCode", color = Palette.textSecondary(dark), fontSize = 13.sp, fontWeight = FontWeight.SemiBold)
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

// Fila de un arribo de colectivo: badge de línea + destino + countdown + demora.
@Composable
private fun ColectivoArrivalRow(arrival: BusArrival, dark: Boolean) {
    val color = BusLine.color(arrival.lineName)
    Row(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(Palette.surface(dark))
            .padding(vertical = 12.dp, horizontal = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        ColectivoBusBadge(arrival.lineName, color)
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(
                arrival.destino?.let { "a $it" } ?: "Línea ${arrival.lineName}",
                color = Palette.textPrimary(dark),
                fontSize = 16.sp,
                fontWeight = FontWeight.SemiBold,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
            Text("Hora ${Formatting.clock(arrival.eta)}", color = Palette.textSecondary(dark), fontSize = 12.sp, fontWeight = FontWeight.Medium)
        }
        Column(horizontalAlignment = Alignment.End, verticalArrangement = Arrangement.spacedBy(6.dp)) {
            CountdownText(secondsUntil = arrival.secondsUntil, big = false)
            DelayPill(status = arrival.delay)
        }
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
