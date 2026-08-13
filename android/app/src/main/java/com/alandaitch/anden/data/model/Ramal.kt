package com.alandaitch.anden.data.model

import com.alandaitch.anden.util.DelayLogic
import kotlinx.serialization.Serializable

// Ramal de una línea (lineas.json -> ramales).
@Serializable
data class Ramal(
    val id: Int,
    val nombre: String? = null,
    val siglas: String? = null,
    val cabeceras: List<String> = emptyList(),
    val cabeceraInicialId: Int? = null,
    val cabeceraFinalId: Int? = null,
    val estaciones: Int? = null,
    val esElectrico: Boolean = false,
    val operativo: Boolean = false,
    val toleranciaPuntualidadSegundos: Int? = null,
    val tipoId: Int? = null
) {
    val tolerancia: Int get() = toleranciaPuntualidadSegundos ?: DelayLogic.DEFAULT_TOLERANCE
    val displayName: String get() = nombre ?: cabeceras.joinToString("-")
}
