package com.alandaitch.anden.ui.map

import android.Manifest
import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Typeface
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Apps
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.DirectionsBike
import androidx.compose.material.icons.filled.DirectionsBus
import androidx.compose.material.icons.filled.DirectionsSubway
import androidx.compose.material.icons.filled.MyLocation
import androidx.compose.material.icons.filled.NearMe
import androidx.compose.material.icons.filled.Train
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Remove
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.compose.ui.platform.LocalLifecycleOwner
import com.alandaitch.anden.data.catalog.ColectivoCatalog
import com.alandaitch.anden.data.catalog.StationCatalog
import com.alandaitch.anden.data.catalog.SubteCatalog
import com.alandaitch.anden.data.catalog.SubteStation
import com.alandaitch.anden.data.location.LocationProvider
import com.alandaitch.anden.data.model.Arrival
import com.alandaitch.anden.data.model.BusPosition
import com.alandaitch.anden.data.model.EcobiciStation
import com.alandaitch.anden.data.model.Station
import com.alandaitch.anden.data.model.TrainLine
import com.alandaitch.anden.data.net.ApiError
import com.alandaitch.anden.data.net.BaApi
import com.alandaitch.anden.data.net.SofseApi
import com.alandaitch.anden.ui.theme.Palette
import com.alandaitch.anden.util.Formatting
import com.alandaitch.anden.util.GeoPoint
import com.alandaitch.anden.util.MapsOpener
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.osmdroid.config.Configuration
import org.osmdroid.tileprovider.tilesource.TileSourceFactory
import org.osmdroid.views.MapView
import org.osmdroid.views.overlay.Marker
import java.time.Instant
import kotlin.math.ceil

// Capas del mapa multimodal.
private enum class MapLayer(val key: String, val label: String, val tint: Color) {
    TRENES("trenes", "Trenes", Color(0xFF1E7FD4)),
    SUBTE("subte", "Subte", Color(0xFF00A650)),
    BICI("bici", "Bici", Palette.onTime),
    COLECTIVOS("colectivos", "Colectivos", Color(0xFFE4572E))
}

// Estado de carga por capa.
private sealed class LayerState {
    object Idle : LayerState()
    object Loading : LayerState()
    object Ready : LayerState()
    data class Failed(val msg: String) : LayerState()
    data class Unavailable(val msg: String) : LayerState()
}

// Centro por defecto: Buenos Aires.
private val BA_CENTER = GeoPoint(-34.61, -58.40)
private const val BA_ZOOM = 12.0

/**
 * Mapa multimodal en vivo. Cuatro capas seleccionables sobre osmdroid.
 * Recibe lambdas de navegación; no instancia NavController.
 */
