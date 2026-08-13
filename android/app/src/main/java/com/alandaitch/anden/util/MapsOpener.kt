package com.alandaitch.anden.util

import android.content.Context
import android.content.Intent
import android.net.Uri

// Abre una app de mapas con indicaciones hacia una coordenada.
// Prefiere google.navigation (Google Maps); si no hay, cae a la web maps.google.com.
object MapsOpener {

    // Indicaciones a pie.
    fun walk(context: Context, to: GeoPoint, name: String) {
        open(context, to, name, "walking")
    }

    // Indicaciones en transporte público.
    fun transit(context: Context, to: GeoPoint, name: String) {
        open(context, to, name, "transit")
    }

    private fun open(context: Context, to: GeoPoint, name: String, mode: String) {
        // google.navigation soporta modos: w=walk, d=drive, b=bike, r=transit.
        val navMode = when (mode) {
            "walking" -> "w"
            "transit" -> "r"
            else -> "d"
        }
        val navUri = Uri.parse("google.navigation:q=${to.lat},${to.lng}&mode=$navMode")
        val navIntent = Intent(Intent.ACTION_VIEW, navUri).apply {
            setPackage("com.google.android.apps.maps")
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        if (navIntent.resolveActivity(context.packageManager) != null) {
            context.startActivity(navIntent)
            return
        }
        // Fallback web con travelmode y destino.
        val label = Uri.encode(name)
        val webUri = Uri.parse(
            "https://www.google.com/maps/dir/?api=1" +
                "&destination=${to.lat},${to.lng}" +
                "&destination_place_id=$label" +
                "&travelmode=$mode"
        )
        val webIntent = Intent(Intent.ACTION_VIEW, webUri).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        context.startActivity(webIntent)
    }
}
