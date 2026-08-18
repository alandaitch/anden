package com.alandaitch.anden.ui.ecobici

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Bolt
import androidx.compose.material.icons.rounded.Star
import androidx.compose.material.icons.rounded.StarBorder
import androidx.compose.material.icons.rounded.DirectionsBike
import androidx.compose.material.icons.rounded.MyLocation
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.collectAsState
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.alandaitch.anden.data.location.LocationProvider
import com.alandaitch.anden.data.model.EcobiciStation
import com.alandaitch.anden.data.net.ApiError
import com.alandaitch.anden.data.net.BaApi
import com.alandaitch.anden.ui.components.EmptyState
import com.alandaitch.anden.ui.components.ErrorState
import com.alandaitch.anden.ui.components.GoButton
import com.alandaitch.anden.ui.components.LoadingState
import com.alandaitch.anden.ui.theme.Palette
import com.alandaitch.anden.ui.theme.hexColor
import com.alandaitch.anden.util.Formatting
import com.alandaitch.anden.util.Geo
import com.alandaitch.anden.util.GeoPoint
import com.alandaitch.anden.util.MapsOpener
import kotlinx.coroutines.delay
import java.time.Instant

private sealed interface EcobiciPhase {
    data object Loading : EcobiciPhase
    data object Ready : EcobiciPhase
    data object Empty : EcobiciPhase
    data class Error(val message: String) : EcobiciPhase
}

