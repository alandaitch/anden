package com.alandaitch.anden.data.model

import com.alandaitch.anden.util.GeoPoint
import java.time.Instant

// Línea de colectivo cercana con "cuándo llega" (API OneBusAway de cuandosubo).
// Cada ítem = una (línea + destino) con su próximo arribo futuro y la parada.
data class BusLineNearby(
    val lineShort: String,
    val headsign: String,
    val eta: Instant?,
    val secondsUntil: Int,
    val isLive: Boolean,
    val stopName: String,
    val stopId: String,
    val stopLat: Double,
    val stopLng: Double
) {
    val coordinate: GeoPoint get() = GeoPoint(stopLat, stopLng)
}

// Arribo de colectivo en una parada (OneBusAway arrivals-and-departures-for-stop).
data class BusArrivalOba(
    val lineShort: String,
    val headsign: String,
    val eta: Instant?,
    val secondsUntil: Int,
    val isLive: Boolean
) {
    val id: String get() = "$lineShort-$headsign-${eta?.epochSecond ?: 0}"
}
