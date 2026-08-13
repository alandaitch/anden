package com.alandaitch.anden.ui.subte

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.AltRoute
import androidx.compose.material.icons.rounded.Block
import androidx.compose.material.icons.rounded.CheckCircle
import androidx.compose.material.icons.rounded.ChevronRight
import androidx.compose.material.icons.rounded.Error
import androidx.compose.material.icons.rounded.PinDrop
import androidx.compose.material.icons.rounded.ScheduleSend
import androidx.compose.material.icons.rounded.Train
import androidx.compose.material.icons.rounded.WifiOff
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.alandaitch.anden.data.model.SubteAlertItem
import com.alandaitch.anden.data.model.SubteLine
import com.alandaitch.anden.data.net.ApiError
import com.alandaitch.anden.data.net.BaApi
import com.alandaitch.anden.ui.components.SubteBadge
import com.alandaitch.anden.ui.theme.Palette

// Estado del home de subte.
private sealed interface SubteHomePhase {
    data object Loading : SubteHomePhase
    data class Ready(val alertsByLine: Map<String, List<SubteAlertItem>>) : SubteHomePhase
    data class Error(val message: String) : SubteHomePhase
}

// Home del subte: estado de servicio + lista de líneas A-E, H.
@Composable
fun SubteHomeScreen(onOpenLine: (routeId: String) -> Unit) {
    val dark = androidx.compose.foundation.isSystemInDarkTheme()
    var phase by remember { mutableStateOf<SubteHomePhase>(SubteHomePhase.Loading) }

    suspend fun load() {
        try {
            val alerts = BaApi.shared.subteAlerts()
            val map = alerts.groupBy { it.line.routeId }
            phase = SubteHomePhase.Ready(map)
        } catch (e: ApiError) {
            phase = SubteHomePhase.Error(e.message ?: "Revisá tu conexión e intentá de nuevo.")
        } catch (e: Exception) {
            phase = SubteHomePhase.Error("Revisá tu conexión e intentá de nuevo.")
        }
    }

    LaunchedEffect(Unit) { load() }

    val lines = remember { SubteLine.all.filter { it.routeId != "Premetro" } }
    val current = phase

    Box(
        Modifier
            .fillMaxSize()
            .background(Palette.background(dark))
    ) {
        LazyColumn(
            Modifier.fillMaxSize(),
            contentPadding = androidx.compose.foundation.layout.PaddingValues(16.dp, 12.dp, 16.dp, 32.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            // Estado del servicio.
            item {
                when (current) {
                    is SubteHomePhase.Loading ->
                        SubteStatusBanner(
                            icon = null,
                            iconColor = Palette.textSecondary(dark),
                            text = "Consultando estado del servicio…",
                            dark = dark,
                            loading = true
                        )
                    is SubteHomePhase.Error ->
                        SubteStatusBanner(
                            icon = Icons.Rounded.WifiOff,
                            iconColor = Palette.minorDelay,
                            text = current.message,
                            dark = dark
                        )
                    is SubteHomePhase.Ready -> {
                        val all = current.alertsByLine.values.flatten().sortedBy { it.severity }
                        if (all.isEmpty()) {
                            SubteNormalBanner(dark)
                        } else {
                            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                                SubteSectionTitle("Estado del servicio", dark)
                                all.forEach { SubteAlertCard(it, dark) }
                            }
                        }
                    }
                }
            }

            item {
                SubteSectionTitle("Líneas", dark, subtitle = "Tocá una para ver estaciones y arribos")
            }

            items(lines, key = { it.routeId }) { line ->
                val top = (current as? SubteHomePhase.Ready)
                    ?.alertsByLine?.get(line.routeId)
                    ?.minByOrNull { it.severity }
                SubteLineRow(line = line, top = top, dark = dark) { onOpenLine(line.routeId) }
            }
        }
    }
}