@Composable
fun MapScreen(
    onOpenTren: (Int) -> Unit,
    onOpenSubte: (String, String?) -> Unit
) {
    val context = LocalContext.current
    val dark = isSystemInDarkTheme()
    val scope = rememberCoroutineScope()

    // userAgentValue es obligatorio para osmdroid; setear antes de crear el MapView.
    remember { Configuration.getInstance().userAgentValue = context.packageName }

    // MapView único, retenido entre recomposiciones.
    val mapView = remember {
        MapView(context).apply {
            setTileSource(TileSourceFactory.MAPNIK)
            setMultiTouchControls(true)
            setUseDataConnection(true)
            zoomController.setVisibility(org.osmdroid.views.CustomZoomButtonsController.Visibility.NEVER)
            controller.setZoom(BA_ZOOM)
            controller.setCenter(org.osmdroid.util.GeoPoint(BA_CENTER.lat, BA_CENTER.lng))
        }
    }

    // Cache de íconos de marcador por (tipo + color). Evita recrear bitmaps.
    val iconCache = remember { HashMap<String, Drawable>() }

    // Capas activas persistidas en rememberSaveable.
    var activeCsv by rememberSaveable { mutableStateOf("trenes,subte") }
    val active: Set<MapLayer> = remember(activeCsv) {
        activeCsv.split(",").mapNotNull { key -> MapLayer.entries.firstOrNull { it.key == key.trim() } }.toSet()
    }

    // Datos por capa.
    val trains = remember { mutableStateListOf<Arrival>() }
    val trainStations = remember { mutableStateListOf<Station>() }
    val subtes = remember { mutableStateListOf<SubteStation>() }
    val bikes = remember { mutableStateListOf<EcobiciStation>() }
    val buses = remember { mutableStateListOf<BusPosition>() }

    val states = remember { mutableStateMapOf<MapLayer, LayerState>() }
    var lastUpdated by remember { mutableStateOf<Instant?>(null) }

    // Selecciones de panel.
    var selectedBus by remember { mutableStateOf<BusPosition?>(null) }
    var selectedBike by remember { mutableStateOf<EcobiciStation?>(null) }
    var selectedTrain by remember { mutableStateOf<Arrival?>(null) }

    val hasPermission by LocationProvider.shared.hasPermission.collectAsState()

    // Lee el centro actual del mapa.
    fun centerNow(): GeoPoint {
        val c = mapView.mapCenter
        return GeoPoint(c.latitude, c.longitude)
    }

    // Ciclo de vida del MapView.
    val lifecycleOwner = LocalLifecycleOwner.current
    DisposableEffect(lifecycleOwner) {
        val observer = LifecycleEventObserver { _, event ->
            when (event) {
                Lifecycle.Event.ON_RESUME -> mapView.onResume()
                Lifecycle.Event.ON_PAUSE -> mapView.onPause()
                else -> {}
            }
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose {
            lifecycleOwner.lifecycle.removeObserver(observer)
            mapView.onDetach()
        }
    }

    // Loops de datos. Se reinician al cambiar el set de capas activas.
    LaunchedEffect(active) {
        // Limpio los datos de las capas desactivadas.
        if (MapLayer.TRENES !in active) { trains.clear(); trainStations.clear() }
        if (MapLayer.SUBTE !in active) subtes.clear()
        if (MapLayer.BICI !in active) bikes.clear()
        if (MapLayer.COLECTIVOS !in active) buses.clear()

        coroutineScope {
            if (MapLayer.TRENES in active) launch {
                trainStations.clear()
                trainStations.addAll(StationCatalog.shared.nearest(centerNow(), 28).map { it.first })
                while (currentCoroutineContext().isActive) {
                    if (trains.isEmpty()) states[MapLayer.TRENES] = LayerState.Loading
                    val (res, err) = gatherTrains()
                    if (!currentCoroutineContext().isActive) break
                    trains.clear(); trains.addAll(res.sortedBy { it.secondsUntil })
                    trainStations.clear()
                    trainStations.addAll(StationCatalog.shared.nearest(centerNow(), 28).map { it.first })
                    states[MapLayer.TRENES] = when {
                        res.isNotEmpty() -> { lastUpdated = Instant.now(); LayerState.Ready }
                        err -> LayerState.Failed("No pude cargar los trenes en vivo.")
                        else -> LayerState.Ready
                    }
                    delay(25_000)
                }
            }

            if (MapLayer.SUBTE in active) launch {
                states[MapLayer.SUBTE] = LayerState.Loading
                val all = SubteCatalog.shared.all
                states[MapLayer.SUBTE] = if (all.isEmpty()) {
                    LayerState.Unavailable("No pude cargar las estaciones de subte.")
                } else {
                    subtes.clear(); subtes.addAll(all); LayerState.Ready
                }
            }

            if (MapLayer.BICI in active) launch {
                while (currentCoroutineContext().isActive) {
                    if (bikes.isEmpty()) states[MapLayer.BICI] = LayerState.Loading
                    try {
                        val res = BaApi.shared.ecobiciStations()
                        if (!currentCoroutineContext().isActive) break
                        bikes.clear(); bikes.addAll(res)
                        states[MapLayer.BICI] = if (res.isEmpty()) {
                            LayerState.Failed("Sin estaciones de EcoBici ahora.")
                        } else { lastUpdated = Instant.now(); LayerState.Ready }
                    } catch (e: ApiError.NoToken) {
                        states[MapLayer.BICI] = LayerState.Unavailable(e.message ?: "EcoBici no disponible.")
                        break
                    } catch (e: ApiError) {
                        if (bikes.isEmpty()) states[MapLayer.BICI] = LayerState.Failed(e.message ?: "No pude cargar EcoBici.")
                    }
                    delay(30_000)
                }
            }

            if (MapLayer.COLECTIVOS in active) launch {
                while (currentCoroutineContext().isActive) {
                    if (buses.isEmpty()) states[MapLayer.COLECTIVOS] = LayerState.Loading
                    try {
                        val res = BaApi.shared.colectivoPositions(near = centerNow(), maxCount = 350)
                        if (!currentCoroutineContext().isActive) break
                        buses.clear(); buses.addAll(res)
                        states[MapLayer.COLECTIVOS] = if (res.isEmpty()) {
                            LayerState.Failed("Sin colectivos con GPS ahora.")
                        } else { lastUpdated = Instant.now(); LayerState.Ready }
                    } catch (e: ApiError.NoToken) {
                        states[MapLayer.COLECTIVOS] = LayerState.Unavailable(e.message ?: "Colectivos no disponibles.")
                        break
                    } catch (e: ApiError.ServiceUnavailable) {
                        states[MapLayer.COLECTIVOS] = LayerState.Unavailable(e.message ?: "Servicio de colectivos no disponible.")
                    } catch (e: ApiError) {
                        if (buses.isEmpty()) states[MapLayer.COLECTIVOS] = LayerState.Failed(e.message ?: "No pude cargar los colectivos.")
                    }
                    delay(15_000)
                }
            }
        }
    }

    // Reconstruye los marcadores cuando cambian datos o capas.
    LaunchedEffect(
        trains.toList(), trainStations.toList(), subtes.toList(),
        bikes.toList(), buses.toList(), active
    ) {
        rebuildOverlays(
            mapView = mapView, context = context, iconCache = iconCache, active = active,
            trains = trains, trainStations = trainStations, subtes = subtes, bikes = bikes, buses = buses,
            onOpenTren = onOpenTren,
            onOpenSubte = onOpenSubte,
            onSelectBus = { selectedBus = it; selectedBike = null; selectedTrain = null },
            onSelectBike = { selectedBike = it; selectedBus = null; selectedTrain = null },
            onSelectTrain = { selectedTrain = it; selectedBus = null; selectedBike = null }
        )
    }

    // Permisos de ubicación.
    val permLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions()
    ) { _ ->
        LocationProvider.shared.refreshPermission()
        if (LocationProvider.shared.computePermission()) {
            LocationProvider.shared.start()
            LocationProvider.shared.point?.let {
                mapView.controller.animateTo(org.osmdroid.util.GeoPoint(it.lat, it.lng))
            }
        }
    }

    // UI.
    Box(modifier = Modifier.fillMaxSize().background(Palette.background(dark))) {
        AndroidView(factory = { mapView }, modifier = Modifier.fillMaxSize())

        // Barra de capas (arriba).
        LayerBar(
            active = active,
            stateOf = { states[it] },
            onToggle = { layer ->
                val set = active.toMutableSet()
                if (set.contains(layer)) set.remove(layer) else set.add(layer)
                activeCsv = MapLayer.entries.filter { set.contains(it) }.joinToString(",") { it.key }
            },
            onToggleAll = {
                val allOn = active.size == MapLayer.entries.size
                activeCsv = if (allOn) "" else MapLayer.entries.joinToString(",") { it.key }
            },
            dark = dark,
            modifier = Modifier.align(Alignment.TopCenter)
        )

        // Controles flotantes (abajo derecha).
        Column(
            modifier = Modifier.align(Alignment.BottomEnd).padding(end = 16.dp, bottom = 120.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            IconRoundButton(dark, Icons.Filled.MyLocation) {
                LocationProvider.shared.refreshPermission()
                if (LocationProvider.shared.computePermission()) {
                    LocationProvider.shared.start()
                    val p = LocationProvider.shared.point
                    if (p != null) mapView.controller.animateTo(org.osmdroid.util.GeoPoint(p.lat, p.lng))
                    else permLauncher.launch(arrayOf(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION))
                } else {
                    permLauncher.launch(arrayOf(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION))
                }
            }
            IconRoundButton(dark, Icons.Filled.Add) { mapView.controller.zoomIn() }
            IconRoundButton(dark, Icons.Filled.Remove) { mapView.controller.zoomOut() }
        }

        // Leyenda + estado (abajo).
        Legend(
            active = active,
            countOf = { layer ->
                when (layer) {
                    MapLayer.TRENES -> trains.size
                    MapLayer.SUBTE -> subtes.size
                    MapLayer.BICI -> bikes.size
                    MapLayer.COLECTIVOS -> buses.size
                }
            },
            statusText = statusText(active, states, lastUpdated),
            loading = active.any { states[it] is LayerState.Loading },
            dark = dark,
            modifier = Modifier.align(Alignment.BottomCenter)
        )

        // Panel de colectivo.
        selectedBus?.let { bus ->
            InfoPanel(dark = dark, onClose = { selectedBus = null }, modifier = Modifier.align(Alignment.BottomCenter)) {
                BusPanelContent(bus, dark, context)
            }
        }
        // Panel de EcoBici.
        selectedBike?.let { bike ->
            InfoPanel(dark = dark, onClose = { selectedBike = null }, modifier = Modifier.align(Alignment.BottomCenter)) {
                BikePanelContent(bike, dark, context)
            }
        }
        // Panel de tren en vivo.
        selectedTrain?.let { train ->
            InfoPanel(dark = dark, onClose = { selectedTrain = null }, modifier = Modifier.align(Alignment.BottomCenter)) {
                TrainPanelContent(train, dark, context)
            }
        }
    }
}

// ---------- Reconstrucción de overlays ----------

private fun rebuildOverlays(
    mapView: MapView,
    context: Context,
    iconCache: HashMap<String, Drawable>,
    active: Set<MapLayer>,
    trains: List<Arrival>,
    trainStations: List<Station>,
    subtes: List<SubteStation>,
    bikes: List<EcobiciStation>,
    buses: List<BusPosition>,
    onOpenTren: (Int) -> Unit,
    onOpenSubte: (String, String?) -> Unit,
    onSelectBus: (BusPosition) -> Unit,
    onSelectBike: (EcobiciStation) -> Unit,
    onSelectTrain: (Arrival) -> Unit
) {
    val density = context.resources.displayMetrics.density
    mapView.overlays.clear()

    fun addMarker(p: GeoPoint, icon: Drawable, onClick: () -> Unit) {
        val m = Marker(mapView)
        m.position = org.osmdroid.util.GeoPoint(p.lat, p.lng)
        m.setAnchor(Marker.ANCHOR_CENTER, Marker.ANCHOR_CENTER)
        m.icon = icon
        m.setInfoWindow(null)
        m.setOnMarkerClickListener { _, _ -> onClick(); true }
        mapView.overlays.add(m)
    }

    if (MapLayer.SUBTE in active) {
        subtes.forEach { st ->
            val icon = iconCache.getOrPut("subte-${st.line.routeId}") {
                letterDot(context, st.line.color.toArgb(), st.line.letra, 22f, 2f, density)
            }
            addMarker(st.coordinate, icon) { onOpenSubte(st.name, st.line.routeId) }
        }
    }

    if (MapLayer.BICI in active) {
        bikes.forEach { b ->
            val c = bikeColor(b).toArgb()
            val icon = iconCache.getOrPut("bike-$c") { dot(context, c, 14f, 1.5f, density) }
            addMarker(b.coordinate, icon) { onSelectBike(b) }
        }
    }

    if (MapLayer.COLECTIVOS in active) {
        buses.forEach { bus ->
            val c = busColor(bus).toArgb()
            val icon = iconCache.getOrPut("bus-$c") { dot(context, c, 11f, 1f, density) }
            addMarker(bus.coordinate, icon) { onSelectBus(bus) }
        }
    }

    if (MapLayer.TRENES in active) {
        trainStations.forEach { st ->
            val c = st.line.color.copy(alpha = 0.7f).toArgb()
            val icon = iconCache.getOrPut("station-$c") { dot(context, c, 12f, 1.5f, density) }
            addMarker(st.coordinate, icon) { onOpenTren(st.id) }
        }
        trains.forEach { a ->
            a.trainLocation?.let { loc ->
                val c = a.line.color.toArgb()
                val icon = iconCache.getOrPut("train-$c") { dot(context, c, 26f, 2.5f, density) }
                addMarker(loc, icon) { onSelectTrain(a) }
            }
        }
    }

    // Ubicación del usuario (punto azul), arriba de todo.
    com.alandaitch.anden.data.location.LocationProvider.shared.lastKnown()?.let { loc ->
        val icon = iconCache.getOrPut("me") { dot(context, 0xFF2D7DF6.toInt(), 13f, 3f, density) }
        addMarker(GeoPoint(loc.latitude, loc.longitude), icon) { }
    }

    mapView.invalidate()
}

// ---------- Colores derivados ----------

// Color de EcoBici por disponibilidad.
private fun bikeColor(b: EcobiciStation): Color = when {
    b.status != "IN_SERVICE" -> Palette.noData
    b.bikesTotal <= 0 -> Palette.majorDelay
    b.bikesTotal <= 2 -> Palette.minorDelay
    else -> Palette.onTime
}

// Color de colectivo: por línea si matchea el catálogo, gris si no.
private fun busColor(bus: BusPosition): Color {
    val rid = bus.routeId
    if (rid != null) ColectivoCatalog.shared.line(rid)?.let { return it.color }
    return Palette.noData
}

// ---------- Dibujo de íconos ----------

// Círculo relleno con anillo blanco.
private fun dot(context: Context, colorInt: Int, diamDp: Float, ringDp: Float, density: Float): Drawable {
    val d = diamDp * density
    val ring = ringDp * density
    val size = ceil(d + ring * 2).toInt().coerceAtLeast(2)
    val bmp = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
    val c = Canvas(bmp)
    val cx = size / 2f
    val p = Paint(Paint.ANTI_ALIAS_FLAG)
    if (ring > 0f) {
        p.color = 0xFFFFFFFF.toInt()
        c.drawCircle(cx, cx, d / 2f + ring, p)
    }
    p.color = colorInt
    c.drawCircle(cx, cx, d / 2f, p)
    return BitmapDrawable(context.resources, bmp)
}

// Círculo relleno con anillo blanco y letra centrada (subte).
private fun letterDot(context: Context, colorInt: Int, letter: String, diamDp: Float, ringDp: Float, density: Float): Drawable {
    val d = diamDp * density
    val ring = ringDp * density
    val size = ceil(d + ring * 2).toInt().coerceAtLeast(2)
    val bmp = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
    val c = Canvas(bmp)
    val cx = size / 2f
    val p = Paint(Paint.ANTI_ALIAS_FLAG)
    p.color = 0xFFFFFFFF.toInt()
    c.drawCircle(cx, cx, d / 2f + ring, p)
    p.color = colorInt
    c.drawCircle(cx, cx, d / 2f, p)
    val tp = Paint(Paint.ANTI_ALIAS_FLAG)
    tp.color = 0xFFFFFFFF.toInt()
    tp.textAlign = Paint.Align.CENTER
    tp.typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
    tp.textSize = d * 0.62f
    val fm = tp.fontMetrics
    val baseline = cx - (fm.ascent + fm.descent) / 2f
    c.drawText(letter, cx, baseline, tp)
    return BitmapDrawable(context.resources, bmp)
}

// ---------- Junta de trenes en vivo ----------

// Muestrea estaciones de las líneas cubiertas y junta arribos con GPS. Dedup por serviceId.
private suspend fun gatherTrains(): Pair<List<Arrival>, Boolean> = withContext(Dispatchers.IO) {
    val covered = TrainLine.all.filter { it.covered }
    val sample = mutableListOf<Station>()
    for (line in covered) {
        val stations = StationCatalog.shared.all
            .filter { it.gerenciaId == line.id && it.enRamalPublico && it.tieneArribosHoy }
            .sortedBy { it.distanciaObeliscoKm }
        sample += spread(stations, 3)
    }
    val seen = HashSet<Int>()
    val uniq = sample.filter { seen.add(it.id) }

    val collected = HashMap<String, Arrival>()
    var anyError = false

    for (chunk in uniq.chunked(5)) {
        if (!currentCoroutineContext().isActive) break
        val results = coroutineScope {
            chunk.map { st ->
                async { runCatching { SofseApi.shared.arrivals(st.id, limit = 6) } }
            }.awaitAll()
        }
        for (r in results) {
            r.onSuccess { list ->
                for (a in list) {
                    if (a.trainLocation != null) {
                        val key = a.serviceId ?: a.id
                        val ex = collected[key]
                        if (ex == null || a.secondsUntil < ex.secondsUntil) collected[key] = a
                    }
                }
            }.onFailure { anyError = true }
        }
    }
    Pair(collected.values.toList(), anyError)
}

// Toma N elementos repartidos a lo largo de la lista.
private fun spread(items: List<Station>, count: Int): List<Station> {
    if (items.size <= count) return items
    val step = items.size.toDouble() / count
    return (0 until count).map { items[(it * step).toInt()] }
}

// ---------- Texto de estado ----------

private fun statusText(active: Set<MapLayer>, states: Map<MapLayer, LayerState>, lastUpdated: Instant?): String {
    if (active.isEmpty()) return "Elegí una capa arriba."
    for (layer in MapLayer.entries) {
        if (layer !in active) continue
        when (val s = states[layer]) {
            is LayerState.Failed -> return s.msg
            is LayerState.Unavailable -> return s.msg
            else -> {}
        }
    }
    if (lastUpdated != null) return "Actualizado ${Formatting.clock(lastUpdated)} hs"
    return "Cargando red…"
}

// ---------- Componentes de UI ----------

@Composable
private fun LayerBar(
    active: Set<MapLayer>,
    stateOf: (MapLayer) -> LayerState?,
    onToggle: (MapLayer) -> Unit,
    onToggleAll: () -> Unit,
    dark: Boolean,
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .background(Palette.surface(dark).copy(alpha = 0.94f))
            .horizontalScroll(rememberScrollState())
            .padding(horizontal = 12.dp, vertical = 10.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        val allOn = active.size == MapLayer.entries.size
        Chip(
            label = "Todos",
            active = allOn,
            tint = Palette.brand,
            loading = false,
            dark = dark,
            icon = { Icon(Icons.Filled.Apps, null, tint = it, modifier = Modifier.size(15.dp)) },
            onClick = onToggleAll
        )
        MapLayer.entries.forEach { layer ->
            Chip(
                label = layer.label,
                active = layer in active,
                tint = layer.tint,
                loading = stateOf(layer) is LayerState.Loading,
                dark = dark,
                icon = { Icon(layerIcon(layer), null, tint = it, modifier = Modifier.size(15.dp)) },
                onClick = { onToggle(layer) }
            )
        }
    }
}

@Composable
private fun Chip(
    label: String,
    active: Boolean,
    tint: Color,
    loading: Boolean,
    dark: Boolean,
    icon: @Composable (Color) -> Unit,
    onClick: () -> Unit
) {
    val bg = if (active) tint else Palette.elevated(dark)
    val fg = if (active) Color.White else Palette.textPrimary(dark)
    Row(
        modifier = Modifier
            .clip(CircleShape)
            .background(bg)
            .clickableNoRipple(onClick)
            .padding(horizontal = 12.dp, vertical = 7.dp),
        horizontalArrangement = Arrangement.spacedBy(6.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        if (loading) {
            CircularProgressIndicator(color = fg, strokeWidth = 2.dp, modifier = Modifier.size(14.dp))
        } else {
            icon(fg)
        }
        Text(label, color = fg, fontSize = 13.sp, fontWeight = FontWeight.SemiBold)
    }
}

@Composable
private fun Legend(
    active: Set<MapLayer>,
    countOf: (MapLayer) -> Int,
    statusText: String,
    loading: Boolean,
    dark: Boolean,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier.fillMaxWidth().padding(start = 16.dp, end = 16.dp, bottom = 16.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        if (active.isNotEmpty()) {
            Row(
                modifier = Modifier
                    .clip(CircleShape)
                    .background(Palette.surface(dark).copy(alpha = 0.94f))
                    .padding(horizontal = 14.dp, vertical = 8.dp),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                MapLayer.entries.filter { it in active }.forEach { layer ->
                    Row(
                        horizontalArrangement = Arrangement.spacedBy(5.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Box(Modifier.size(9.dp).clip(CircleShape).background(layer.tint))
                        val n = countOf(layer)
                        Text(
                            if (n > 0) "${layer.label} $n" else layer.label,
                            color = Palette.textSecondary(dark),
                            fontSize = 11.sp,
                            fontWeight = FontWeight.SemiBold
                        )
                    }
                }
            }
        }
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clip(CircleShape)
                .background(Palette.surface(dark).copy(alpha = 0.94f))
                .padding(horizontal = 14.dp, vertical = 10.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            if (loading) {
                CircularProgressIndicator(color = Palette.textSecondary(dark), strokeWidth = 2.dp, modifier = Modifier.size(14.dp))
            }
            Text(statusText, color = Palette.textSecondary(dark), fontSize = 12.sp, fontWeight = FontWeight.Medium)
        }
    }
}

@Composable
private fun InfoPanel(
    dark: Boolean,
    onClose: () -> Unit,
    modifier: Modifier = Modifier,
    content: @Composable () -> Unit
) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .padding(12.dp)
            .clip(RoundedCornerShape(20.dp))
            .background(Palette.surface(dark))
            .padding(16.dp)
    ) {
        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End) {
            Icon(
                Icons.Filled.Close, "Cerrar",
                tint = Palette.textSecondary(dark),
                modifier = Modifier.size(22.dp).clip(CircleShape).clickableNoRipple(onClose)
            )
        }
        content()
    }
}

