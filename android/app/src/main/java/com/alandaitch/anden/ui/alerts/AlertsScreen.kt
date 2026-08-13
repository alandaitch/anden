package com.alandaitch.anden.ui.alerts

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
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
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AltRoute
import androidx.compose.material.icons.filled.Block
import androidx.compose.material.icons.filled.Build
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Error
import androidx.compose.material.icons.filled.FilterAlt
import androidx.compose.material.icons.filled.Handyman
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.PersonOff
import androidx.compose.material.icons.filled.Schedule
import androidx.compose.material.icons.filled.Thunderstorm
import androidx.compose.material.icons.filled.Train
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material.icons.filled.WrongLocation
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.pulltorefresh.PullToRefreshContainer
import androidx.compose.material3.pulltorefresh.rememberPullToRefreshState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.input.nestedscroll.nestedScroll
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.alandaitch.anden.data.model.ServiceAlert
import com.alandaitch.anden.data.model.SubteAlertItem
import com.alandaitch.anden.data.model.TrainLine
import com.alandaitch.anden.data.net.ApiError
import com.alandaitch.anden.data.net.BaApi
import com.alandaitch.anden.data.net.SofseApi
import com.alandaitch.anden.ui.components.EmptyState
import com.alandaitch.anden.ui.components.ErrorState
import com.alandaitch.anden.ui.components.LineBadge
import com.alandaitch.anden.ui.components.LoadingState
import com.alandaitch.anden.ui.components.SectionHeader
import com.alandaitch.anden.ui.components.SubteBadge
import com.alandaitch.anden.ui.theme.Palette
import com.alandaitch.anden.ui.theme.hexColor
import com.alandaitch.anden.util.Formatting
import java.time.Instant
import kotlinx.coroutines.launch