@Composable
private fun SubteStatusBanner(
    icon: ImageVector?,
    iconColor: Color,
    text: String,
    dark: Boolean,
    loading: Boolean = false
) {
    Row(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(Palette.surface(dark))
            .padding(14.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        if (loading) {
            CircularProgressIndicator(
                Modifier.size(16.dp),
                strokeWidth = 2.dp,
                color = iconColor
            )
        } else if (icon != null) {
            Icon(icon, contentDescription = null, tint = iconColor, modifier = Modifier.size(18.dp))
        }
        Text(
            text,
            color = Palette.textSecondary(dark),
            fontSize = 13.sp,
            fontWeight = FontWeight.Medium,
            maxLines = 2,
            overflow = TextOverflow.Ellipsis
        )
    }
}

@Composable
private fun SubteNormalBanner(dark: Boolean) {
    Row(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(Palette.onTime.copy(alpha = 0.12f))
            .padding(14.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        Icon(Icons.Rounded.CheckCircle, contentDescription = null, tint = Palette.onTime, modifier = Modifier.size(18.dp))
        Text(
            "Toda la red funciona con normalidad",
            color = Palette.textPrimary(dark),
            fontSize = 14.sp,
            fontWeight = FontWeight.SemiBold
        )
    }
}

@Composable
private fun SubteAlertCard(alert: SubteAlertItem, dark: Boolean) {
    val tint = subteTint(alert)
    Row(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(Palette.surface(dark))
            .padding(14.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        SubteBadge(line = alert.line, size = 36.dp)
        Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                Icon(subteAlertIcon(alert.iconName), contentDescription = null, tint = tint, modifier = Modifier.size(14.dp))
                Text(subteShortStatus(alert), color = tint, fontSize = 13.sp, fontWeight = FontWeight.Bold)
            }
            Text(alert.text, color = Palette.textSecondary(dark), fontSize = 13.sp)
        }
    }
}

@Composable
private fun SubteLineRow(line: SubteLine, top: SubteAlertItem?, dark: Boolean, onClick: () -> Unit) {
    Row(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(Palette.surface(dark))
            .clickable(onClick = onClick)
            .padding(vertical = 12.dp, horizontal = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(14.dp)
    ) {
        SubteBadge(line = line, size = 44.dp)
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
            Text(line.nombre, color = Palette.textPrimary(dark), fontSize = 17.sp, fontWeight = FontWeight.SemiBold)
            if (top != null) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(5.dp)) {
                    Icon(subteAlertIcon(top.iconName), contentDescription = null, tint = subteTint(top), modifier = Modifier.size(12.dp))
                    Text(subteShortStatus(top), color = subteTint(top), fontSize = 12.sp, fontWeight = FontWeight.Medium, maxLines = 1, overflow = TextOverflow.Ellipsis)
                }
            } else {
                Text("Servicio normal", color = Palette.onTime, fontSize = 12.sp, fontWeight = FontWeight.Medium)
            }
        }
        Icon(Icons.Rounded.ChevronRight, contentDescription = null, tint = Palette.textSecondary(dark), modifier = Modifier.size(18.dp))
    }
}

// ---- Helpers de sección compartidos por el feature Subte ----

@Composable
internal fun SubteSectionTitle(title: String, dark: Boolean, subtitle: String? = null) {
    Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
        Text(title, color = Palette.textPrimary(dark), fontSize = 18.sp, fontWeight = FontWeight.Bold)
        if (subtitle != null) {
            Text(subtitle, color = Palette.textSecondary(dark), fontSize = 13.sp, fontWeight = FontWeight.Medium)
        }
    }
}

// Tinte por gravedad del efecto GTFS-rt.
internal fun subteTint(alert: SubteAlertItem): Color = when (alert.effect) {
    1, 4 -> Palette.majorDelay
    2, 6 -> Palette.minorDelay
    else -> Palette.noData
}

// Texto corto del estado de una línea.
internal fun subteShortStatus(alert: SubteAlertItem): String = when (alert.effect) {
    1 -> "Sin servicio"
    2 -> "Servicio reducido"
    4 -> "Demoras"
    6 -> "Desvío"
    8 -> "Estación movida"
    else -> "Con novedades"
}

// Mapea el iconName string del modelo a un ImageVector Material.
internal fun subteAlertIcon(name: String): ImageVector = when (name) {
    "block" -> Icons.Rounded.Block
    "schedule_alert" -> Icons.Rounded.ScheduleSend
    "alt_route" -> Icons.Rounded.AltRoute
    "wrong_location" -> Icons.Rounded.PinDrop
    "train_tunnel" -> Icons.Rounded.Train
    else -> Icons.Rounded.Error
}
