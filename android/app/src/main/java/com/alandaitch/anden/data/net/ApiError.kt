package com.alandaitch.anden.data.net

import java.time.Instant
import java.time.LocalDateTime
import java.time.ZoneId
import java.time.format.DateTimeFormatter

// Error de red/API. Réplica de APIError de iOS.
sealed class ApiError(message: String) : Exception(message) {
    object InvalidUrl : ApiError("URL inválida.")
    data class Http(val status: Int, val body: String?) : ApiError("Error de red ($status).")
    object Unauthorized : ApiError("Autenticación fallida.")
    data class Decoding(val error: Throwable) : ApiError("No se pudo leer la respuesta.")
    data class Transport(val error: Throwable) : ApiError("Sin conexión con el servidor.")
    object NoToken : ApiError("No hay token disponible.")
    data class ServiceUnavailable(val info: String?) : ApiError(info ?: "Servicio no disponible.")
}

// Parseo de fechas de la API. Dos esquemas: ISO UTC (con Z) y alertas (local, sin Z).
object SofseDate {
    private val baZone: ZoneId = ZoneId.of("America/Argentina/Buenos_Aires")
    private val alertFormatter: DateTimeFormatter =
        DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss")

    // ISO UTC con sufijo Z. Ej "2026-08-12T20:53:30.000Z".
    fun iso(s: String?): Instant? {
        if (s.isNullOrEmpty()) return null
        return try {
            Instant.parse(s)
        } catch (_: Exception) {
            null
        }
    }

    // Fecha de alerta: "YYYY-MM-DD HH:MM:SS" en hora local, sin Z.
    fun alert(s: String?): Instant? {
        if (s.isNullOrEmpty()) return null
        return try {
            val ldt = LocalDateTime.parse(s, alertFormatter)
            ldt.atZone(baZone).toInstant()
        } catch (_: Exception) {
            null
        }
    }
}
