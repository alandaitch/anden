package com.alandaitch.anden.data.model

import java.time.Instant

// Parada del recorrido de un servicio.
data class RouteStop(
    val stationId: Int,
    val name: String,
    val order: Int,
    val scheduled: Instant?,
    val estimated: Instant?,
    val trackName: String?,
    val hasPassed: Boolean
) {
    val id: Int get() = order
}
