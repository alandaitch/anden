package com.alandaitch.anden.data.model

import androidx.compose.ui.graphics.Color
import com.alandaitch.anden.ui.theme.hexColor

// Línea de subte (SBASE). routeId == Route_Id de forecastGTFS.
// Colores oficiales SBASE (ver docs/ba-api.md).
data class SubteLine(
    val routeId: String,   // "LineaA".."LineaH","Premetro"
    val letra: String,     // "A".."H","P"
    val nombre: String,
    val colorHex: String
) {
    val id: String get() = routeId
    val color: Color get() = hexColor(colorHex)

    companion object {
        // Las 6 líneas + premetro con la paleta oficial.
        val all: List<SubteLine> = listOf(
            SubteLine("LineaA", "A", "Línea A", "#00AEEF"),
            SubteLine("LineaB", "B", "Línea B", "#EE3124"),
            SubteLine("LineaC", "C", "Línea C", "#0072BC"),
            SubteLine("LineaD", "D", "Línea D", "#00A650"),
            SubteLine("LineaE", "E", "Línea E", "#8E44AD"),
            SubteLine("LineaH", "H", "Línea H", "#FFD200"),
            SubteLine("Premetro", "P", "Premetro", "#00A19A"),
        )

        val unknown = SubteLine("?", "?", "Subte", "#8A94A6")

        // Busca por routeId. Fallback: deriva la letra del sufijo ("LineaX" -> "X").
        fun line(routeId: String): SubteLine {
            all.firstOrNull { it.routeId.equals(routeId, ignoreCase = true) }?.let { return it }
            val suffix = routeId.replace("Linea", "", ignoreCase = true)
            val letra = if (suffix.isEmpty()) "?" else suffix.take(1).uppercase()
            return SubteLine(routeId, letra, routeId, "#8A94A6")
        }
    }
}
