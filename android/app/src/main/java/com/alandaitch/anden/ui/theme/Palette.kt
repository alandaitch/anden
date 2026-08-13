package com.alandaitch.anden.ui.theme

import androidx.compose.ui.graphics.Color

// Parseo de hex "#RRGGBB" (o "RRGGBB") a Color. Ignora no-alfanuméricos iniciales.
fun hexColor(hex: String): Color {
    val cleaned = hex.filter { it.isLetterOrDigit() }
    val v = cleaned.toLongOrNull(16) ?: 0L
    val r = ((v and 0xFF0000) shr 16).toInt()
    val g = ((v and 0x00FF00) shr 8).toInt()
    val b = (v and 0x0000FF).toInt()
    return Color(red = r, green = g, blue = b, alpha = 255)
}

// Paleta del PLAN iOS. Colores de línea, semánticos y fondos.
// Los fondos vienen en par claro/oscuro; la capa de UI elige según el tema.
object Palette {
    // Semánticos de demora (fijos, no dependen del tema)
    val onTime = hexColor("#22C55E")
    val minorDelay = hexColor("#F59E0B")
    val majorDelay = hexColor("#EF4444")
    val noData = hexColor("#8A94A6")

    // Marca (chrome)
    val brand = hexColor("#242C4F")

    // Fondos dinámicos: par (light, dark)
    val backgroundLight = hexColor("#EEF1F5")
    val backgroundDark = hexColor("#0A0C10")
    val surfaceLight = hexColor("#FFFFFF")
    val surfaceDark = hexColor("#151A22")
    val elevatedLight = hexColor("#FFFFFF")
    val elevatedDark = hexColor("#1E242E")

    // Texto dinámico: par (light, dark)
    val textPrimaryLight = hexColor("#0A0C10")
    val textPrimaryDark = hexColor("#F5F7FA")
    val textSecondaryLight = hexColor("#5B6472")
    val textSecondaryDark = hexColor("#9AA4B2")

    // Helpers de selección por tema (dark=true -> variante oscura).
    fun background(dark: Boolean) = if (dark) backgroundDark else backgroundLight
    fun surface(dark: Boolean) = if (dark) surfaceDark else surfaceLight
    fun elevated(dark: Boolean) = if (dark) elevatedDark else elevatedLight
    fun textPrimary(dark: Boolean) = if (dark) textPrimaryDark else textPrimaryLight
    fun textSecondary(dark: Boolean) = if (dark) textSecondaryDark else textSecondaryLight
}