@Composable
private fun BusPanelContent(bus: BusPosition, dark: Boolean, context: Context) {
    val rid = bus.routeId
    val line = rid?.let { ColectivoCatalog.shared.line(it) }
    val title = if (line != null) "Línea ${line.shortName}" else "Línea s/d"
    val color = busColor(bus)
    PanelHeader(title, "Colectivo en vivo", color, dark)
    Spacer(Modifier.height(14.dp))
    Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        StatBox(bus.interno ?: "s/d", "interno", dark, Modifier.weight(1f))
        StatBox(bus.patente ?: "s/d", "patente", dark, Modifier.weight(1f))
    }
    Spacer(Modifier.height(14.dp))
    ActionButton("Cómo llego") { MapsOpener.transit(context, bus.coordinate, title) }
}

@Composable
private fun BikePanelContent(bike: EcobiciStation, dark: Boolean, context: Context) {
    val inService = bike.status == "IN_SERVICE"
    PanelHeader(
        bike.displayName,
        if (inService) "En servicio" else "Fuera de servicio",
        bikeColor(bike), dark
    )
    Spacer(Modifier.height(14.dp))
    Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        StatBox("${bike.bikesMechanical}", "mecánicas", dark, Modifier.weight(1f))
        StatBox("${bike.bikesEbike}", "eléctricas", dark, Modifier.weight(1f))
        StatBox("${bike.docksAvailable}", "anclajes", dark, Modifier.weight(1f))
    }
    Spacer(Modifier.height(14.dp))
    ActionButton("Ir a pie") { MapsOpener.walk(context, bike.coordinate, bike.displayName) }
}