// Pantalla Alertas. Junta alertas de tren (SofseApi) y de subte (BaApi).
// Filtro por línea de tren, pull-to-refresh, estados loading/vacío/error por sección.
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AlertsScreen(modifier: Modifier = Modifier) {
    val dark = isSystemInDarkTheme()
    val scope = rememberCoroutineScope()
    val pullState = rememberPullToRefreshState()

    var trainAlerts by remember { mutableStateOf<List<ServiceAlert>>(emptyList()) }
    var subteAlerts by remember { mutableStateOf<List<SubteAlertItem>>(emptyList()) }
    var isLoadingTrain by remember { mutableStateOf(true) }
    var isLoadingSubte by remember { mutableStateOf(true) }
    var trainError by remember { mutableStateOf<String?>(null) }
    var subteError by remember { mutableStateOf<String?>(null) }
    var selectedLineId by remember { mutableStateOf<Int?>(null) }

    suspend fun loadTrain() {
        isLoadingTrain = true
        try {
            trainAlerts = SofseApi.shared.alerts()
            trainError = null
        } catch (e: ApiError) {
            trainError = e.message ?: "No pudimos cargar las alertas de tren."
        } catch (e: Exception) {
            trainError = "No pudimos cargar las alertas de tren."
        }
        isLoadingTrain = false
    }

    suspend fun loadSubte() {
        isLoadingSubte = true
        try {
            subteAlerts = BaApi.shared.subteAlerts()
            subteError = null
        } catch (e: ApiError) {
            subteError = e.message ?: "No pudimos cargar las alertas de subte."
        } catch (e: Exception) {
            subteError = "No pudimos cargar las alertas de subte."
        }
        isLoadingSubte = false
    }

    suspend fun refreshAll() {
        loadTrain()
        loadSubte()
    }

    LaunchedEffect(Unit) { refreshAll() }

    LaunchedEffect(pullState.isRefreshing) {
        if (pullState.isRefreshing) {
            refreshAll()
            pullState.endRefresh()
        }
    }

    val filteredTrainAlerts = remember(trainAlerts, selectedLineId) {
        val id = selectedLineId
        if (id == null) trainAlerts else trainAlerts.filter { it.lineId == id }
    }

    Column(
        modifier = modifier
            .fillMaxSize()
            .background(Palette.background(dark))
    ) {
        Text(
            text = "Alertas",
            style = MaterialTheme.typography.headlineMedium,
            fontWeight = FontWeight.Bold,
            color = Palette.textPrimary(dark),
            modifier = Modifier.padding(horizontal = 20.dp, vertical = 16.dp)
        )

        Box(
            modifier = Modifier
                .fillMaxWidth()
                .fillMaxSize()
                .nestedScroll(pullState.nestedScrollConnection)
        ) {
            val bothLoadingEmpty = isLoadingTrain && isLoadingSubte && trainAlerts.isEmpty() && subteAlerts.isEmpty()
            val bothErrorEmpty = trainError != null && trainAlerts.isEmpty() && subteError != null && subteAlerts.isEmpty()

            when {
                bothLoadingEmpty -> {
                    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        LoadingState(message = "Buscando alertas…")
                    }
                }
                bothErrorEmpty -> {
                    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        ErrorState(
                            message = trainError ?: subteError ?: "No pudimos cargar las alertas.",
                            onRetry = { scope.launch { refreshAll() } }
                        )
                    }
                }
                else -> {
                    LazyColumn(
                        modifier = Modifier.fillMaxSize(),
                        verticalArrangement = Arrangement.spacedBy(12.dp),
                        contentPadding = PaddingValues(bottom = 24.dp)
                    ) {
                        item {
                            AlertsChipsRow(
                                selectedLineId = selectedLineId,
                                onSelect = { selectedLineId = it },
                                dark = dark
                            )
                        }

                        when {
                            trainAlerts.isEmpty() && trainError == null -> item {
                                Box(Modifier.padding(horizontal = 16.dp)) {
                                    EmptyState(
                                        icon = Icons.Filled.CheckCircle,
                                        title = "Todo en orden",
                                        message = "Sin alertas de tren. Todo el servicio normal."
                                    )
                                }
                            }
                            trainError != null && trainAlerts.isEmpty() -> item {
                                Box(Modifier.padding(horizontal = 16.dp)) {
                                    ErrorState(
                                        message = trainError ?: "Error",
                                        onRetry = { scope.launch { loadTrain() } }
                                    )
                                }
                            }
                            filteredTrainAlerts.isEmpty() -> item {
                                Box(Modifier.padding(horizontal = 16.dp)) {
                                    EmptyState(
                                        icon = Icons.Filled.FilterAlt,
                                        title = "Sin alertas para esta línea",
                                        message = "Probá con otra línea o mirá todas."
                                    )
                                }
                            }
                            else -> items(filteredTrainAlerts, key = { it.id }) { alert ->
                                Box(Modifier.padding(horizontal = 16.dp)) {
                                    AlertsTrainCard(alert = alert, dark = dark)
                                }
                            }
                        }

                        item {
                            Box(Modifier.padding(horizontal = 16.dp)) {
                                SectionHeader(title = "Subte")
                            }
                        }

                        when {
                            isLoadingSubte && subteAlerts.isEmpty() -> item {
                                Box(Modifier.padding(horizontal = 16.dp)) {
                                    LoadingState(message = "Buscando alertas de subte…")
                                }
                            }
                            subteError != null && subteAlerts.isEmpty() -> item {
                                Box(Modifier.padding(horizontal = 16.dp)) {
                                    ErrorState(
                                        message = subteError ?: "Error",
                                        onRetry = { scope.launch { loadSubte() } }
                                    )
                                }
                            }
                            subteAlerts.isEmpty() -> item {
                                Box(Modifier.padding(horizontal = 16.dp)) {
                                    EmptyState(
                                        icon = Icons.Filled.CheckCircle,
                                        title = "Subte sin alertas",
                                        message = "Servicio normal en todas las líneas."
                                    )
                                }
                            }
                            else -> items(subteAlerts, key = { it.id }) { alert ->
                                Box(Modifier.padding(horizontal = 16.dp)) {
                                    AlertsSubteCard(alert = alert, dark = dark)
                                }
                            }
                        }
                    }
                }
            }

            PullToRefreshContainer(
                state = pullState,
                modifier = Modifier.align(Alignment.TopCenter)
            )
        }
    }
}

// MARK: - Chips de filtro por línea

@Composable
private fun AlertsChipsRow(selectedLineId: Int?, onSelect: (Int?) -> Unit, dark: Boolean) {
    LazyRow(
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        contentPadding = PaddingValues(horizontal = 16.dp)
    ) {
        item {
            AlertsChip(
                title = "Todas",
                color = Palette.brand,
                selected = selectedLineId == null,
                dark = dark,
                onClick = { onSelect(null) }
            )
        }
        items(TrainLine.all, key = { it.id }) { line ->
            AlertsChip(
                title = line.shortCode,
                color = line.color,
                selected = selectedLineId == line.id,
                dark = dark,
                onClick = { onSelect(line.id) }
            )
        }
    }
}

