package com.alandaitch.anden.data.model

import androidx.compose.ui.graphics.Color
import com.alandaitch.anden.ui.theme.hexColor
import com.alandaitch.anden.util.Text

// Línea de tren. id == gerenciaId de la API SOFSE.
data class TrainLine(
    val id: Int,
    val nombre: String,
    val shortCode: String,
    val colorHex: String,
    val covered: Boolean
) {
    val color: Color get() = hexColor(colorHex)

    companion object {
        // Las 9 líneas de lineas.json + paleta del PLAN.
        val all: List<TrainLine> = listOf(
            TrainLine(1, "Sarmiento", "SA", "#B83280", true),
            TrainLine(5, "Mitre", "MI", "#1E7FD4", true),
            TrainLine(11, "Roca", "RO", "#16A34A", true),
            TrainLine(21, "Belgrano Sur", "BS", "#EAB308", true),
            TrainLine(31, "San Martín", "SM", "#E0632B", true),
            TrainLine(41, "Tren de la Costa", "TC", "#0D9488", true),
            TrainLine(61, "Belgrano Norte", "BN", "#8A94A6", false),
            TrainLine(71, "Urquiza", "UR", "#8A94A6", false),
            TrainLine(501, "Regionales", "RG", "#7C5CFC", true),
        )

        val unknown = TrainLine(-1, "Sin línea", "?", "#8A94A6", false)

        fun line(id: Int): TrainLine = all.firstOrNull { it.id == id } ?: unknown

        fun line(nombre: String?): TrainLine {
            if (nombre == null) return unknown
            val q = Text.normalize(nombre)
            return all.firstOrNull { Text.normalize(it.nombre) == q } ?: unknown
        }
    }
}
