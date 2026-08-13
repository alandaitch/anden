package com.alandaitch.anden.ui.comollego

import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.background
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.DirectionsTransit
import androidx.compose.material.icons.filled.Explore
import androidx.compose.material.icons.filled.History
import androidx.compose.material.icons.filled.NearMe
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.unit.dp
import com.alandaitch.anden.ui.components.EmptyState
import com.alandaitch.anden.ui.components.SectionHeader
import com.alandaitch.anden.ui.theme.Palette

// "Cómo llego": buscador de destino en texto libre. Al confirmar, delega el
// ruteo multimodal completo a Google Maps con indicaciones de transporte
// público (no armamos rutas propias: no tenemos datos para combinar
// colectivo + subte + tren en un viaje).
@Composable
fun ComoLlegoScreen(onBack: () -> Unit) {
    val dark = isSystemInDarkTheme()
    val context = LocalContext.current
    val focusManager = LocalFocusManager.current

    var query by remember { mutableStateOf("") }
    var recents by remember { mutableStateOf(ComoLlegoRecentsStore.load(context)) }

    fun go(destination: String) {
        val trimmed = destination.trim()
        if (trimmed.isEmpty()) return
        focusManager.clearFocus()
        openTransitDirections(context, trimmed)
        recents = ComoLlegoRecentsStore.record(context, trimmed)
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(Palette.background(dark))
    ) {
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
                text = "Cómo llego",
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Bold,
                color = Palette.textPrimary(dark)
            )
        }

        Column(modifier = Modifier.padding(horizontal = 16.dp)) {
            OutlinedTextField(
                value = query,
                onValueChange = { query = it },
                modifier = Modifier.fillMaxWidth(),
                placeholder = { Text("¿A dónde vas?") },
                leadingIcon = { Icon(Icons.Filled.Search, contentDescription = null) },
                trailingIcon = {
                    if (query.isNotEmpty()) {
                        IconButton(onClick = { query = "" }) {
                            Icon(Icons.Filled.Close, contentDescription = "Borrar")
                        }
                    }
                },
                singleLine = true,
                shape = RoundedCornerShape(16.dp),
                keyboardOptions = KeyboardOptions(imeAction = ImeAction.Search),
                keyboardActions = KeyboardActions(onSearch = { go(query) }),
                colors = OutlinedTextFieldDefaults.colors(
                    focusedBorderColor = Palette.brand,
                    unfocusedBorderColor = Palette.textSecondary(dark).copy(alpha = 0.4f)
                )
            )

            Spacer(Modifier.height(12.dp))

            Button(
                onClick = { go(query) },
                enabled = query.isNotBlank(),
                modifier = Modifier
                    .fillMaxWidth()
                    .height(52.dp),
                shape = RoundedCornerShape(16.dp),
                colors = ButtonDefaults.buttonColors(containerColor = Palette.brand)
            ) {
                Icon(Icons.Filled.DirectionsTransit, contentDescription = null, modifier = Modifier.size(20.dp))
                Spacer(Modifier.width(8.dp))
                Text("Ir con indicaciones", fontWeight = FontWeight.Bold)
            }
        }

        LazyColumn(
            modifier = Modifier.fillMaxSize(),
            contentPadding = PaddingValues(horizontal = 16.dp, vertical = 20.dp),
            verticalArrangement = Arrangement.spacedBy(20.dp)
        ) {
            if (recents.isEmpty()) {
                item {
                    EmptyState(
                        icon = Icons.Filled.Explore,
                        title = "¿A dónde vas?",
                        message = "Escribí un destino. Te llevamos con indicaciones de transporte público en Google Maps."
                    )
                }
            } else {
                item { SectionHeader(title = "Recientes") }
                items(recents, key = { it }) { recent ->
                    ComoLlegoRecentRow(text = recent, dark = dark, onClick = { go(recent) })
                }
            }

            item { SectionHeader(title = "Ejemplos") }
            item {
                LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    items(comoLlegoExamples) { example ->
                        ComoLlegoExampleChip(text = example, dark = dark, onClick = { query = example })
                    }
                }
            }
        }
    }
}

private val comoLlegoExamples = listOf("Obelisco", "Aeroparque", "Ezeiza", "Tribunales", "Palermo", "Once")

@Composable
private fun ComoLlegoRecentRow(text: String, dark: Boolean, onClick: () -> Unit) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(14.dp),
        colors = CardDefaults.cardColors(containerColor = Palette.surface(dark))
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(12.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Icon(Icons.Filled.History, contentDescription = null, tint = Palette.textSecondary(dark))
            Text(
                text = text,
                style = MaterialTheme.typography.bodyLarge,
                fontWeight = FontWeight.SemiBold,
                color = Palette.textPrimary(dark),
                modifier = Modifier.weight(1f)
            )
            IconButton(onClick = onClick) {
                Icon(Icons.Filled.NearMe, contentDescription = "Ir", tint = Palette.brand)
            }
        }
    }
}

@Composable
private fun ComoLlegoExampleChip(text: String, dark: Boolean, onClick: () -> Unit) {
    Surface(
        onClick = onClick,
        shape = CircleShape,
        color = Palette.elevated(dark)
    ) {
        Text(
            text = text,
            style = MaterialTheme.typography.labelLarge,
            fontWeight = FontWeight.SemiBold,
            color = Palette.textSecondary(dark),
            modifier = Modifier.padding(horizontal = 14.dp, vertical = 8.dp)
        )
    }
}

// Abre Google Maps con indicaciones de transporte público hacia el texto
// tipeado. Sin geocoding propio: la resolución del destino la hace Maps.
private fun openTransitDirections(context: Context, query: String) {
    val uri = Uri.parse(
        "https://www.google.com/maps/dir/?api=1&destination=${Uri.encode(query)}&travelmode=transit"
    )
    val intent = Intent(Intent.ACTION_VIEW, uri).apply {
        flags = Intent.FLAG_ACTIVITY_NEW_TASK
    }
    context.startActivity(intent)
}

// Persistencia liviana de destinos recientes en SharedPreferences.
private object ComoLlegoRecentsStore {
    private const val PREFS = "anden.comollego"
    private const val KEY = "recents"
    private const val LIMIT = 6
    private const val SEPARATOR = ""

    fun load(context: Context): List<String> {
        val raw = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(KEY, null)
            ?: return emptyList()
        return raw.split(SEPARATOR).filter { it.isNotBlank() }
    }

    fun record(context: Context, query: String): List<String> {
        val current = load(context).toMutableList()
        current.removeAll { it.equals(query, ignoreCase = true) }
        current.add(0, query)
        val trimmed = current.take(LIMIT)
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY, trimmed.joinToString(SEPARATOR))
            .apply()
        return trimmed
    }
}
