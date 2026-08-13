package com.alandaitch.anden.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.alandaitch.anden.data.model.BusLine
import com.alandaitch.anden.data.model.SubteLine
import com.alandaitch.anden.data.model.TrainLine

// Badge cuadrado redondeado con el color de la línea de tren y su sigla en blanco.
@Composable
fun LineBadge(line: TrainLine, modifier: Modifier = Modifier, size: Dp = 28.dp) {
    SquareBadge(
        modifier = modifier,
        size = size,
        fill = line.color,
        text = line.shortCode,
        textColor = Color.White,
        cornerFactor = 0.28f,
        borderColor = Color.White.copy(alpha = 0.12f),
        contentDescription = "Línea ${line.nombre}",
    )
}

// Badge cuadrado con el color oficial del subte. Texto negro/blanco según luminancia.
@Composable
fun SubteBadge(line: SubteLine, modifier: Modifier = Modifier, size: Dp = 32.dp) {
    SquareBadge(
        modifier = modifier,
        size = size,
        fill = line.color,
        text = line.letra,
        textColor = if (isLightColor(line.colorHex)) Color.Black else Color.White,
        cornerFactor = 0.24f,
        borderColor = Color.Black.copy(alpha = 0.08f),
        contentDescription = line.nombre,
    )
}

// Badge cuadrado de colectivo con su color determinístico y el código (shortName).
@Composable
fun BusBadge(line: BusLine, modifier: Modifier = Modifier, size: Dp = 40.dp) {
    SquareBadge(
        modifier = modifier,
        size = size,
        fill = line.color,
        text = line.shortName,
        textColor = Color.White,
        cornerFactor = 0.26f,
        borderColor = Color.White.copy(alpha = 0.12f),
        contentDescription = "Línea ${line.shortName}",
    )
}

@Composable
private fun SquareBadge(
    size: Dp,
    fill: Color,
    text: String,
    textColor: Color,
    cornerFactor: Float,
    borderColor: Color,
    contentDescription: String,
    modifier: Modifier = Modifier,
) {
    val shape = RoundedCornerShape((size.value * cornerFactor).dp)
    Box(
        modifier = modifier
            .size(size)
            .clip(shape)
            .background(fill)
            .border(0.5.dp, borderColor, shape)
            .semantics { this.contentDescription = contentDescription },
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = text,
            color = textColor,
            fontWeight = FontWeight.Black,
            fontFamily = FontFamily.SansSerif,
            fontSize = (size.value * 0.44f).sp,
            maxLines = 1,
            textAlign = TextAlign.Center,
            modifier = Modifier.padding(horizontal = 1.dp),
        )
    }
}

// Luminancia relativa del hex para decidir texto negro/blanco (la línea H amarilla pide negro).
fun isLightColor(hex: String): Boolean {
    var s = hex.trim()
    if (s.startsWith("#")) s = s.drop(1)
    if (s.length != 6) return false
    val v = s.toLongOrNull(16) ?: return false
    val r = ((v shr 16) and 0xFF) / 255.0
    val g = ((v shr 8) and 0xFF) / 255.0
    val b = (v and 0xFF) / 255.0
    val lum = 0.299 * r + 0.587 * g + 0.114 * b
    return lum > 0.6
}
