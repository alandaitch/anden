package com.alandaitch.anden.util

import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.sin
import kotlin.math.sqrt

// Coordenada geográfica. Reemplazo de CLLocationCoordinate2D.
data class GeoPoint(val lat: Double, val lng: Double)

object Geo {
    private const val EARTH_RADIUS_M = 6_371_000.0

    // Distancia haversine en metros. Equivale a CLLocation.distance(from:).
    fun distanceMeters(a: GeoPoint, b: GeoPoint): Double {
        val dLat = Math.toRadians(b.lat - a.lat)
        val dLng = Math.toRadians(b.lng - a.lng)
        val lat1 = Math.toRadians(a.lat)
        val lat2 = Math.toRadians(b.lat)
        val h = sin(dLat / 2) * sin(dLat / 2) +
            cos(lat1) * cos(lat2) * sin(dLng / 2) * sin(dLng / 2)
        return 2 * EARTH_RADIUS_M * atan2(sqrt(h), sqrt(1 - h))
    }
}
