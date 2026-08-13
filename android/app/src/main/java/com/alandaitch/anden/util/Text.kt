package com.alandaitch.anden.util

import java.text.Normalizer

// Normalización de texto para búsquedas y matcheo de nombres.
// Réplica de folding(diacriticInsensitive+caseInsensitive) de iOS.
object Text {
    // Quita acentos, pasa a minúscula, recorta espacios.
    fun normalize(s: String): String {
        val decomposed = Normalizer.normalize(s, Normalizer.Form.NFD)
        val stripped = decomposed.replace(Regex("\\p{Mn}+"), "")
        return stripped.lowercase().trim()
    }
}
