package com.alandaitch.anden.util

import com.alandaitch.anden.data.model.DelayStatus
import java.time.Instant
import kotlin.math.roundToInt

// Cálculo de demora. demora = estimada - programada. Ver api-reference sección 7.
object DelayLogic {
    const val DEFAULT_TOLERANCE = 359
    const val EARLY_THRESHOLD = 60 // segundos adelantado para marcar "early"

    fun status(
        scheduled: Instant?,
        estimated: Instant?,
        secondsUntil: Int = 0,
        serverNow: Instant? = null,
        tolerance: Int = DEFAULT_TOLERANCE,
        isCancelled: Boolean = false
    ): DelayStatus {
        if (isCancelled) return DelayStatus.Cancelled
        // Sin estimada no hay predicción en vivo. No asumir 0. Ver sección 7.
        if (estimated == null || scheduled == null) return DelayStatus.NoData
        val delay = ((estimated.toEpochMilli() - scheduled.toEpochMilli()).toDouble() / 1000.0).roundToInt()
        if (delay < -EARLY_THRESHOLD) return DelayStatus.Early(-delay)
        if (delay <= tolerance) return DelayStatus.OnTime
        if (delay <= tolerance * 2) return DelayStatus.Minor(delay)
        return DelayStatus.Major(delay)
    }
}
