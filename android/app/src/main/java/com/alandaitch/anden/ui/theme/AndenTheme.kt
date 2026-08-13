package com.alandaitch.anden.ui.theme

import androidx.compose.foundation.background
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Typography
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

// Acento de EcoBici (no hay línea; color fijo del PLAN iOS).
val BiciAccent: Color = hexColor("#0FA3A3")

// Bundle de colores resueltos según el tema. Los componentes lo leen con andenColors().
@Immutable
data class AndenColors(
    val dark: Boolean,
    val background: Color,
    val surface: Color,
    val elevated: Color,
    val textPrimary: Color,
    val textSecondary: Color,
    val brand: Color,
    val onTime: Color,
    val minorDelay: Color,
    val majorDelay: Color,
    val noData: Color,
) {
    companion object {
        fun of(dark: Boolean) = AndenColors(
            dark = dark,
            background = Palette.background(dark),
            surface = Palette.surface(dark),
            elevated = Palette.elevated(dark),
            textPrimary = Palette.textPrimary(dark),
            textSecondary = Palette.textSecondary(dark),
            brand = Palette.brand,
            onTime = Palette.onTime,
            minorDelay = Palette.minorDelay,
            majorDelay = Palette.majorDelay,
            noData = Palette.noData,
        )
    }
}

// Default oscuro para previews y para usos fuera de AndenTheme.
val LocalAndenColors = staticCompositionLocalOf { AndenColors.of(dark = true) }

// Acceso corto a los colores del tema desde cualquier composable.
@Composable
fun andenColors(): AndenColors = LocalAndenColors.current

private fun schemeFor(c: AndenColors) = if (c.dark) {
    darkColorScheme(
        primary = c.brand,
        onPrimary = Color.White,
        background = c.background,
        onBackground = c.textPrimary,
        surface = c.surface,
        onSurface = c.textPrimary,
        surfaceVariant = c.elevated,
        onSurfaceVariant = c.textSecondary,
        error = c.majorDelay,
    )
} else {
    lightColorScheme(
        primary = c.brand,
        onPrimary = Color.White,
        background = c.background,
        onBackground = c.textPrimary,
        surface = c.surface,
        onSurface = c.textPrimary,
        surfaceVariant = c.elevated,
        onSurfaceVariant = c.textSecondary,
        error = c.majorDelay,
    )
}

// Tipografía con familia por defecto (SansSerif redondeado del sistema).
private val AndenTypography = Typography()

// Tema raíz. Elige variante clara/oscura con el sistema salvo override.
@Composable
fun AndenTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit,
) {
    val colors = AndenColors.of(darkTheme)
    androidx.compose.runtime.CompositionLocalProvider(LocalAndenColors provides colors) {
        MaterialTheme(
            colorScheme = schemeFor(colors),
            typography = AndenTypography,
            content = content,
        )
    }
}

// Estilo "card": fondo elevado, esquinas ~18dp, sombra suave. Aplicar al Modifier del contenedor.
@Composable
fun Modifier.andenCard(corner: Dp = 18.dp, elevated: Boolean = false): Modifier {
    val colors = andenColors()
    val shape = RoundedCornerShape(corner)
    return this
        .shadow(if (elevated) 8.dp else 3.dp, shape, clip = false)
        .clip(shape)
        .background(if (elevated) colors.elevated else colors.surface)
}
