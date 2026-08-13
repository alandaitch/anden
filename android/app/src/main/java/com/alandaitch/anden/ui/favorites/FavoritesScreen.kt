package com.alandaitch.anden.ui.favorites

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.StarBorder
import androidx.compose.material.icons.filled.Work
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.alandaitch.anden.data.store.FavoriteRole
import com.alandaitch.anden.data.store.FavoritesStore
import com.alandaitch.anden.ui.components.EmptyState
import com.alandaitch.anden.ui.components.LineBadge
import com.alandaitch.anden.ui.components.SectionHeader
import com.alandaitch.anden.ui.theme.andenCard
import com.alandaitch.anden.ui.theme.andenColors
import androidx.compose.runtime.collectAsState

// Pantalla de favoritos: estaciones guardadas con tap al tablero. Estado vacío claro.
@Composable
fun FavoritesScreen(
    onOpenTren: (Int) -> Unit,
    modifier: Modifier = Modifier,
) {
    val colors = andenColors()
    val store = remember { FavoritesStore.shared }
    val favs by store.itemsFlow.collectAsState()
    val stations = remember(favs) { store.favorites }

    Box(modifier = modifier.fillMaxSize()) {
        if (stations.isEmpty()) {
            EmptyState(
                icon = Icons.Filled.StarBorder,
                title = "Sin favoritos",
                message = "Guardá una estación desde su tablero para verla acá.",
                modifier = Modifier.align(Alignment.Center),
            )
        } else {
            LazyColumn(
                modifier = Modifier.fillMaxSize(),
                contentPadding = androidx.compose.foundation.layout.PaddingValues(16.dp),
                verticalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                item {
                    SectionHeader(title = "Favoritos", subtitle = "Tus estaciones guardadas")
                    Spacer(Modifier.width(0.dp))
                }
                items(stations, key = { it.id }) { station ->
                    val role = store.role(station.id)
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .andenCard(corner = 16.dp)
                            .clickable { onOpenTren(station.id) }
                            .padding(horizontal = 14.dp, vertical = 12.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        LineBadge(line = station.line, size = 40.dp)
                        Spacer(Modifier.width(12.dp))
                        Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
                            Text(
                                text = station.nombre,
                                color = colors.textPrimary,
                                fontWeight = FontWeight.SemiBold,
                                fontSize = 16.sp,
                                maxLines = 1,
                            )
                            Row(
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.spacedBy(6.dp),
                            ) {
                                Text(
                                    station.line.shortCode,
                                    color = station.line.color,
                                    fontWeight = FontWeight.Bold,
                                    fontSize = 11.sp,
                                    maxLines = 1,
                                )
                                if (role != FavoriteRole.NONE) {
                                    Text("·", color = colors.textSecondary, fontSize = 11.sp)
                                    Icon(
                                        imageVector = if (role == FavoriteRole.HOME) Icons.Filled.Home else Icons.Filled.Work,
                                        contentDescription = null,
                                        tint = colors.textSecondary,
                                        modifier = Modifier.size(13.dp),
                                    )
                                    Text(
                                        if (role == FavoriteRole.HOME) "Casa" else "Trabajo",
                                        color = colors.textSecondary,
                                        fontWeight = FontWeight.Medium,
                                        fontSize = 11.sp,
                                    )
                                }
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
            }
        }
    }
}
