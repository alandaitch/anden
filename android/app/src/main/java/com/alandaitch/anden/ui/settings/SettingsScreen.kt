package com.alandaitch.anden.ui.settings

import androidx.activity.compose.BackHandler
import androidx.compose.animation.Crossfade
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.CloudOff
import androidx.compose.material.icons.filled.Dns
import androidx.compose.material.icons.filled.NotificationsActive
import androidx.compose.material.icons.filled.Verified
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material.icons.filled.WifiOff
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.alandaitch.anden.BuildConfig
import com.alandaitch.anden.data.store.AppSettings
import com.alandaitch.anden.ui.theme.Palette

// Pantalla raíz de Ajustes. Maneja su propia sub-navegación interna
// (Principal / Acerca de / Créditos) con estado local, sin NavController.
@Composable
fun SettingsScreen(modifier: Modifier = Modifier) {
    val dark = isSystemInDarkTheme()
    var page by remember { mutableStateOf(SettingsPage.MAIN) }

    BackHandler(enabled = page != SettingsPage.MAIN) { page = SettingsPage.MAIN }

    Crossfade(targetState = page, modifier = modifier.fillMaxSize(), label = "settings-page") { current ->
        when (current) {
            SettingsPage.MAIN -> SettingsMainContent(
                dark = dark,
                onOpenAbout = { page = SettingsPage.ABOUT },
                onOpenCredits = { page = SettingsPage.CREDITS }
            )
            SettingsPage.ABOUT -> AboutContent(dark = dark, onBack = { page = SettingsPage.MAIN })
            SettingsPage.CREDITS -> CreditsContent(dark = dark, onBack = { page = SettingsPage.MAIN })
        }
    }
}

private enum class SettingsPage { MAIN, ABOUT, CREDITS }

@Composable
private fun SettingsMainContent(dark: Boolean, onOpenAbout: () -> Unit, onOpenCredits: () -> Unit) {
    var notifEnabled by remember { mutableStateOf(AppSettings.shared.notifDemorasEnabled) }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(Palette.background(dark))
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 20.dp)
    ) {
        Text(
            text = "Ajustes",
            style = MaterialTheme.typography.headlineMedium,
            fontWeight = FontWeight.Bold,
            color = Palette.textPrimary(dark),
            modifier = Modifier.padding(vertical = 16.dp)
        )

        SettingsSection(dark = dark) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    Icon(Icons.Filled.NotificationsActive, contentDescription = null, tint = Palette.brand)
                    Text(
                        text = "Avisarme de demoras",
                        style = MaterialTheme.typography.bodyLarge,
                        color = Palette.textPrimary(dark)
                    )
                }
                Switch(
                    checked = notifEnabled,
                    onCheckedChange = { checked ->
                        notifEnabled = checked
                        AppSettings.shared.notifDemorasEnabled = checked
                    },
                    colors = SwitchDefaults.colors(checkedTrackColor = Palette.brand)
                )
            }
            Text(
                text = "Guarda tu preferencia. Hoy no hay chequeo en segundo plano.",
                style = MaterialTheme.typography.bodySmall,
                color = Palette.textSecondary(dark)
            )
        }

        Spacer(Modifier.height(16.dp))
        SettingsSectionTitle(title = "Cómo funciona", dark = dark)
        SettingsSection(dark = dark) {
            SettingsInfoRow(icon = Icons.Filled.WifiOff, text = "Sin servidor propio, no hay push en tiempo real.", dark = dark)
            SettingsInfoRow(icon = Icons.Filled.CloudOff, text = "El horario de colectivos usa un backend de la Ciudad. A veces da error 503.", dark = dark)
            SettingsInfoRow(icon = Icons.Filled.Warning, text = "Belgrano Norte y Urquiza no tienen datos en tiempo real.", dark = dark)
            SettingsLinkRow(text = "Ver el detalle completo", dark = dark, onClick = onOpenAbout)
        }

        Spacer(Modifier.height(16.dp))
        SettingsSectionTitle(title = "Datos", dark = dark)
        SettingsSection(dark = dark) {
            SettingsInfoRow(icon = Icons.Filled.Dns, text = "Fuente: API pública de Trenes Argentinos (SOFSE).", dark = dark)
            SettingsInfoRow(icon = Icons.Filled.Dns, text = "Subte y colectivos usan la API de la Ciudad.", dark = dark)
            SettingsInfoRow(icon = Icons.Filled.Verified, text = "Andén es una app no oficial.", dark = dark)
        }

        Spacer(Modifier.height(16.dp))
        SettingsSection(dark = dark) {
            CreditsPreviewRow(dark = dark, onClick = onOpenCredits)
        }

        Spacer(Modifier.height(16.dp))
        SettingsSection(dark = dark) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Text("Versión", style = MaterialTheme.typography.bodyMedium, color = Palette.textPrimary(dark))
                Text(
                    text = "${BuildConfig.VERSION_NAME} (${BuildConfig.VERSION_CODE})",
                    style = MaterialTheme.typography.bodyMedium,
                    color = Palette.textSecondary(dark)
                )
            }
        }

        Spacer(Modifier.height(32.dp))
    }
}

@Composable
private fun SettingsSectionTitle(title: String, dark: Boolean) {
    Text(
        text = title,
        style = MaterialTheme.typography.titleSmall,
        fontWeight = FontWeight.SemiBold,
        color = Palette.textSecondary(dark),
        modifier = Modifier.padding(bottom = 8.dp, top = 4.dp)
    )
}

@Composable
private fun SettingsSection(dark: Boolean, content: @Composable ColumnScope.() -> Unit) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(18.dp),
        colors = CardDefaults.cardColors(containerColor = Palette.surface(dark))
    ) {
        Column(
            modifier = Modifier.padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
            content = content
        )
    }
}

@Composable
private fun SettingsInfoRow(icon: ImageVector, text: String, dark: Boolean) {
    Row(horizontalArrangement = Arrangement.spacedBy(12.dp), verticalAlignment = Alignment.Top) {
        Icon(icon, contentDescription = null, tint = Palette.brand, modifier = Modifier.size(20.dp))
        Text(
            text = text,
            style = MaterialTheme.typography.bodyMedium,
            color = Palette.textPrimary(dark)
        )
    }
}

@Composable
private fun SettingsLinkRow(text: String, dark: Boolean, onClick: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(text, style = MaterialTheme.typography.bodyMedium, color = Palette.brand, fontWeight = FontWeight.SemiBold)
        Icon(Icons.Filled.ChevronRight, contentDescription = null, tint = Palette.brand)
    }
}

@Composable
private fun CreditsPreviewRow(dark: Boolean, onClick: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(Icons.Filled.AutoAwesome, contentDescription = null, tint = Palette.brand)
        Column(modifier = Modifier.weight(1f)) {
            Text("Créditos", style = MaterialTheme.typography.bodyLarge, fontWeight = FontWeight.SemiBold, color = Palette.textPrimary(dark))
            Text("Alan Daitch + Claude (Anthropic)", style = MaterialTheme.typography.bodySmall, color = Palette.textSecondary(dark))
        }
        Icon(Icons.Filled.ChevronRight, contentDescription = null, tint = Palette.textSecondary(dark))
    }
}
