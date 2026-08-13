package com.alandaitch.anden.ui.components

import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Dangerous
import androidx.compose.material.icons.filled.Schedule
import androidx.compose.material.icons.filled.Speed
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.alandaitch.anden.data.model.DelayStatus
import com.alandaitch.anden.ui.theme.Palette
import com.alandaitch.anden.ui.theme.andenColors
import com.alandaitch.anden.util.Formatting

// Punto "en vivo" que pulsa con un halo. Se detiene si active == false.
@Composable
fun LiveDot(
    active: Boolean,
    modifier: Modifier = Modifier,
    color: Color = Palette.onTime,
    size: Dp = 8.dp,
) {
    val halo = size * 2.4f
    Box(
        modifier = modifier.size(halo),
        contentAlignment = Alignment.Center,
    ) {
        if (active) {
            val transition = rememberInfiniteTransition(label = "livedot")
            val progress by transition.animateFloat(
                initialValue = 0f,
                targetValue = 1f,
                animationSpec = infiniteRepeatable(
                    animation = tween(durationMillis = 1400),
                    repeatMode = RepeatMode.Restart,
                ),
                label = "pulse",
            )
            Box(
                modifier = Modifier
                    .size(halo)
                    .scale(0.4f + progress * 0.6f)
                    .clip(CircleShape)
                    .background(color.copy(alpha = (1f - progress) * 0.35f)),
            )
        }
        Box(
            modifier = Modifier
                .size(size)
                .clip(CircleShape)
                .background(if (active) color else Palette.noData),
        )
    }
}

// Cápsula con color semántico y label de demora.
@Composable
fun DelayPill(status: DelayStatus, modifier: Modifier = Modifier, compact: Boolean = false) {
    val color = status.color
    val icon = delayIcon(status)
    val label = if (compact) status.shortLabel else status.label
    Row(
        modifier = modifier
            .clip(CircleShape)
            .background(color.copy(alpha = 0.16f))
            .border(0.5.dp, color.copy(alpha = 0.28f), CircleShape)
            .padding(horizontal = if (compact) 7.dp else 9.dp, vertical = if (compact) 3.dp else 4.dp)
            .semantics { contentDescription = status.label },
        horizontalArrangement = Arrangement.spacedBy(4.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (icon != null) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                tint = color,
                modifier = Modifier.size(if (compact) 11.dp else 12.dp),
            )
        }
        Text(
            text = label,
            color = color,
            fontWeight = FontWeight.Bold,
            fontSize = (if (compact) 11 else 12).sp,
            maxLines = 1,
        )
    }
}

private fun delayIcon(status: DelayStatus): ImageVector? = when (status) {
    is DelayStatus.OnTime -> Icons.Filled.CheckCircle
    is DelayStatus.Early -> Icons.Filled.Speed
    is DelayStatus.Minor -> Icons.Filled.Schedule
    is DelayStatus.Major -> Icons.Filled.Warning
    is DelayStatus.Cancelled -> Icons.Filled.Dangerous
    is DelayStatus.NoData -> null
}

// Numeral héroe del countdown. "ahora"/"llegando" o el número de minutos grande + "min".
@Composable
fun CountdownText(secondsUntil: Int, modifier: Modifier = Modifier, big: Boolean = true) {
    val colors = andenColors()
    val numberSize = if (big) 44 else 26
    val wordSize = if (big) 24 else 16
    val unitSize = if (big) 15 else 12
    Box(
        modifier = modifier.clearAndSetSemantics {
            contentDescription = Formatting.etaText(secondsUntil)
        },
    ) {
        when {
            secondsUntil <= 30 -> Text(
                text = "ahora",
                color = colors.onTime,
                fontWeight = FontWeight.Bold,
                fontSize = wordSize.sp,
                maxLines = 1,
            )
            secondsUntil < 90 -> Text(
                text = "llegando",
                color = colors.onTime,
                fontWeight = FontWeight.Bold,
                fontSize = wordSize.sp,
                maxLines = 1,
            )
            else -> Row(verticalAlignment = Alignment.Bottom) {
                Text(
                    text = "${Formatting.minutesUntil(secondsUntil)}",
                    color = colors.textPrimary,
                    fontWeight = FontWeight.Black,
                    fontFamily = FontFamily.SansSerif,
                    fontSize = numberSize.sp,
                    maxLines = 1,
                )
                Text(
                    text = " min",
                    color = colors.textSecondary,
                    fontWeight = FontWeight.SemiBold,
                    fontSize = unitSize.sp,
                    maxLines = 1,
                    modifier = Modifier.padding(bottom = (numberSize * 0.12f).dp),
                )
            }
        }
    }
}
