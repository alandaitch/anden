package com.alandaitch.anden.ui.map

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import com.alandaitch.anden.util.Geo
import com.alandaitch.anden.util.GeoPoint
import org.osmdroid.config.Configuration
import org.osmdroid.tileprovider.tilesource.TileSourceFactory
import org.osmdroid.util.BoundingBox
import org.osmdroid.views.CustomZoomButtonsController
import org.osmdroid.views.MapView
import org.osmdroid.views.overlay.Marker
import kotlin.math.ceil

private const val STOP_ARGB = 0xFF242C4F.toInt() // brand

// Mini-mapa "tu parada + el vehículo viniendo". Solo visual (no interactivo).
// Se auto-encuadra para mostrar la parada y, si hay GPS, el coche que se acerca.
@Composable
fun MiniMapView(
    stop: GeoPoint,
    vehicle: GeoPoint?,
    vehicleColorArgb: Int,
    modifier: Modifier = Modifier,
    heightDp: Int = 150,
) {
    val context = LocalContext.current
    remember { Configuration.getInstance().userAgentValue = context.packageName }
    val density = context.resources.displayMetrics.density

    val mapView = remember {
        MapView(context).apply {
            setTileSource(TileSourceFactory.MAPNIK)
            setMultiTouchControls(false)
            setUseDataConnection(true)
            zoomController.setVisibility(CustomZoomButtonsController.Visibility.NEVER)
            isHorizontalMapRepetitionEnabled = false
            isVerticalMapRepetitionEnabled = false
            // No interactivo: es un vistazo.
            setOnTouchListener { _, _ -> true }
            controller.setZoom(15.5)
            controller.setCenter(org.osmdroid.util.GeoPoint(stop.lat, stop.lng))
        }
    }

    val owner = LocalLifecycleOwner.current
    DisposableEffect(owner) {
        val obs = LifecycleEventObserver { _, event ->
            when (event) {
                Lifecycle.Event.ON_RESUME -> mapView.onResume()
                Lifecycle.Event.ON_PAUSE -> mapView.onPause()
                else -> {}
            }
        }
        owner.lifecycle.addObserver(obs)
        onDispose {
            owner.lifecycle.removeObserver(obs)
            mapView.onDetach()
        }
    }

    AndroidView(
        factory = { mapView },
        modifier = modifier.fillMaxWidth().height(heightDp.dp),
        update = { mv ->
            mv.overlays.clear()
            addDot(mv, stop, STOP_ARGB, 13f, 2.5f, density)
            if (vehicle != null) addDot(mv, vehicle, vehicleColorArgb, 17f, 3f, density)
            mv.invalidate()
            mv.post {
                if (vehicle != null && Geo.distanceMeters(stop, vehicle) > 120.0) {
                    val box = BoundingBox.fromGeoPoints(
                        listOf(
                            org.osmdroid.util.GeoPoint(stop.lat, stop.lng),
                            org.osmdroid.util.GeoPoint(vehicle.lat, vehicle.lng),
                        )
                    ).increaseByScale(1.7f)
                    runCatching { mv.zoomToBoundingBox(box, false, 48) }
                } else {
                    mv.controller.setZoom(16.0)
                    mv.controller.setCenter(org.osmdroid.util.GeoPoint(stop.lat, stop.lng))
                }
            }
        },
    )
}

// Marcador circular relleno con anillo blanco (mismo estilo que el mapa grande).
private fun addDot(mv: MapView, p: GeoPoint, colorInt: Int, diamDp: Float, ringDp: Float, density: Float) {
    val m = Marker(mv)
    m.position = org.osmdroid.util.GeoPoint(p.lat, p.lng)
    m.setAnchor(Marker.ANCHOR_CENTER, Marker.ANCHOR_CENTER)
    m.icon = dot(colorInt, diamDp, ringDp, density)
    m.setInfoWindow(null)
    m.setOnMarkerClickListener { _, _ -> true }
    mv.overlays.add(m)
}

private fun dot(colorInt: Int, diamDp: Float, ringDp: Float, density: Float): Drawable {
    val d = diamDp * density
    val ring = ringDp * density
    val size = ceil(d + ring * 2).toInt().coerceAtLeast(2)
    val bmp = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
    val c = Canvas(bmp)
    val cx = size / 2f
    val paint = Paint(Paint.ANTI_ALIAS_FLAG)
    paint.color = 0xFFFFFFFF.toInt()
    c.drawCircle(cx, cx, d / 2f + ring, paint)
    paint.color = colorInt
    c.drawCircle(cx, cx, d / 2f, paint)
    return BitmapDrawable(null, bmp)
}
