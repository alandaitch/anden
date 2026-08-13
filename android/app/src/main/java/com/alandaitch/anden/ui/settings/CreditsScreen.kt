package com.alandaitch.anden.ui.settings

import androidx.compose.foundation.background
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
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Tram
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Divider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.alandaitch.anden.ui.theme.Palette

// Tarjeta de créditos. Pedido explícito de Alan.
@Composable
internal fun CreditsContent(dark: Boolean, onBack: () -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(Palette.background(dark))
    ) {
        SettingsSubScreenTopBar(title = "Créditos", dark = dark, onBack = onBack)

        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 24.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Spacer(Modifier.height(16.dp))

            Box(
                modifier = Modifier
                    .size(84.dp)
                    .background(Palette.brand, RoundedCornerShape(22.dp)),
                contentAlignment = Alignment.Center
            ) {
                Icon(Icons.Filled.Tram, contentDescription = null, tint = Color.White, modifier = Modifier.size(34.dp))
            }

            Spacer(Modifier.height(10.dp))
            Text("Andén", style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold, color = Palette.textPrimary(dark))
            Text("Tu tren, en vivo.", style = MaterialTheme.typography.bodyMedium, color = Palette.textSecondary(dark))

            Spacer(Modifier.height(28.dp))

            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                Icon(Icons.Filled.AutoAwesome, contentDescription = null, tint = Palette.brand, modifier = Modifier.size(16.dp))
                Text(
                    text = "Hecho por Alan Daitch + Claude (Anthropic).",
                    style = MaterialTheme.typography.bodyMedium,
                    fontWeight = FontWeight.SemiBold,
                    color = Palette.textPrimary(dark),
                    textAlign = TextAlign.Center
                )
            }

            Spacer(Modifier.height(16.dp))

            Card(
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(18.dp),
                colors = CardDefaults.cardColors(containerColor = Palette.surface(dark))
            ) {
                Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
                    CreditRow(icon = Icons.Filled.Person, name = "Alan Daitch", role = "Producto y diseño", dark = dark)
                    Divider(color = Palette.textSecondary(dark).copy(alpha = 0.15f))
                    CreditRow(icon = Icons.Filled.AutoAwesome, name = "Claude (Anthropic)", role = "Ingeniería", dark = dark)
                }
            }

            Spacer(Modifier.height(24.dp))

            Text(
                text = "Andén es un proyecto independiente. No tiene relación con SOFSE, Trenes Argentinos ni el Estado.",
                style = MaterialTheme.typography.bodySmall,
                color = Palette.textSecondary(dark),
                textAlign = TextAlign.Center
            )

            Spacer(Modifier.height(32.dp))
        }
    }
}

@Composable
private fun CreditRow(icon: ImageVector, name: String, role: String, dark: Boolean) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        Box(
            modifier = Modifier
                .size(40.dp)
                .background(Palette.brand.copy(alpha = 0.15f), CircleShape),
            contentAlignment = Alignment.Center
        ) {
            Icon(icon, contentDescription = null, tint = Palette.brand)
        }
        Column {
            Text(name, style = MaterialTheme.typography.bodyLarge, fontWeight = FontWeight.SemiBold, color = Palette.textPrimary(dark))
            Text(role, style = MaterialTheme.typography.bodySmall, color = Palette.textSecondary(dark))
        }
    }
}