@Composable
private fun TrainPanelContent(train: Arrival, dark: Boolean, context: Context) {
    PanelHeader(
        "${train.line.shortCodeOrName()} · ${train.destinationName}",
        train.delay.label,
        train.line.color, dark
    )
    Spacer(Modifier.height(14.dp))
    Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        StatBox(Formatting.etaText(train.secondsUntil), "llega en", dark, Modifier.weight(1f))
        StatBox(train.ramalName.ifBlank { "s/d" }, "ramal", dark, Modifier.weight(1f))
    }
    Spacer(Modifier.height(14.dp))
    train.trainLocation?.let { loc ->
        ActionButton("Cómo llego") { MapsOpener.transit(context, loc, train.destinationName) }
    }
}

private fun TrainLine.shortCodeOrName(): String = shortCode.ifBlank { nombre }

@Composable
private fun PanelHeader(title: String, subtitle: String, color: Color, dark: Boolean) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        Box(Modifier.size(34.dp).clip(CircleShape).background(color))
        Column {
            Text(title, color = Palette.textPrimary(dark), fontSize = 18.sp, fontWeight = FontWeight.Bold)
            Text(subtitle, color = Palette.textSecondary(dark), fontSize = 12.sp, fontWeight = FontWeight.Medium)
        }
    }
}

