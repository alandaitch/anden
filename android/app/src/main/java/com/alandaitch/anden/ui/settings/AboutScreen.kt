package com.alandaitch.anden.ui.settings

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
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
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.alandaitch.anden.ui.theme.Palette

// Detalle honesto de los límites de Andén. Sin vueltas, sin promesas falsas.
@Composable
internal fun AboutContent(dark: Boolean, onBack: () -> Unit) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(Palette.background(dark))
    ) {
        SettingsSubScreenTopBar(title = "Acerca de Andén", dark = dark, onBack = onBack)

        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(20.dp)
        ) {
            AboutSectionBlock(
                title = "Cómo funciona",
                items = listOf(
                    "Andén no tiene servidor propio.",
                    "No hay notificaciones push en tiempo real.",
                    "El aviso de demoras guarda tu preferencia nomás.",
                    "El chequeo en segundo plano llega en otra versión."
                ),
                dark = dark
            )

            AboutSectionBlock(
                title = "Colectivos",
                items = listOf(
                    "El horario depende de la API de la Ciudad.",
                    "Esa API a veces devuelve error 503.",
                    "Un tercio de los colectivos no tiene número de línea.",
                    "Es un límite del catálogo GTFS de 2019."
                ),
                dark = dark
            )

            AboutSectionBlock(
                title = "Cobertura de tren",
                items = listOf(
                    "Belgrano Norte y Urquiza no tienen tiempo real.",
                    "Las opera Ferrovías y Metrovías, fuera de la API de SOFSE.",
                    "Las demás líneas del AMBA sí tienen datos en vivo."
                ),
                dark = dark
            )

            AboutSectionBlock(
                title = "Datos",
                items = listOf(
                    "La fuente es la API pública de Trenes Argentinos (SOFSE).",
                    "Subte y colectivos usan la API de la Ciudad.",
                    "Andén es una app no oficial. No tiene relación con el Estado."
                ),
                dark = dark
            )
        }
    }
}

@Composable
internal fun SettingsSubScreenTopBar(title: String, dark: Boolean, onBack: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 4.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        IconButton(onClick = onBack) {
            Icon(Icons.Filled.ArrowBack, contentDescription = "Volver", tint = Palette.textPrimary(dark))
        }
        Text(
            text = title,
            style = MaterialTheme.typography.titleLarge,
            fontWeight = FontWeight.Bold,
            color = Palette.textPrimary(dark)
        )
    }
}

@Composable
private fun AboutSectionBlock(title: String, items: List<String>, dark: Boolean) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(18.dp),
        colors = CardDefaults.cardColors(containerColor = Palette.surface(dark))
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Text(
                text = title,
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold,
                color = Palette.textPrimary(dark)
            )
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                items.forEach { item ->
                    Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        Box(
                            modifier = Modifier
                                .padding(top = 7.dp)
                                .size(6.dp)
                                .background(Palette.brand, CircleShape)
                        )
                        Text(
                            text = item,
                            style = MaterialTheme.typography.bodyMedium,
                            color = Palette.textSecondary(dark)
                        )
                    }
                }
            }
        }
    }
}
