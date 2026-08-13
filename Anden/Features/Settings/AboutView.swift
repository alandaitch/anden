import SwiftUI

// Detalle honesto de los límites de la app. Sin vueltas, sin promesas falsas.
struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                sectionBlock(
                    title: "Cómo funciona",
                    items: [
                        "Andén no tiene servidor propio.",
                        "Por eso no manda notificaciones push en tiempo real.",
                        "Los avisos de demora son de mejor esfuerzo.",
                        "iOS decide cuándo revisa en segundo plano. No hay horario fijo.",
                        "Una demora puede tardar en avisarse. A veces no se avisa.",
                        "El widget y el countdown en pantalla se actualizan cuando abrís la app.",
                        "El presupuesto de actualización en background lo fija iOS, no Andén."
                    ]
                )

                sectionBlock(
                    title: "Cobertura",
                    items: [
                        "Belgrano Norte y Urquiza no están en esta fuente de datos.",
                        "Las opera Ferrovías y Metrovías, fuera de la API de SOFSE.",
                        "Las demás líneas del AMBA sí tienen datos en vivo."
                    ]
                )

                sectionBlock(
                    title: "Datos",
                    items: [
                        "La fuente es la API pública de Trenes Argentinos (SOFSE).",
                        "El catálogo tiene 360 estaciones del AMBA.",
                        "Andén es una app no oficial. No tiene relación con SOFSE ni con el Estado."
                    ]
                )
            }
            .padding(20)
        }
        .background(Palette.background)
        .navigationTitle("Acerca de Andén")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func sectionBlock(title: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.anden(20, weight: .bold))
                .foregroundStyle(Palette.textPrimary)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(items, id: \.self) { item in
                    HStack(alignment: .top, spacing: 10) {
                        Circle()
                            .fill(Palette.brand)
                            .frame(width: 6, height: 6)
                            .padding(.top, 7)
                        Text(item)
                            .font(.anden(15))
                            .foregroundStyle(Palette.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .andenCard()
    }
}
