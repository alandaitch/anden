package com.alandaitch.anden.data.model

import com.alandaitch.anden.util.GeoPoint
import java.time.Instant

// Estación de EcoBici (GBFS). Une stationInformation + stationStatus.
data class EcobiciStation(
    val id: String,
    val name: String,
    val lat: Double,
    val lng: Double,
    val capacity: Int,
    val bikesMechanical: Int,
    val bikesEbike: Int,
    val bikesTotal: Int,
    val docksAvailable: Int,
    val status: String,
    val lastReported: Instant
) {
    val coordinate: GeoPoint get() = GeoPoint(lat, lng)

    // Nombre sin el prefijo numérico. "002 - Retiro I" -> "Retiro I".
    val displayName: String
        get() {
            val parts = name.split("-", limit = 2)
            if (parts.size == 2 && parts[0].trim().toIntOrNull() != null) {
                return parts[1].trim()
            }
            return name.trim()
        }
}