@Composable
private fun StatBox(value: String, label: String, dark: Boolean, modifier: Modifier = Modifier) {
    Column(
        modifier = modifier
            .clip(RoundedCornerShape(14.dp))
            .background(Palette.elevated(dark))
            .padding(vertical = 10.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(2.dp)
    ) {
        Text(value, color = Palette.textPrimary(dark), fontSize = 18.sp, fontWeight = FontWeight.Bold)
        Text(label, color = Palette.textSecondary(dark), fontSize = 11.sp, fontWeight = FontWeight.Medium)
    }
}

@Composable
private fun ActionButton(label: String, onClick: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(CircleShape)
            .background(Palette.brand)
            .clickableNoRipple(onClick)
            .padding(vertical = 12.dp),
        horizontalArrangement = Arrangement.Center,
        verticalAlignment = Alignment.CenterVertically,
        content = {
            Icon(Icons.Filled.NearMe, null, tint = Color.White, modifier = Modifier.size(16.dp))
            Spacer(Modifier.width(8.dp))
            Text(label, color = Color.White, fontSize = 15.sp, fontWeight = FontWeight.SemiBold)
        }
    )
}

@Composable
private fun IconRoundButton(dark: Boolean, icon: androidx.compose.ui.graphics.vector.ImageVector, onClick: () -> Unit) {
    Box(
        modifier = Modifier
            .size(44.dp)
            .clip(CircleShape)
            .background(Palette.surface(dark).copy(alpha = 0.96f))
            .clickableNoRipple(onClick),
        contentAlignment = Alignment.Center
    ) {
        Icon(icon, null, tint = Palette.textPrimary(dark), modifier = Modifier.size(20.dp))
    }
}

private fun layerIcon(layer: MapLayer): androidx.compose.ui.graphics.vector.ImageVector = when (layer) {
    MapLayer.TRENES -> Icons.Filled.Train
    MapLayer.SUBTE -> Icons.Filled.DirectionsSubway
    MapLayer.BICI -> Icons.Filled.DirectionsBike
    MapLayer.COLECTIVOS -> Icons.Filled.DirectionsBus
}

// Click para chips/botones custom.
private fun Modifier.clickableNoRipple(onClick: () -> Unit): Modifier =
    this.clickable(onClick = onClick)
