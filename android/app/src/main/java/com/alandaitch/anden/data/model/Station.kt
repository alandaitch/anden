package com.alandaitch.anden.data.model

import com.alandaitch.anden.util.GeoPoint
import kotlinx.serialization.Serializable

// Estación del catálogo embebido (estaciones.json).
// Campos extra del JSON se ignoran (ignoreUnknownKeys en el decoder).
@Serializable
data class Station(
    val id: Int,
    val nombre: String,
    val lat: Double,
    val lng: Double,
    val linea: String? = null,
    val ramales: List<Int> = emptyList(),
    val ramalesOperativos: List<Int> = emptyList(),
    val gerenciaId: Int? = null,
    val visibleEnApp: Boolean = false,
    val enRamalPublico: Boolean = false,
    val tieneArribosHoy: Boolean = false,
    val distanciaObeliscoKm: Double = 0.0,
    val andenes: Int? = null
) {
    val coordinate: GeoPoint get() = GeoPoint(lat, lng)

    val line: TrainLine
        get() = if (gerenciaId != null) TrainLine.line(gerenciaId) else TrainLine.line(linea)
}
