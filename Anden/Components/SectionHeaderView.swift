import SwiftUI

// Encabezado de sección: título y subtítulo opcional.
struct SectionHeaderView: View {
    let title: String
    var subtitle: String?

    init(title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.anden(20, weight: .bold))
                .foregroundStyle(Palette.textPrimary)
            if let subtitle {
                Text(subtitle)
                    .font(.anden(13, weight: .medium))
                    .foregroundStyle(Palette.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    VStack(spacing: 20) {
        SectionHeaderView(title: "Próximos trenes")
        SectionHeaderView(title: "Cercanas", subtitle: "Ordenadas por distancia")
    }
    .padding()
    .background(Palette.background)
}
