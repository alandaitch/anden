package com.alandaitch.anden.ui.favorites

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.background
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.DirectionsBike
import androidx.compose.material.icons.filled.DirectionsBus
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.StarBorder
import androidx.compose.material.icons.filled.Work
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import com.alandaitch.anden.data.model.EcobiciStation
import com.alandaitch.anden.data.net.BaApi
import com.alandaitch.anden.data.net.ObaApi
import com.alandaitch.anden.data.net.SofseApi
import com.alandaitch.anden.data.store.FavoriteItem
import com.alandaitch.anden.data.store.FavoriteMode
import com.alandaitch.anden.data.store.FavoriteRole
import com.alandaitch.anden.data.store.FavoritesStore
import com.alandaitch.anden.ui.components.EmptyState
import com.alandaitch.anden.ui.components.SectionHeader
import com.alandaitch.anden.ui.theme.BiciAccent
import com.alandaitch.anden.ui.theme.andenCard
import com.alandaitch.anden.ui.theme.andenColors
import com.alandaitch.anden.ui.theme.hexColor
import com.alandaitch.anden.util.Formatting
import kotlinx.coroutines.launch
import kotlinx.coroutines.supervisorScope

// Pantalla de favoritos multi-modo: tren, subte, colectivo y bici, con su próximo arribo.
@Composable
fun FavoritesScreen(
    onOpenTren: (Int) -> Unit,
    onOpenSubte: (String, String?) -> Unit,
    onOpenBondi: (String, String, Double, Double) -> Unit,
    onOpenBici: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val colors = andenColors()
    val store = remember { FavoritesStore.shared }
    val favs by store.itemsFlow.collectAsState()
    val subtitles = remember { mutableStateMapOf<String, String>() }

    // Trae el próximo arribo (o disponibilidad, en bici) de cada favorito.
    LaunchedEffect(favs) {
        if (favs.isEmpty()) return@LaunchedEffect
        val ecobici: Map<String, EcobiciStation> =
            if (favs.any { it.mode == FavoriteMode.BICI }) {
                runCatching { BaApi.shared.ecobiciStations().associateBy { it.id } }.getOrNull().orEmpty()
            } else emptyMap()
        supervisorScope {
            favs.forEach { item ->
                launch { subtitleFor(item, ecobici)?.let { subtitles[item.id] = it } }
            }
        }
    }

    fun open(item: FavoriteItem) {
        when (item.mode) {
            FavoriteMode.TREN -> item.refId.toIntOrNull()?.let(onOpenTren)
            FavoriteMode.SUBTE -> onOpenSubte(item.name, item.routeId)
            FavoriteMode.BONDI -> onOpenBondi(item.refId, item.name, item.lat, item.lng)
            FavoriteMode.BICI -> onOpenBici()
        }
    }

    Box(modifier = modifier.fillMaxSize()) {
        if (favs.isEmpty()) {
            EmptyState(
                icon = Icons.Filled.StarBorder,
                title = "Sin favoritos",
                message = "Guardá cualquier parada (tren, subte, colectivo o bici) desde su tablero para verla acá.",
                modifier = Modifier.align(Alignment.Center),
            )
        } else {
            val primary = remember(favs) { store.contextualPrimary() }
            LazyColumn(
                modifier = Modifier.fillMaxSize(),
                contentPadding = PaddingValues(16.dp),
                verticalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                if (primary != null) {
                    item {
                        SectionHeader(title = "Del momento", subtitle = roleText(primary.role))
                    }
                    item(key = "primary-${primary.id}") {
                        FavoriteRow(primary, subtitles[primary.id], colors) { open(primary) }
                    }
                }
                item {
                    SectionHeader(title = "Tus favoritos", subtitle = null)
                    Spacer(Modifier.width(0.dp))
                }
                items(favs, key = { it.id }) { item ->
                    FavoriteRow(item, subtitles[item.id], colors) { open(item) }
                }
            }
        }
    }
}

