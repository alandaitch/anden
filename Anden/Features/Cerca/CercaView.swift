import SwiftUI

// Contenedor multimodal "Cerca". Un solo NavigationStack y un selector segmentado
// arriba con [Tren · Subte · Bici]. Cada modo muestra su feature sin stack propio.
struct CercaView: View {
    @AppStorage("cercaMode") private var storedMode: Int = CercaMode.tren.rawValue
    @State private var path = NavigationPath()

    private var mode: CercaMode {
        CercaMode(rawValue: storedMode) ?? .tren
    }

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                modePicker
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 4)

                modeContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(Palette.background)
        }
    }

    private var modePicker: some View {
        Picker("Modo", selection: modeBinding) {
            ForEach(CercaMode.allCases) { m in
                Text(m.title).tag(m)
            }
        }
        .pickerStyle(.segmented)
    }

    // Al cambiar de modo, limpiamos el path para no arrastrar destinos de otro feature.
    private var modeBinding: Binding<CercaMode> {
        Binding(
            get: { mode },
            set: { newValue in
                if newValue != mode {
                    path = NavigationPath()
                    storedMode = newValue.rawValue
                }
            }
        )
    }

    @ViewBuilder
    private var modeContent: some View {
        switch mode {
        case .tren:
            NearbyContent(path: $path)
        case .subte:
            SubteHomeView()
        case .bici:
            EcobiciNearbyView()
        }
    }
}

enum CercaMode: Int, CaseIterable, Identifiable {
    case tren
    case subte
    case bici

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .tren:  return "Tren"
        case .subte: return "Subte"
        case .bici:  return "Bici"
        }
    }
}
