package com.alandaitch.anden.data.model

import com.alandaitch.anden.util.DelayLogic
import java.time.Instant

// Tolerancia de puntualidad del subte (segundos). Más chica que la del tren.
const val SUBTE_TOLERANCE = 120

// Una parada dentro del recorrido de un tren de subte.
data class SubteStop(
    val stopId: String,
    val name: String,
    val eta: Instant,
    val delaySeconds: Int,
    val delay: DelayStatus
) {
    val id: String get() = stopId

    companion object {
        // Construye calculando el estado de demora con DelayLogic.
        // scheduled = eta - delaySeconds; estimated = eta.
        fun create(
            stopId: String,
            name: String,
            eta: Instant,
            delaySeconds: Int,
            tolerance: Int = SUBTE_TOLERANCE
        ): SubteStop {
            val scheduled = eta.minusSeconds(delaySeconds.toLong())
            val delay = DelayLogic.status(scheduled = scheduled, estimated = eta, tolerance = tolerance)
            return SubteStop(stopId, name, eta, delaySeconds, delay)
        }
    }
}

// Un tren de subte (viaje) con sus paradas restantes.
data class SubteTrip(
    val line: SubteLine,
    val direction: Int,      // Direction_ID (0/1)
    val stops: List<SubteStop>
)

// Arribo para el tablero de una estación.
data class SubteArrival(
    val line: SubteLine,
    val direction: Int,
    val destinationName: String,
    val eta: Instant,
    val secondsUntil: Int,
    val delay: DelayStatus
) {
    val id: String get() = "${line.routeId}-$direction-${eta.epochSecond}-$destinationName"
}

// Alerta de estado de servicio del subte.
data class SubteAlertItem(
    val line: SubteLine,
    val text: String,
    val effect: Int         // GTFS-rt: 1 NO_SERVICE, 2 REDUCED, 4 DELAYS, 6 DETOUR, 7 OTHER, 8 STOP_MOVED
) {
    val id: String get() = "${line.routeId}-$effect-${text.hashCode()}"

    // Nombre de ícono Material según el efecto GTFS-rt.
    val iconName: String
        get() = when (effect) {
            1 -> "block"                 // NO_SERVICE
            2 -> "train_tunnel"          // REDUCED_SERVICE
            4 -> "schedule_alert"        // SIGNIFICANT_DELAYS
            6 -> "alt_route"             // DETOUR
            8 -> "wrong_location"        // STOP_MOVED
            else -> "error"              // OTHER_EFFECT
        }

    // Orden de severidad para ordenar alertas. Menor = más grave.
    val severity: Int
        get() = when (effect) {
            1 -> 0    // NO_SERVICE
            4 -> 1    // SIGNIFICANT_DELAYS
            2 -> 2    // REDUCED_SERVICE
            6 -> 3    // DETOUR
            8 -> 4    // STOP_MOVED
            else -> 5 // OTHER
        }
}
