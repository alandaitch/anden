package com.alandaitch.anden.ui

import android.net.Uri
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Map
import androidx.compose.material.icons.filled.NearMe
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.outlined.Map
import androidx.compose.material.icons.outlined.NearMe
import androidx.compose.material.icons.outlined.Notifications
import androidx.compose.material.icons.outlined.Settings
import androidx.compose.material.icons.outlined.StarBorder
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationBarItemDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import com.alandaitch.anden.ui.alerts.AlertsScreen
import com.alandaitch.anden.ui.board.StationBoardScreen
import com.alandaitch.anden.ui.cerca.CercaScreen
import com.alandaitch.anden.ui.colectivo.ColectivoStopBoardScreen
import com.alandaitch.anden.ui.comollego.ComoLlegoScreen
import com.alandaitch.anden.ui.ecobici.EcobiciScreen
import com.alandaitch.anden.ui.favorites.FavoritesScreen
import com.alandaitch.anden.ui.map.MapScreen
import com.alandaitch.anden.ui.settings.SettingsScreen
import com.alandaitch.anden.ui.subte.SubteStationBoardScreen
import com.alandaitch.anden.ui.theme.andenColors

// Rutas de las cinco solapas inferiores.
private object Tab {
    const val CERCA = "cerca"
    const val FAVORITOS = "favoritos"
    const val MAPA = "mapa"
    const val ALERTAS = "alertas"
    const val AJUSTES = "ajustes"
}

private data class TabItem(
    val route: String,
    val label: String,
    val selectedIcon: ImageVector,
    val icon: ImageVector,
)

private val TABS = listOf(
    TabItem(Tab.CERCA, "Cerca", Icons.Filled.NearMe, Icons.Outlined.NearMe),
    TabItem(Tab.FAVORITOS, "Favoritos", Icons.Filled.Star, Icons.Outlined.StarBorder),
    TabItem(Tab.MAPA, "Mapa", Icons.Filled.Map, Icons.Outlined.Map),
    TabItem(Tab.ALERTAS, "Alertas", Icons.Filled.Notifications, Icons.Outlined.Notifications),
    TabItem(Tab.AJUSTES, "Ajustes", Icons.Filled.Settings, Icons.Outlined.Settings),
)

// Navegación raíz: NavigationBar inferior + NavHost con rutas de detalle.
@Composable
fun RootScreen() {
    val colors = andenColors()
    val navController = rememberNavController()

    val backStackEntry by navController.currentBackStackEntryAsState()
    val currentRoute = backStackEntry?.destination?.route
    val showBar = TABS.any { it.route == currentRoute }

    // Navega a una estación de tren (tablero).
    val goTren: (Int) -> Unit = { id -> navController.navigate("board/$id") }
    // Navega a un tablero de subte (nombre + routeId opcional).
    val goSubte: (String, String?) -> Unit = { name, routeId ->
        val enc = Uri.encode(name)
        navController.navigate("subte/$enc?routeId=${routeId ?: ""}")
    }

    Scaffold(
        containerColor = colors.background,
        bottomBar = {
            if (showBar) {
                NavigationBar(containerColor = colors.surface) {
                    TABS.forEach { tab ->
                        val selected = currentRoute == tab.route
                        NavigationBarItem(
                            selected = selected,
                            onClick = {
                                navController.navigate(tab.route) {
                                    popUpTo(navController.graph.findStartDestination().id) {
                                        saveState = true
                                    }
                                    launchSingleTop = true
                                    restoreState = true
                                }
                            },
                            icon = {
                                Icon(
                                    imageVector = if (selected) tab.selectedIcon else tab.icon,
                                    contentDescription = tab.label,
                                )
                            },
                            label = {
                                Text(tab.label, fontSize = 11.sp, fontWeight = FontWeight.SemiBold)
                            },
                            colors = NavigationBarItemDefaults.colors(
                                selectedIconColor = colors.brand,
                                selectedTextColor = colors.brand,
                                indicatorColor = colors.brand.copy(alpha = 0.16f),
                                unselectedIconColor = colors.textSecondary,
                                unselectedTextColor = colors.textSecondary,
                            ),
                        )
                    }
                }
            }
        },
    ) { innerPadding ->
        NavHost(
            navController = navController,
            startDestination = Tab.CERCA,
            modifier = Modifier.padding(innerPadding),
        ) {
            // --- Solapas ---
            composable(Tab.CERCA) {
                CercaScreen(
                    onOpenTren = goTren,
                    onOpenSubte = goSubte,
                    onOpenBici = { navController.navigate("bici") },
                    onOpenBondi = { code -> navController.navigate("bondi/${Uri.encode(code)}") },
                    onComoLlego = { navController.navigate("comollego") },
                )
            }
            composable(Tab.FAVORITOS) {
                FavoritesScreen(onOpenTren = goTren)
            }
            composable(Tab.MAPA) {
                MapScreen(onOpenTren = goTren, onOpenSubte = goSubte)
            }
            composable(Tab.ALERTAS) {
                AlertsScreen()
            }
            composable(Tab.AJUSTES) {
                SettingsScreen()
            }

            // --- Rutas de detalle ---
            composable(
                route = "board/{id}",
                arguments = listOf(navArgument("id") { type = NavType.IntType }),
            ) { entry ->
                val id = entry.arguments?.getInt("id") ?: return@composable
                StationBoardScreen(stationId = id, onBack = { navController.popBackStack() })
            }
            composable(
                route = "subte/{name}?routeId={routeId}",
                arguments = listOf(
                    navArgument("name") { type = NavType.StringType },
                    navArgument("routeId") {
                        type = NavType.StringType
                        defaultValue = ""
                    },
                ),
            ) { entry ->
                val name = entry.arguments?.getString("name").orEmpty()
                val routeId = entry.arguments?.getString("routeId")?.takeIf { it.isNotEmpty() }
                SubteStationBoardScreen(stationName = name, routeId = routeId)
            }
            composable("bici") {
                EcobiciScreen()
            }
            composable(
                route = "bondi/{code}",
                arguments = listOf(navArgument("code") { type = NavType.StringType }),
            ) { entry ->
                val code = entry.arguments?.getString("code").orEmpty()
                ColectivoStopBoardScreen(stopCode = code)
            }
            composable("comollego") {
                ComoLlegoScreen(onBack = { navController.popBackStack() })
            }
        }
    }
}
