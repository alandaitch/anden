package com.alandaitch.anden.data.model

import androidx.compose.ui.graphics.Color
import com.alandaitch.anden.ui.theme.Palette
import kotlin.math.abs
import kotlin.math.roundToInt

// Estado de demora de un arribo. minor vs major se decide con la tolerancia del ramal.
sealed class DelayStatus {
    object OnTime : DelayStatus()
    data class Early(val seconds: Int) : DelayStatus()
    data class Minor(val seconds: Int) : DelayStatus()
    data class Major(val seconds: Int) : DelayStatus()
    object NoData : DelayStatus()
    object Cancelled : DelayStatus()

    val label: String
        get() = when (this) {
            is OnTime -> "En horario"
            is Early -> "-${minutes(seconds)} min"
            is Minor -> "+${minutes(seconds)} min"
            is Major -> "+${minutes(seconds)} min"
            is NoData -> "Sin datos"
            is Cancelled -> "Cancelado"
        }

    val shortLabel: String
        get() = when (this) {
            is OnTime -> "En hora"
            is Early -> "-${minutes(seconds)}"
            is Minor -> "+${minutes(seconds)}"
            is Major -> "+${minutes(seconds)}"
            is NoData -> "S/D"
            is Cancelled -> "Canc."
        }

    val color: Color
        get() = when (this) {
            is OnTime, is Early -> Palette.onTime
            is Minor -> Palette.minorDelay
            is Major, is Cancelled -> Palette.majorDelay
            is NoData -> Palette.noData
        }

    // Segundos de demora con signo (negativo = adelantado). null si no hay dato.
    val delaySeconds: Int?
        get() = when (this) {
            is Early -> -seconds
            is Minor -> seconds
            is Major -> seconds
            is OnTime -> 0
            is NoData, is Cancelled -> null
        }

    companion object {
        private fun minutes(seconds: Int): Int = (abs(seconds).toDouble() / 60.0).roundToInt()
    }
}
