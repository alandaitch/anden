package com.alandaitch.anden.data.model

import java.time.Instant

// Alerta de servicio. Viaja embebida en /infraestructura/gerencias y /infraestructura/ramales.
data class ServiceAlert(
    val id: Int,
    val lineId: Int?,
    val ramalId: Int?,
    val causeGTFS: String,
    val effectGTFS: String,
    val content: String,
    val criticality: Int,
    val validFrom: Instant?,
    val validUntil: Instant?
) {
    // Nombre de ícono Material. El efecto manda sobre la causa.
    // Los agentes de UI mapean estos nombres a íconos concretos.
    val iconName: String
        get() {
            when (effectGTFS) {
                "NO_SERVICE" -> return "block"
                "SIGNIFICANT_DELAYS" -> return "schedule_alert"
                "REDUCED_SERVICE" -> return "train_tunnel"
                "DETOUR" -> return "alt_route"
                "STOP_MOVED" -> return "wrong_location"
            }
            return when (causeGTFS) {
                "ACCIDENT" -> "warning"
                "TECHNICAL_PROBLEM" -> "build"
                "STRIKE" -> "person_off"
                "MAINTENANCE" -> "handyman"
                "WEATHER" -> "thunderstorm"
                else -> "error"
            }
        }
}