@Composable
private fun FavoriteRow(
    item: FavoriteItem,
    subtitle: String?,
    colors: com.alandaitch.anden.ui.theme.AndenColors,
    onClick: () -> Unit,
) {
    val accent = accentFor(item)
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .andenCard(corner = 16.dp)
            .clickable(onClick = onClick)
            .padding(horizontal = 14.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        FavoriteBadge(item, accent)
        Spacer(Modifier.width(12.dp))
        Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
            Text(
                text = item.name,
                color = colors.textPrimary,
                fontWeight = FontWeight.SemiBold,
                fontSize = 16.sp,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                Text(modeTag(item.mode), color = accent, fontWeight = FontWeight.Bold, fontSize = 11.sp)
                if (item.role != FavoriteRole.NONE) {
                    Icon(
                        imageVector = if (item.role == FavoriteRole.HOME) Icons.Filled.Home else Icons.Filled.Work,
                        contentDescription = null,
                        tint = colors.textSecondary,
                        modifier = Modifier.size(13.dp),
                    )
                }
            }
            if (subtitle != null) {
                Text(subtitle, color = colors.onTime, fontWeight = FontWeight.Medium, fontSize = 13.sp, maxLines = 1, overflow = TextOverflow.Ellipsis)
            }
        }
        Icon(
            Icons.Filled.ChevronRight,
            contentDescription = null,
            tint = colors.textSecondary.copy(alpha = 0.5f),
            modifier = Modifier.size(20.dp),
        )
    }
}

@Composable
private fun FavoriteBadge(item: FavoriteItem, accent: Color) {
    Box(
        modifier = Modifier
            .size(44.dp)
            .clip(RoundedCornerShape(12.dp))
            .background(accent),
        contentAlignment = Alignment.Center,
    ) {
        val label = item.lineLabel
        if (label != null && label.isNotEmpty()) {
            Text(label, color = Color.White, fontWeight = FontWeight.Black, fontSize = 17.sp, maxLines = 1)
        } else {
            Icon(
                imageVector = if (item.mode == FavoriteMode.BICI) Icons.Filled.DirectionsBike else Icons.Filled.DirectionsBus,
                contentDescription = null,
                tint = Color.White,
                modifier = Modifier.size(22.dp),
            )
        }
    }
}

private fun accentFor(item: FavoriteItem): Color = when (item.mode) {
    FavoriteMode.TREN, FavoriteMode.SUBTE -> hexColor(item.lineColorHex ?: "#3A4A63")
    FavoriteMode.BONDI -> hexColor("#242C4F")
    FavoriteMode.BICI -> BiciAccent
}

private fun modeTag(mode: FavoriteMode): String = when (mode) {
    FavoriteMode.TREN -> "Tren"
    FavoriteMode.SUBTE -> "Subte"
    FavoriteMode.BONDI -> "Colectivo"
    FavoriteMode.BICI -> "EcoBici"
}

private fun roleText(role: FavoriteRole): String? = when (role) {
    FavoriteRole.HOME -> "Tu casa"
    FavoriteRole.WORK -> "Tu trabajo"
    FavoriteRole.NONE -> null
}

// Próximo arribo (o disponibilidad en bici) resuelto por el cliente de cada modo.
private suspend fun subtitleFor(item: FavoriteItem, ecobici: Map<String, EcobiciStation>): String? = when (item.mode) {
    FavoriteMode.TREN -> runCatching {
        val a = SofseApi.shared.arrivals(item.refId.toInt(), limit = 1).firstOrNull() ?: return null
        "${Formatting.etaText(a.secondsUntil)} · a ${a.destinationName}"
    }.getOrNull()
    FavoriteMode.SUBTE -> runCatching {
        val a = BaApi.shared.subteArrivals(item.name).minByOrNull { it.secondsUntil } ?: return null
        "${Formatting.etaText(a.secondsUntil)} · a ${a.destinationName}"
    }.getOrNull()
    FavoriteMode.BONDI -> runCatching {
        val a = ObaApi.shared.stopArrivals(item.refId).firstOrNull() ?: return null
        val estado = if (a.isLive) "en vivo" else "prog"
        "${a.lineShort} · ${Formatting.etaText(a.secondsUntil)} $estado"
    }.getOrNull()
    FavoriteMode.BICI -> ecobici[item.refId]?.let { st ->
        val bikes = "${st.bikesTotal} ${if (st.bikesTotal == 1) "bici" else "bicis"}"
        val docks = "${st.docksAvailable} ${if (st.docksAvailable == 1) "anclaje" else "anclajes"}"
        "$bikes · $docks"
    }
}
