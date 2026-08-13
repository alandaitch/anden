import SwiftUI

// Raíz de la app. TabView con 5 pestañas.
// Cada vista de feature trae su propio NavigationStack y registra sus destinos
// (Station -> StationBoardView; ServiceDetail se empuja/presenta desde adentro).
// Por eso las montamos directo, sin envolver en otro NavigationStack.
struct RootView: View {
    var body: some View {
        TabView {
            CercaView()
                .tabItem { Label("Cerca", systemImage: "location.fill") }

            FavoritesView()
                .tabItem { Label("Favoritos", systemImage: "star.fill") }

            NetworkMapView()
                .tabItem { Label("Mapa", systemImage: "map.fill") }

            AlertsView()
                .tabItem { Label("Alertas", systemImage: "exclamationmark.triangle.fill") }

            SettingsView()
                .tabItem { Label("Ajustes", systemImage: "gearshape.fill") }
        }
        .tint(Palette.brand)
    }
}