@Composable
private fun AlertsChip(title: String, color: Color, selected: Boolean, dark: Boolean, onClick: () -> Unit) {
    Surface(
        onClick = onClick,
        shape = CircleShape,
        color = if (selected) color else Palette.elevated(dark),
        contentColor = if (selected) Color.White else Palette.textPrimary(dark),
        border = if (selected) null else BorderStroke(1.dp, color.copy(alpha = 0.4f))
    ) {
        Text(
            text = title,
            style = MaterialTheme.typography.labelLarge,
            fontWeight = FontWeight.SemiBold,
            modifier = Modifier.padding(horizontal = 14.dp, vertical = 8.dp)
        )
    }
}

// MARK: - Tarjetas de alerta

@Composable
private fun AlertsTrainCard(alert: ServiceAlert, dark: Boolean) {
    val borderColor = criticalityColor(alert.criticality)
    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(18.dp),
        colors = CardDefaults.cardColors(containerColor = Palette.surface(dark)),
        border = BorderStroke(1.5.dp, borderColor)
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Icon(
                imageVector = iconForAlertName(alert.iconName),
                contentDescription = null,
                tint = borderColor,
                modifier = Modifier.size(22.dp)
            )
            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    LineBadge(line = TrainLine.line(alert.lineId ?: -1))
                    Text(
                        text = alertValidityText(alert.validFrom, alert.validUntil),
                        style = MaterialTheme.typography.labelSmall,
                        color = Palette.textSecondary(dark)
                    )
                }
                Text(
                    text = alert.content,
                    style = MaterialTheme.typography.bodyMedium,
                    fontWeight = FontWeight.Medium,
                    color = Palette.textPrimary(dark)
                )
            }
        }
    }
}

@Composable
private fun AlertsSubteCard(alert: SubteAlertItem, dark: Boolean) {
    val borderColor = when (alert.effect) {
        1 -> Palette.majorDelay
        4 -> Palette.minorDelay
        else -> hexColor("#3B82F6")
    }
    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(18.dp),
        colors = CardDefaults.cardColors(containerColor = Palette.surface(dark)),
        border = BorderStroke(1.5.dp, borderColor)
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Icon(
                imageVector = iconForAlertName(alert.iconName),
                contentDescription = null,
                tint = borderColor,
                modifier = Modifier.size(22.dp)
            )
            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                SubteBadge(line = alert.line)
                Text(
                    text = alert.text,
                    style = MaterialTheme.typography.bodyMedium,
                    fontWeight = FontWeight.Medium,
                    color = Palette.textPrimary(dark)
                )
            }
        }
    }
}

// MARK: - Helpers

private fun criticalityColor(criticality: Int): Color = when (criticality) {
    1 -> Palette.majorDelay
    2 -> Palette.minorDelay
    else -> hexColor("#3B82F6")
}

private fun alertValidityText(from: Instant?, until: Instant?): String = when {
    from != null && until != null -> "${Formatting.clock(from)} a ${Formatting.clock(until)} hs"
    from != null -> "Desde las ${Formatting.clock(from)} hs"
    until != null -> "Hasta las ${Formatting.clock(until)} hs"
    else -> "Vigente"
}

// Mapea el iconName de la capa de datos (block/schedule_alert/train_tunnel/...) a un ImageVector.
private fun iconForAlertName(name: String): ImageVector = when (name) {
    "block" -> Icons.Filled.Block
    "schedule_alert" -> Icons.Filled.Schedule
    "train_tunnel" -> Icons.Filled.Train
    "alt_route" -> Icons.Filled.AltRoute
    "wrong_location" -> Icons.Filled.WrongLocation
    "warning" -> Icons.Filled.Warning
    "build" -> Icons.Filled.Build
    "person_off" -> Icons.Filled.PersonOff
    "handyman" -> Icons.Filled.Handyman
    "thunderstorm" -> Icons.Filled.Thunderstorm
    "error" -> Icons.Filled.Error
    else -> Icons.Filled.Info
}
