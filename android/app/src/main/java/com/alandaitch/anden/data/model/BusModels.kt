package com.alandaitch.anden.data.model

import androidx.compose.ui.graphics.Color
import com.alandaitch.anden.ui.theme.hexColor
import com.alandaitch.anden.util.GeoPoint
import java.time.Instant

// Posición GPS en vivo de un colectivo (del feed vehiclePositions).
data class BusPosition(
    val id: String,
    val coordinate: GeoPoint,
    val routeId: String?,
    val bearing: Double?,
    val interno: String?,
    val patente: String?
)

// Parada de colectivo del catálogo (colectivos-paradas.json).
data class BusStop(
    val code: String,
    val name: String,
    val lat: Double,
    val lng: Double
) {
    val id: String get() = code
    val coordinate: GeoPoint get() = GeoPoint(lat, lng)
}

// Arribo pronosticado en una parada (forecastGTFS por StopCode).
data class BusArrival(
    val lineName: String,
    val destino: String?,
    val eta: Instant,
    val secondsUntil: Int,
    val delay: DelayStatus
) {
    val id: String get() = "$lineName-${eta.epochSecond}-${destino ?: ""}"
}

// Línea de colectivo del catálogo (colectivos-lineas.json).
// No hay color oficial: se deriva uno determinístico del shortName.
data class BusLine(
    val routeId: String,
    val shortName: String,
    val longName: String
) {
    val id: String get() = routeId
    val color: Color get() = color(shortName)

    companion object {
        // Paleta propia. 12 tonos legibles en fondo claro y oscuro.
        private val palette: List<String> = listOf(
            "#E4572E", "#F3A712", "#2E9E5B", "#1E7FD4", "#7B4FB5", "#D6336C",
            "#0FA3A3", "#B5651D", "#5B7A2E", "#3D5AA9", "#C2417B", "#557A95"
        )

        // Hash determinístico (djb2) del shortName -> índice de paleta.
        // Usa Long (64-bit) para replicar el Int de 64 bits de Swift.
        fun color(shortName: String): Color {
            var hash = 5381L
            for (ch in shortName) {
                hash = hash * 33 + ch.code.toLong()
            }
            val size = palette.size.toLong()
            val idx = (((hash % size) + size) % size).toInt()
            return hexColor(palette[idx])
        }
    }
}