// Estaciones de EcoBici ordenadas por cercanía. Auto-refresh 30s.
@Composable
fun EcobiciScreen() {
    val dark = isSystemInDarkTheme()
    val context = LocalContext.current
    val provider = LocationProvider.shared
    val hasPermission by provider.hasPermission.collectAsState()
    val liveLocation by provider.location.collectAsState()

    var stations by remember { mutableStateOf<List<EcobiciStation>>(emptyList()) }
    val favs by com.alandaitch.anden.data.store.FavoritesStore.shared.itemsFlow.collectAsState()
    var phase by remember { mutableStateOf<EcobiciPhase>(EcobiciPhase.Loading) }
    var lastUpdated by remember { mutableStateOf<Instant?>(null) }
    var reloadKey by remember { mutableIntStateOf(0) }

    val permissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions()
    ) { _ ->
        provider.refreshPermission()
        provider.start()
    }

    // Arranca ubicación si ya hay permiso.
    LaunchedEffect(Unit) {
        provider.refreshPermission()
        if (provider.computePermission()) provider.start()
    }

    // Carga + refresco cada 30s.
    LaunchedEffect(reloadKey) {
        if (stations.isEmpty()) phase = EcobiciPhase.Loading
        while (true) {
            try {
                val list = BaApi.shared.ecobiciStations()
                stations = list
                phase = if (list.isEmpty()) EcobiciPhase.Empty else EcobiciPhase.Ready
                lastUpdated = Instant.now()
            } catch (e: ApiError) {
                if (stations.isEmpty()) phase = EcobiciPhase.Error(e.message ?: "Revisá tu conexión e intentá de nuevo.")
            } catch (e: Exception) {
                if (stations.isEmpty()) phase = EcobiciPhase.Error("Revisá tu conexión e intentá de nuevo.")
            }
            delay(30_000)
        }
    }

    // Orden: con ubicación por cercanía; sin ubicación, alfabético.
    val origin: GeoPoint? = if (hasPermission) provider.point else null
    val sorted: List<Pair<EcobiciStation, Double?>> = remember(stations, origin, liveLocation) {
        if (origin != null) {
            stations.map { it to Geo.distanceMeters(origin, it.coordinate) }
                .sortedBy { it.second ?: Double.MAX_VALUE }
        } else {
            stations.sortedBy { it.displayName.lowercase() }.map { it to null }
        }
    }

    Box(
        Modifier
            .fillMaxSize()
            .background(Palette.background(dark))
    ) {
        when (val p = phase) {
            is EcobiciPhase.Loading ->
                if (stations.isEmpty()) LoadingState(message = "Buscando estaciones de EcoBici…")

            is EcobiciPhase.Error ->
                if (stations.isEmpty()) ErrorState(message = p.message, onRetry = { reloadKey++ })

            is EcobiciPhase.Empty ->
                EmptyState(
                    icon = Icons.Rounded.DirectionsBike,
                    title = "Sin estaciones",
                    message = "No encontramos estaciones de EcoBici ahora."
                )

            is EcobiciPhase.Ready -> {
                LazyColumn(
                    Modifier.fillMaxSize(),
                    contentPadding = PaddingValues(16.dp, 12.dp, 16.dp, 24.dp),
                    verticalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    if (!hasPermission) {
                        item {
                            EcobiciLocationBanner(dark) {
                                permissionLauncher.launch(
                                    arrayOf(
                                        android.Manifest.permission.ACCESS_FINE_LOCATION,
                                        android.Manifest.permission.ACCESS_COARSE_LOCATION
                                    )
                                )
                            }
                        }
                    }
                    if (lastUpdated != null) {
                        item {
                            Text(
                                "Actualizado ${Formatting.clock(lastUpdated)} hs",
                                color = Palette.textSecondary(dark),
                                fontSize = 11.sp,
                                fontWeight = FontWeight.Medium,
                                modifier = Modifier.fillMaxWidth(),
                                textAlign = androidx.compose.ui.text.style.TextAlign.End
                            )
                        }
                    }
                    items(sorted, key = { it.first.id }) { (station, distance) ->
                        val isFav = favs.any {
                            it.mode == com.alandaitch.anden.data.store.FavoriteMode.BICI && it.refId == station.id
                        }
                        EcobiciStationRow(
                            station, distance, dark,
                            isFavorite = isFav,
                            onToggleFav = {
                                com.alandaitch.anden.data.store.FavoritesStore.shared.toggle(
                                    com.alandaitch.anden.data.store.FavoriteItem.bici(station)
                                )
                            },
                        ) {
                            MapsOpener.walk(context, station.coordinate, station.displayName)
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun EcobiciStationRow(
    station: EcobiciStation,
    distanceMeters: Double?,
    dark: Boolean,
    isFavorite: Boolean = false,
    onToggleFav: (() -> Unit)? = null,
    onGo: () -> Unit
) {
    val inService = station.status == "IN_SERVICE"
    val availabilityColor: Color = when {
        !inService -> Palette.noData
        station.bikesTotal == 0 -> Palette.majorDelay
        station.bikesTotal <= 2 -> Palette.minorDelay
        else -> Palette.onTime
    }
    val fraction: Float =
        if (inService && station.capacity > 0) minOf(1f, station.bikesTotal.toFloat() / station.capacity.toFloat()) else 0f

    Row(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(Palette.surface(dark))
            .padding(vertical = 12.dp, horizontal = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        EcobiciRing(availabilityColor, fraction)

        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(5.dp)) {
            Text(
                station.displayName,
                color = Palette.textPrimary(dark),
                fontSize = 16.sp,
                fontWeight = FontWeight.SemiBold,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                if (distanceMeters != null) {
                    Text(Formatting.distanceText(distanceMeters), color = Palette.textSecondary(dark), fontSize = 12.sp, fontWeight = FontWeight.Medium)
                    Text("·", color = Palette.textSecondary(dark), fontSize = 12.sp)
                }
                Text(
                    "${station.docksAvailable} ${if (station.docksAvailable == 1) "anclaje libre" else "anclajes libres"}",
                    color = Palette.textSecondary(dark),
                    fontSize = 12.sp,
                    fontWeight = FontWeight.Medium,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
            }
            if (inService) {
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    EcobiciChip(Icons.Rounded.DirectionsBike, station.bikesMechanical, Palette.onTime)
                    EcobiciChip(Icons.Rounded.Bolt, station.bikesEbike, hexColor("#3B82F6"))
                }
            } else {
                Text("Fuera de servicio", color = Palette.noData, fontSize = 11.sp, fontWeight = FontWeight.Bold)
            }
        }

        Column(horizontalAlignment = Alignment.End, verticalArrangement = Arrangement.spacedBy(6.dp)) {
            if (onToggleFav != null) {
                IconButton(onClick = onToggleFav, modifier = Modifier.size(28.dp)) {
                    Icon(
                        if (isFavorite) Icons.Rounded.Star else Icons.Rounded.StarBorder,
                        contentDescription = if (isFavorite) "Quitar de favoritos" else "Agregar a favoritos",
                        tint = if (isFavorite) Palette.minorDelay else Palette.textSecondary(dark),
                        modifier = Modifier.size(20.dp),
                    )
                }
            }
            Text("${station.bikesTotal}", color = availabilityColor, fontSize = 26.sp, fontWeight = FontWeight.Black)
            Text(if (station.bikesTotal == 1) "bici" else "bicis", color = Palette.textSecondary(dark), fontSize = 11.sp, fontWeight = FontWeight.Medium)
            GoButton(onClick = onGo)
        }
    }
}

@Composable
private fun EcobiciRing(color: Color, fraction: Float) {
    Box(Modifier.size(38.dp), contentAlignment = Alignment.Center) {
        Canvas(Modifier.size(38.dp)) {
            val stroke = 3.dp.toPx()
            val inset = stroke / 2
            val arcSize = Size(size.width - stroke, size.height - stroke)
            drawArc(
                color = color.copy(alpha = 0.25f),
                startAngle = 0f,
                sweepAngle = 360f,
                useCenter = false,
                topLeft = Offset(inset, inset),
                size = arcSize,
                style = Stroke(width = stroke)
            )
            if (fraction > 0f) {
                drawArc(
                    color = color,
                    startAngle = -90f,
                    sweepAngle = 360f * fraction,
                    useCenter = false,
                    topLeft = Offset(inset, inset),
                    size = arcSize,
                    style = Stroke(width = stroke, cap = StrokeCap.Round)
                )
            }
        }
        Icon(Icons.Rounded.DirectionsBike, contentDescription = null, tint = color, modifier = Modifier.size(15.dp))
    }
}

@Composable
private fun EcobiciChip(icon: androidx.compose.ui.graphics.vector.ImageVector, count: Int, color: Color) {
    val active = count > 0
    val tint = if (active) color else Palette.noData
    Row(
        Modifier
            .clip(CircleShape)
            .background(tint.copy(alpha = 0.14f))
            .padding(horizontal = 7.dp, vertical = 3.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        Icon(icon, contentDescription = null, tint = tint, modifier = Modifier.size(11.dp))
        Text("$count", color = tint, fontSize = 11.sp, fontWeight = FontWeight.Bold)
    }
}

@Composable
private fun EcobiciLocationBanner(dark: Boolean, onActivate: () -> Unit) {
    Row(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .background(Palette.elevated(dark))
            .clickable(onClick = onActivate)
            .padding(12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Icon(Icons.Rounded.MyLocation, contentDescription = null, tint = Palette.brand, modifier = Modifier.size(22.dp))
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text("Activá tu ubicación", color = Palette.textPrimary(dark), fontSize = 13.sp, fontWeight = FontWeight.Bold)
            Text("Activala para ordenar las estaciones por cercanía.", color = Palette.textSecondary(dark), fontSize = 12.sp)
        }
        Text(
            "Activar",
            color = Color.White,
            fontSize = 12.sp,
            fontWeight = FontWeight.Bold,
            modifier = Modifier
                .clip(CircleShape)
                .background(Palette.brand)
                .padding(horizontal = 12.dp, vertical = 7.dp)
        )
    }
}
