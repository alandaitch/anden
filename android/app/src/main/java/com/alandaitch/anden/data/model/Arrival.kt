package com.alandaitch.anden.data.model

import com.alandaitch.anden.util.GeoPoint
import java.time.Instant

// Modelo de dominio de un arribo para la UI. No es el JSON crudo.
data class Arrival(
    val id: String,
    val serviceId: String?,
    val lineId: Int,
    val line: TrainLine,
    val ramalName: String,
    val destinationName: String,
    val originName: String,
    val trackName: String?,
    val scheduled: Instant?,
    val estimated: Instant?,
    val secondsUntil: Int,
    val delay: DelayStatus,
    val trainLocation: GeoPoint?,
    val equipmentName: String?,
    val isElectric: Boolean,
    val isCancelled: Boolean,
    val direction: Int,
    val stateName: String?,
    val route: List<RouteStop>
)
