package com.alandaitch.anden.ui.onboarding

import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
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
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Bolt
import androidx.compose.material.icons.filled.MyLocation
import androidx.compose.material.icons.filled.Train
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.alandaitch.anden.data.store.AppSettings
import com.alandaitch.anden.ui.theme.Palette
import kotlinx.coroutines.launch

// Onboarding de 3 páginas: qué hace Andén, valor honesto de la ubicación,
// y CTA final. No dispara el permiso real acá: eso lo hace la integración
// después de onDone(). Esta pantalla solo marca onboardingDone=true.
@OptIn(ExperimentalFoundationApi::class)
@Composable
fun OnboardingScreen(onDone: () -> Unit) {
    val dark = isSystemInDarkTheme()
    val pages = remember { onboardingPages() }
    val pagerState = rememberPagerState(pageCount = { pages.size })
    val scope = rememberCoroutineScope()
    val isLastPage = pagerState.currentPage == pages.lastIndex

    fun finish() {
        AppSettings.shared.onboardingDone = true
        onDone()
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Palette.background(dark))
    ) {
        Column(modifier = Modifier.fillMaxSize()) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(44.dp),
                horizontalArrangement = Arrangement.End
            ) {
                if (!isLastPage) {
                    TextButton(onClick = { finish() }) {
                        Text("Omitir", color = Palette.textSecondary(dark))
                    }
                }
            }

            HorizontalPager(
                state = pagerState,
                modifier = Modifier.weight(1f)
            ) { page ->
                OnboardingPageContent(page = pages[page], dark = dark)
            }

            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 8.dp),
                horizontalArrangement = Arrangement.Center
            ) {
                pages.indices.forEach { index ->
                    val selected = index == pagerState.currentPage
                    Box(
                        modifier = Modifier
                            .padding(horizontal = 4.dp)
                            .height(8.dp)
                            .width(if (selected) 22.dp else 8.dp)
                            .background(
                                color = if (selected) Palette.brand else Palette.textSecondary(dark).copy(alpha = 0.3f),
                                shape = CircleShape
                            )
                    )
                }
            }

            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 24.dp)
                    .padding(top = 20.dp, bottom = 32.dp),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                if (isLastPage) {
                    Button(
                        onClick = { finish() },
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(52.dp),
                        shape = RoundedCornerShape(16.dp),
                        colors = ButtonDefaults.buttonColors(containerColor = Palette.brand)
                    ) {
                        Text("Activar ubicación", fontWeight = FontWeight.Bold, color = Color.White)
                    }
                    Spacer(Modifier.height(12.dp))
                    TextButton(onClick = { finish() }) {
                        Text("Ahora no", color = Palette.textSecondary(dark))
                    }
                } else {
                    Button(
                        onClick = {
                            scope.launch {
                                pagerState.animateScrollToPage(pagerState.currentPage + 1)
                            }
                        },
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(52.dp),
                        shape = RoundedCornerShape(16.dp),
                        colors = ButtonDefaults.buttonColors(containerColor = Palette.brand)
                    ) {
                        Text("Seguir", fontWeight = FontWeight.Bold, color = Color.White)
                    }
                }
            }
        }
    }
}

private data class OnboardingPage(val icon: ImageVector, val title: String, val message: String)

private fun onboardingPages(): List<OnboardingPage> = listOf(
    OnboardingPage(
        icon = Icons.Filled.Train,
        title = "Tu tren, en vivo.",
        message = "Arribos en tiempo real de las líneas del AMBA. Demora real, andén y minutos exactos."
    ),
    OnboardingPage(
        icon = Icons.Filled.MyLocation,
        title = "Sabemos dónde estás parado",
        message = "Con tu ubicación te mostramos las estaciones más cercanas. La usamos solo mientras usás la app. Nunca la compartimos."
    ),
    OnboardingPage(
        icon = Icons.Filled.Bolt,
        title = "Empecemos",
        message = "Activá tu ubicación para ver tus estaciones cercanas apenas abrís Andén."
    )
)

@Composable
private fun OnboardingPageContent(page: OnboardingPage, dark: Boolean) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = 32.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Box(
            modifier = Modifier
                .size(140.dp)
                .background(Palette.brand.copy(alpha = 0.18f), CircleShape),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                imageVector = page.icon,
                contentDescription = null,
                tint = Palette.brand,
                modifier = Modifier.size(54.dp)
            )
        }

        Spacer(Modifier.height(28.dp))

        Text(
            text = page.title,
            style = MaterialTheme.typography.headlineMedium,
            fontWeight = FontWeight.Bold,
            color = Palette.textPrimary(dark),
            textAlign = TextAlign.Center
        )

        Spacer(Modifier.height(12.dp))

        Text(
            text = page.message,
            style = MaterialTheme.typography.bodyLarge,
            color = Palette.textSecondary(dark),
            textAlign = TextAlign.Center
        )
    }
}
