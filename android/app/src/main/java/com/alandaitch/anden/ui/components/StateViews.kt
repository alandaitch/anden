package com.alandaitch.anden.ui.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.WifiOff
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.alandaitch.anden.ui.theme.Palette
import com.alandaitch.anden.ui.theme.andenColors

// Encabezado de sección: título y subtítulo opcional.
@Composable
fun SectionHeader(title: String, modifier: Modifier = Modifier, subtitle: String? = null) {
    val colors = andenColors()
    Column(modifier = modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(2.dp)) {
        Text(title, color = colors.textPrimary, fontWeight = FontWeight.Bold, fontSize = 20.sp)
        if (subtitle != null) {
            Text(subtitle, color = colors.textSecondary, fontWeight = FontWeight.Medium, fontSize = 13.sp)
        }
    }
}

// Estado vacío con ícono, título, mensaje y acción opcional.
@Composable
fun EmptyState(
    icon: ImageVector,
    title: String,
    message: String,
    modifier: Modifier = Modifier,
    actionTitle: String? = null,
    onAction: (() -> Unit)? = null,
) {
    val colors = andenColors()
    Column(
        modifier = modifier
            .fillMaxWidth()
            .padding(28.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Icon(icon, contentDescription = null, tint = colors.textSecondary, modifier = Modifier.size(46.dp))
        Text(title, color = colors.textPrimary, fontWeight = FontWeight.Bold, fontSize = 19.sp, textAlign = TextAlign.Center)
        Text(message, color = colors.textSecondary, fontSize = 14.sp, textAlign = TextAlign.Center)
        if (actionTitle != null && onAction != null) {
            PillButton(text = actionTitle, onClick = onAction)
        }
    }
}

// Estado de carga con spinner y mensaje.
@Composable
fun LoadingState(modifier: Modifier = Modifier, message: String = "Buscando trenes…") {
    val colors = andenColors()
    Column(
        modifier = modifier
            .fillMaxWidth()
            .padding(28.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        CircularProgressIndicator(color = colors.brand)
        Text(message, color = colors.textSecondary, fontWeight = FontWeight.Medium, fontSize = 14.sp, textAlign = TextAlign.Center)
    }
}

// Estado de error con reintento opcional.
@Composable
fun ErrorState(message: String, modifier: Modifier = Modifier, onRetry: (() -> Unit)? = null) {
    val colors = andenColors()
    Column(
        modifier = modifier
            .fillMaxWidth()
            .padding(28.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Icon(Icons.Filled.WifiOff, contentDescription = null, tint = Palette.majorDelay, modifier = Modifier.size(42.dp))
        Text("No pudimos cargar", color = colors.textPrimary, fontWeight = FontWeight.Bold, fontSize = 18.sp)
        Text(message, color = colors.textSecondary, fontSize = 14.sp, textAlign = TextAlign.Center)
        if (onRetry != null) {
            PillButton(text = "Reintentar", onClick = onRetry, icon = Icons.Filled.Refresh)
        }
    }
}

// Botón cápsula de marca, reutilizado por los estados.
@Composable
internal fun PillButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    icon: ImageVector? = null,
) {
    val colors = andenColors()
    Button(
        onClick = onClick,
        modifier = modifier,
        shape = CircleShape,
        colors = ButtonDefaults.buttonColors(containerColor = colors.brand, contentColor = Color.White),
    ) {
        if (icon != null) {
            Icon(icon, contentDescription = null, tint = Color.White, modifier = Modifier.size(16.dp).padding(end = 0.dp))
            Text("  ")
        }
        Text(text, fontWeight = FontWeight.SemiBold, fontSize = 15.sp)
    }
}
