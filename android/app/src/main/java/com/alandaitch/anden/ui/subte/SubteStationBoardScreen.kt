package com.alandaitch.anden.ui.subte

import androidx.compose.foundation.background
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
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
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Train
import androidx.compose.material3.CircularProgressIndicator
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
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.alandaitch.anden.data.model.SubteArrival
import com.alandaitch.anden.data.model.SubteLine
import com.alandaitch.anden.data.net.ApiError
import com.alandaitch.anden.data.net.BaApi
import com.alandaitch.anden.ui.components.CountdownText
import com.alandaitch.anden.ui.components.DelayPill
import com.alandaitch.anden.ui.components.EmptyState
import com.alandaitch.anden.ui.components.ErrorState
import com.alandaitch.anden.ui.components.LoadingState
import com.alandaitch.anden.ui.components.SubteBadge
import com.alandaitch.anden.ui.theme.Palette
import com.alandaitch.anden.util.Formatting
import kotlinx.coroutines.delay
import java.time.Instant

private sealed interface SubteBoardPhase {
    data object Loading : SubteBoardPhase
    data object Ready : SubteBoardPhase
    data object Empty : SubteBoardPhase
    data class Error(val message: String) : SubteBoardPhase
}

private data class SubteDestGroup(val destinationName: String, val arrivals: List<SubteArrival>)

private fun groupByDestination(arrivals: List<SubteArrival>): List<SubteDestGroup> {
    val order = mutableListOf<String>()
    val map = linkedMapOf<String, MutableList<SubteArrival>>()
    for (a in arrivals) {
        if (map[a.destinationName] == null) {
            order.add(a.destinationName)
            map[a.destinationName] = mutableListOf()
        }
        map[a.destinationName]!!.add(a)
    }
    return order.map { dest ->
        SubteDestGroup(dest, (map[dest] ?: emptyList()).sortedBy { it.secondsUntil })
    }
}

