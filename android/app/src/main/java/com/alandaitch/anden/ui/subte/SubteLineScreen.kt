package com.alandaitch.anden.ui.subte

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
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.ChevronRight
import androidx.compose.material.icons.rounded.Train
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
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.alandaitch.anden.data.model.SubteLine
import com.alandaitch.anden.data.net.ApiError
import com.alandaitch.anden.data.net.BaApi
import com.alandaitch.anden.ui.components.EmptyState
import com.alandaitch.anden.ui.components.ErrorState
import com.alandaitch.anden.ui.components.LoadingState
import com.alandaitch.anden.ui.components.SubteBadge
import com.alandaitch.anden.ui.theme.Palette

private sealed interface SubteLinePhase {
    data object Loading : SubteLinePhase
    data class Ready(val stations: List<String>) : SubteLinePhase
    data object Empty : SubteLinePhase
    data class Error(val message: String) : SubteLinePhase
}

// Lista de estaciones de una línea. Cada una lleva al tablero de arribos.
@Composable
fun SubteLineScreen(
    routeId: String,
    onOpenStation: (stationName: String, routeId: String) -> Unit
) {
    val dark = isSystemInDarkTheme()
    val line = remember(routeId) { SubteLine.line(routeId) }
    var phase by remember(routeId) { mutableStateOf<SubteLinePhase>(SubteLinePhase.Loading) }
    var reloadKey by remember(routeId) { mutableIntStateOf(0) }

    LaunchedEffect(routeId, reloadKey) {
        phase = SubteLinePhase.Loading
        try {
            val list = BaApi.shared.subteStations(line)
            phase = if (list.isEmpty()) SubteLinePhase.Empty else SubteLinePhase.Ready(list)
        } catch (e: ApiError) {
            phase = SubteLinePhase.Error(e.message ?: "Revisá tu conexión e intentá de nuevo.")
        } catch (e: Exception) {
            phase = SubteLinePhase.Error("Revisá tu conexión e intentá de nuevo.")
        }
    }

    Box(
        Modifier
            .fillMaxSize()
            .background(Palette.background(dark))
    ) {
        when (val p = phase) {
            is SubteLinePhase.Loading ->
                LoadingState(message = "Buscando estaciones de ${line.nombre}…")

            is SubteLinePhase.Empty ->
                EmptyState(
                    icon = Icons.Rounded.Train,
                    title = "Sin servicio ahora",
                    message = "No hay trenes en circulación en ${line.nombre} en este momento. Probá de nuevo en un rato.",
                    actionTitle = "Reintentar",
                    onAction = { reloadKey++ }
                )

            is SubteLinePhase.Error ->
                ErrorState(message = p.message, onRetry = { reloadKey++ })

            is SubteLinePhase.Ready -> {
                val stations = p.stations
                LazyColumn(
                    Modifier.fillMaxSize(),
                    contentPadding = PaddingValues(16.dp, 12.dp, 16.dp, 32.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    item {
                        SubteLineHeader(line, dark)
                    }
                    item {
                        Text(
                            "${stations.size} estaciones en servicio",
                            color = Palette.textSecondary(dark),
                            fontSize = 13.sp,
                            fontWeight = FontWeight.Medium,
                            modifier = Modifier.padding(start = 4.dp, top = 4.dp, bottom = 2.dp)
                        )
                    }
                    itemsIndexed(stations, key = { _, name -> name }) { index, name ->
                        SubteStationRow(
                            name = name,
                            lineColor = line.color,
                            surface = Palette.surface(dark),
                            textPrimary = Palette.textPrimary(dark),
                            textSecondary = Palette.textSecondary(dark),
                            isFirst = index == 0,
                            isLast = index == stations.size - 1
                        ) { onOpenStation(name, routeId) }
                    }
                }
            }
        }
    }
}

@Composable
private fun SubteLineHeader(line: SubteLine, dark: Boolean) {
    Row(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(20.dp))
            .background(Palette.surface(dark))
            .padding(16.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(14.dp)
    ) {
        SubteBadge(line = line, size = 52.dp)
        Column(verticalArrangement = Arrangement.spacedBy(3.dp)) {
            Text(line.nombre, color = Palette.textPrimary(dark), fontSize = 26.sp, fontWeight = FontWeight.Black)
            Text("Elegí una estación", color = Palette.textSecondary(dark), fontSize = 14.sp, fontWeight = FontWeight.Medium)
        }
    }
}

// Fila de estación con un conector vertical estilo mapa de línea.
@Composable
private fun SubteStationRow(
    name: String,
    lineColor: Color,
    surface: Color,
    textPrimary: Color,
    textSecondary: Color,
    isFirst: Boolean,
    isLast: Boolean,
    onClick: () -> Unit
) {
    Row(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .background(surface)
            .clickable(onClick = onClick)
            .padding(vertical = 12.dp, horizontal = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(14.dp)
    ) {
        Box(Modifier.width(18.dp).height(44.dp), contentAlignment = Alignment.Center) {
            Column(Modifier.fillMaxSize(), horizontalAlignment = Alignment.CenterHorizontally) {
                Box(Modifier.width(3.dp).weight(1f).background(if (isFirst) Color.Transparent else lineColor))
                Box(Modifier.width(3.dp).weight(1f).background(if (isLast) Color.Transparent else lineColor))
            }
            Box(
                Modifier
                    .size(14.dp)
                    .clip(CircleShape)
                    .background(lineColor),
                contentAlignment = Alignment.Center
            ) {
                Box(Modifier.size(6.dp).clip(CircleShape).background(surface))
            }
        }
        Text(
            name,
            color = textPrimary,
            fontSize = 16.sp,
            fontWeight = FontWeight.SemiBold,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.weight(1f)
        )
        Icon(Icons.Rounded.ChevronRight, contentDescription = null, tint = textSecondary, modifier = Modifier.size(18.dp))
    }
}
