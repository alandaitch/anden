package com.alandaitch.anden.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AltRoute
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.DirectionsWalk
import androidx.compose.material.icons.filled.PinDrop
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.alandaitch.anden.data.model.Arrival
import com.alandaitch.anden.ui.theme.Palette
import com.alandaitch.anden.ui.theme.andenColors
import com.alandaitch.anden.util.Formatting
import com.alandaitch.anden.util.GeoPoint
import com.alandaitch.anden.util.MapsOpener

// Fila rica de un arribo: destino, badge de línea, ramal/andén, countdown y demora.
@Composable
fun ArrivalRow(arrival: Arrival, modifier: Modifier = Modifier) {
    val colors = andenColors()
    val isLive = arrival.trainLocation != null || arrival.estimated != null
    CardRow(modifier = modifier, accent = arrival.line.color) {
        LineBadge(line = arrival.line, size = 40.dp)
        Spacer(Modifier.width(12.dp))
        Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                Text(
                    text = arrival.destinationName,
                    color = colors.textPrimary,
                    fontWeight = FontWeight.SemiBold,
                    fontSize = 17.sp,
                    maxLines = 1,
                )
                if (isLive) LiveDot(active = true, color = Palette.onTime, size = 6.dp)
            }
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                if (arrival.ramalName.isNotEmpty()) {
                    IconLabel(icon = Icons.Filled.AltRoute, text = arrival.ramalName, color = colors.textSecondary)
                }
                val track = arrival.trackName
                if (!track.isNullOrEmpty()) {
                    IconLabel(icon = Icons.Filled.DirectionsWalk, text = "And. $track", color = colors.textSecondary)
                }
            }
        }
        Spacer(Modifier.width(8.dp))
        Column(horizontalAlignment = Alignment.End, verticalArrangement = Arrangement.spacedBy(6.dp)) {
            CountdownText(secondsUntil = arrival.secondsUntil, big = false)
            DelayPill(arrival.delay, compact = true)
        }
    }
}

// Fila genérica multimodal: badge/ícono de modo, título, subtítulo, distancia, "Ir" y chevron.
@Composable
fun NearbyRow(
    title: String,
    modeLabel: String,
    modeColor: Color,
    distanceMeters: Double,
    accent: Color,
    subtitle: String?,
    subtitleColor: Color,
    onGo: () -> Unit,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    leading: @Composable () -> Unit,
) {
    val colors = andenColors()
    CardRow(
        modifier = modifier.clickable(onClick = onClick),
        accent = accent,
    ) {
        leading()
        Spacer(Modifier.width(12.dp))
        Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(
                text = title,
                color = colors.textPrimary,
                fontWeight = FontWeight.SemiBold,
                fontSize = 16.sp,
                maxLines = 1,
            )
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                Text(modeLabel, color = modeColor, fontWeight = FontWeight.Bold, fontSize = 11.sp, maxLines = 1)
                Text("·", color = colors.textSecondary, fontSize = 11.sp)
                Text(Formatting.distanceText(distanceMeters), color = colors.textSecondary, fontWeight = FontWeight.Medium, fontSize = 12.sp, maxLines = 1)
            }
            if (subtitle != null) {
                Text(subtitle, color = subtitleColor, fontWeight = FontWeight.SemiBold, fontSize = 12.sp, maxLines = 1)
            }
        }
        Spacer(Modifier.width(8.dp))
        GoButton(onClick = onGo)
        Spacer(Modifier.width(6.dp))
        Icon(
            Icons.Filled.ChevronRight,
            contentDescription = null,
            tint = colors.textSecondary.copy(alpha = 0.5f),
            modifier = Modifier.size(18.dp),
        )
    }
}

// Botón "Ir" con ícono de caminata. Variante lambda (la fila cablea la acción).
@Composable
fun GoButton(onClick: () -> Unit, modifier: Modifier = Modifier) {
    val colors = andenColors()
    Column(
        modifier = modifier
            .size(46.dp)
            .clip(CircleShape)
            .background(colors.brand.copy(alpha = 0.14f))
            .clickable(onClick = onClick)
            .semantics { contentDescription = "Ir" },
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Icon(Icons.Filled.DirectionsWalk, contentDescription = null, tint = colors.brand, modifier = Modifier.size(16.dp))
        Text("Ir", color = colors.brand, fontWeight = FontWeight.Bold, fontSize = 11.sp)
    }
}

// Botón "Ir" conveniente: abre MapsOpener.walk hacia la coordenada.
@Composable
fun GoButton(to: GeoPoint, name: String, modifier: Modifier = Modifier) {
    val context = LocalContext.current
    GoButton(onClick = { MapsOpener.walk(context, to, name) }, modifier = modifier)
}

// Contenedor de fila con superficie, esquinas y barra de acento a la izquierda.
@Composable
private fun CardRow(
    accent: Color,
    modifier: Modifier = Modifier,
    content: @Composable androidx.compose.foundation.layout.RowScope.() -> Unit,
) {
    val colors = andenColors()
    val shape = RoundedCornerShape(16.dp)
    Box(modifier = modifier.fillMaxWidth().clip(shape).background(colors.surface)) {
        Box(
            modifier = Modifier
                .align(Alignment.CenterStart)
                .padding(start = 2.dp, top = 12.dp, bottom = 12.dp)
                .width(4.dp)
                .height(24.dp)
                .clip(RoundedCornerShape(3.dp))
                .background(accent),
        )
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 14.dp, vertical = 11.dp),
            verticalAlignment = Alignment.CenterVertically,
            content = content,
        )
    }
}

@Composable
private fun IconLabel(icon: androidx.compose.ui.graphics.vector.ImageVector, text: String, color: Color) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(3.dp)) {
        Icon(icon, contentDescription = null, tint = color, modifier = Modifier.size(12.dp))
        Text(text, color = color, fontWeight = FontWeight.Medium, fontSize = 12.sp, maxLines = 1)
    }
}

// Ícono redondeado genérico para modos sin badge de código (EcoBici, colectivo genérico).
@Composable
fun ModeIconBadge(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    fill: Color,
    modifier: Modifier = Modifier,
    size: androidx.compose.ui.unit.Dp = 40.dp,
) {
    Box(
        modifier = modifier
            .size(size)
            .clip(RoundedCornerShape((size.value * 0.26f).dp))
            .background(fill),
        contentAlignment = Alignment.Center,
    ) {
        Icon(icon, contentDescription = null, tint = Color.White, modifier = Modifier.size(size * 0.5f))
    }
}

// Ícono por defecto de parada genérica (colectivo).
val StopPinIcon = Icons.Filled.PinDrop