// Tablero de arribos de una estación de subte. Auto-refresh 20s.
@Composable
fun SubteStationBoardScreen(stationName: String, routeId: String?) {
    val dark = isSystemInDarkTheme()
    val line = remember(routeId) { routeId?.let { SubteLine.line(it) } }

    var arrivals by remember(stationName, routeId) { mutableStateOf<List<SubteArrival>>(emptyList()) }
    var phase by remember(stationName, routeId) { mutableStateOf<SubteBoardPhase>(SubteBoardPhase.Loading) }
    var lastUpdated by remember(stationName, routeId) { mutableStateOf<Instant?>(null) }
    var reloadKey by remember(stationName, routeId) { mutableIntStateOf(0) }

    LaunchedEffect(stationName, routeId, reloadKey) {
        if (arrivals.isEmpty()) phase = SubteBoardPhase.Loading
        while (true) {
            try {
                val all = BaApi.shared.subteArrivals(stationName)
                val filtered = if (line != null) all.filter { it.line.routeId == line.routeId } else all
                arrivals = filtered
                phase = if (filtered.isEmpty()) SubteBoardPhase.Empty else SubteBoardPhase.Ready
                lastUpdated = Instant.now()
            } catch (e: ApiError) {
                if (arrivals.isEmpty()) {
                    phase = SubteBoardPhase.Error(e.message ?: "Revisá tu conexión e intentá de nuevo.")
                }
            } catch (e: Exception) {
                if (arrivals.isEmpty()) {
                    phase = SubteBoardPhase.Error("Revisá tu conexión e intentá de nuevo.")
                }
            }
            delay(20_000)
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
                SubteBoardHeader(stationName, line, phase, lastUpdated, dark)
            }

            when (val p = phase) {
                is SubteBoardPhase.Loading -> {
                    if (arrivals.isEmpty()) {
                        item { LoadingState(message = "Buscando trenes en $stationName…") }
                    }
                }
                is SubteBoardPhase.Empty ->
                    item {
                        EmptyState(
                            icon = Icons.Rounded.Train,
                            title = "Sin trenes ahora",
                            message = "No hay arribos en vivo para $stationName en este momento.",
                            actionTitle = "Reintentar",
                            onAction = { reloadKey++ }
                        )
                    }
                is SubteBoardPhase.Error ->
                    item { ErrorState(message = p.message, onRetry = { reloadKey++ }) }
                is SubteBoardPhase.Ready -> {
                    val groups = groupByDestination(arrivals)
                    groups.forEach { group ->
                        item(key = "hdr-${group.destinationName}") {
                            Text(
                                "HACIA ${group.destinationName.uppercase()}",
                                color = Palette.textSecondary(dark),
                                fontSize = 13.sp,
                                fontWeight = FontWeight.Bold,
                                modifier = Modifier.padding(start = 4.dp)
                            )
                        }
                        group.arrivals.firstOrNull()?.let { first ->
                            item(key = "hero-${first.id}") { SubteHeroCard(first, dark) }
                        }
                        group.arrivals.drop(1).take(4).forEach { arrival ->
                            item(key = "row-${arrival.id}") { SubteArrivalRow(arrival, dark) }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun SubteBoardHeader(
    stationName: String,
    line: SubteLine?,
    phase: SubteBoardPhase,
    lastUpdated: Instant?,
    dark: Boolean
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
            if (line != null) SubteBadge(line = line, size = 52.dp)
            Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(
                    stationName,
                    color = Palette.textPrimary(dark),
                    fontSize = 24.sp,
                    fontWeight = FontWeight.Black,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis
                )
                if (line != null) {
                    Text(line.nombre, color = line.color, fontSize = 14.sp, fontWeight = FontWeight.SemiBold)
                }
            }
        }
        // Barra de estado.
        when (phase) {
            is SubteBoardPhase.Ready ->
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
            is SubteBoardPhase.Loading ->
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    CircularProgressIndicator(Modifier.size(14.dp), strokeWidth = 2.dp, color = Palette.textSecondary(dark))
                    Text("Buscando trenes…", color = Palette.textSecondary(dark), fontSize = 12.sp, fontWeight = FontWeight.Medium)
                }
            else -> {}
        }
    }
}

// Tarjeta principal del próximo tren del grupo, con countdown grande.
@Composable
private fun SubteHeroCard(arrival: SubteArrival, dark: Boolean) {
    Column(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(20.dp))
            .background(Palette.surface(dark))
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            SubteBadge(line = arrival.line, size = 36.dp)
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Text("PRÓXIMO", color = Palette.textSecondary(dark), fontSize = 11.sp, fontWeight = FontWeight.SemiBold)
                Text(
                    arrival.destinationName,
                    color = Palette.textPrimary(dark),
                    fontSize = 18.sp,
                    fontWeight = FontWeight.Bold,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
            }
            Box(Modifier.size(7.dp).clip(CircleShape).background(Palette.onTime))
        }
        Row(verticalAlignment = Alignment.Bottom) {
            CountdownText(secondsUntil = arrival.secondsUntil, big = true)
            Spacer(Modifier.weight(1f))
            Column(horizontalAlignment = Alignment.End, verticalArrangement = Arrangement.spacedBy(6.dp)) {
                DelayPill(status = arrival.delay)
                Text(
                    "Hora ${Formatting.clock(arrival.eta)}",
                    color = Palette.textSecondary(dark),
                    fontSize = 12.sp,
                    fontWeight = FontWeight.Medium
                )
            }
        }
    }
}

// Fila compacta de un arribo de subte.
@Composable
private fun SubteArrivalRow(arrival: SubteArrival, dark: Boolean) {
    Row(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(Palette.surface(dark))
            .padding(vertical = 12.dp, horizontal = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        SubteBadge(line = arrival.line, size = 38.dp)
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(
                arrival.destinationName,
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
