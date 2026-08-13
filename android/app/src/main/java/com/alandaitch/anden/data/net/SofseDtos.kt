package com.alandaitch.anden.data.net

import com.alandaitch.anden.data.model.ServiceAlert
import kotlinx.serialization.ExperimentalSerializationApi
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonNames
import kotlinx.serialization.json.JsonNull

// DTOs internos de decodificación. Cubren los dos esquemas de /arribos (vivo y horario)
// y las alertas embebidas en /infraestructura.

@Serializable
data class ArribosResponse(
    val timestamp: Long? = null,
    val results: List<ResultDTO>? = null,
    val total: Int? = null
)

@Serializable
data class ResultDTO(
    val arribo: ArriboDTO? = null,
    val servicio: ServicioDTO? = null
)

@Serializable
data class ArriboDTO(
    val orden: Int? = null,
    val nombre: String? = null,
    val idElemento: Int? = null,
    val segundos: Int? = null,
    val anden: AndenDTO? = null,
    val equipo: EquipoDTO? = null,
    val llegada: TimingDTO? = null,
    val salida: TimingDTO? = null
)

@Serializable
data class AndenDTO(val id: Int? = null, val nombre: String? = null)

@Serializable
data class EquipoDTO(
    val id: Int? = null,
    val nombre: String? = null,
    val esElectrico: Int? = null,
    val gpss: List<String>? = null
)

@Serializable
data class TimingDTO(
    val programada: String? = null,
    val estimada: String? = null,
    val real: String? = null,
    val latitud: Double? = null,
    val longitud: Double? = null
)

@Serializable
data class LocationDTO(val lat: Double? = null, val long: Double? = null)

@Serializable
data class GerenciaRefDTO(val id: Int? = null, val nombre: String? = null)

@Serializable
data class EstadoDTO(val id: Int? = null, val nombre: String? = null)

@Serializable
data class DesdeDTO(val estado: EstadoDTO? = null)

// Cabecera de ramal. Maneja nombreCorto (vivo) y nombre_corto (horario) vía JsonNames.
@OptIn(ExperimentalSerializationApi::class)
@Serializable
data class CabeceraDTO(
    val id: Int? = null,
    val nombre: String? = null,
    @JsonNames("nombreCorto", "nombre_corto") val nombreCorto: String? = null
) {
    val display: String get() = nombreCorto ?: nombre ?: ""
}

@Serializable
data class RamalRefDTO(
    val id: Int? = null,
    val nombre: String? = null,
    val siglas: String? = null,
    val tolerancia: Int? = null,
    val cabeceraInicial: CabeceraDTO? = null,
    val cabeceraFinal: CabeceraDTO? = null
)

@Serializable
data class EstacionRecorridoDTO(
    val idElemento: Int? = null,
    val nombre: String? = null,
    val orden: Int? = null,
    val anden: AndenDTO? = null,
    val llegada: TimingDTO? = null,
    val salida: TimingDTO? = null
)

@Serializable
data class ServicioDTO(
    val id: String? = null,
    val numero: Int? = null,
    val sentido: Int? = null,
    val cancelacion: JsonElement? = null,
    val location: LocationDTO? = null,
    val gerencia: GerenciaRefDTO? = null,
    val ramal: RamalRefDTO? = null,
    val desde: DesdeDTO? = null,
    val estaciones: List<EstacionRecorridoDTO>? = null
) {
    // Cancelación presente = cualquier valor no nulo (ni JSON null).
    val isCancelled: Boolean get() = cancelacion != null && cancelacion !is JsonNull
}

// --- Alertas ---

@Serializable
data class GerenciaAlertDTO(val id: Int? = null, val alerta: List<AlertaDTO>? = null)

@Serializable
data class RamalAlertDTO(val id: Int? = null, val alerta: AlertaDTO? = null)

@Serializable
data class AlertaDTO(
    val id: Int? = null,
    val linea_id: Int? = null,
    val ramal_id: Int? = null,
    val causa_gtfs: String? = null,
    val efecto_gtfs: String? = null,
    val contenido: String? = null,
    val criticidad_orden: Int? = null,
    val vigencia_desde: String? = null,
    val vigencia_hasta: String? = null
)

// Convierte el DTO de alerta al modelo de dominio.
fun AlertaDTO.toServiceAlert(): ServiceAlert = ServiceAlert(
    id = id ?: kotlin.math.abs((contenido ?: java.util.UUID.randomUUID().toString()).hashCode()),
    lineId = linea_id,
    ramalId = ramal_id,
    causeGTFS = causa_gtfs ?: "OTHER_CAUSE",
    effectGTFS = efecto_gtfs ?: "OTHER_EFFECT",
    content = contenido ?: "",
    criticality = criticidad_orden ?: 99,
    validFrom = SofseDate.alert(vigencia_desde),
    validUntil = SofseDate.alert(vigencia_hasta)
)
