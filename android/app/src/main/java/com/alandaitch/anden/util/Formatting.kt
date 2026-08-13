package com.alandaitch.anden.util

import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale
import kotlin.math.roundToInt

// Helpers de formateo para la UI, es-AR.
object Formatting {
    private val baZone: ZoneId = ZoneId.of("America/Argentina/Buenos_Aires")
    private val clockFormatter: DateTimeFormatter =
        DateTimeFormatter.ofPattern("HH:mm", Locale("es", "AR")).withZone(baZone)

    // "ahora" / "llegando" / "en X min".
    fun etaText(secondsUntil: Int): String {
        if (secondsUntil <= 30) return "ahora"
        if (secondsUntil < 90) return "llegando"
        val mins = (secondsUntil.toDouble() / 60.0).roundToInt()
        return "en $mins min"
    }

    // Minutos enteros hasta el arribo, piso en 0.
    fun minutesUntil(secondsUntil: Int): Int =
        maxOf(0, Math.floor(secondsUntil.toDouble() / 60.0).toInt())

    // "a 320 m" / "a 1,2 km" (decimal con coma).
    fun distanceText(meters: Double): String {
        if (meters < 1000) {
            return "a ${meters.roundToInt()} m"
        }
        val km = meters / 1000
        val s = String.format(Locale.US, "%.1f", km).replace(".", ",")
        return "a $s km"
    }

    // Hora local de Buenos Aires, formato HH:mm.
    fun clock(instant: Instant?): String {
        if (instant == null) return "--:--"
        return clockFormatter.format(instant)
    }
}
