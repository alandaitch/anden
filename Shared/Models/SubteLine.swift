import SwiftUI

// Línea de subte (SBASE). routeId == Route_Id de forecastGTFS.
// Colores oficiales SBASE (ver docs/ba-api.md).
struct SubteLine: Identifiable, Hashable {
    let routeId: String   // "LineaA".."LineaH","Premetro"
    let letra: String     // "A".."H","P"
    let nombre: String
    let colorHex: String

    var id: String { routeId }
    var color: Color { Color(hex: colorHex) }
}

extension SubteLine {
    // Las 6 líneas + premetro con la paleta oficial.
    static let all: [SubteLine] = [
        SubteLine(routeId: "LineaA",   letra: "A", nombre: "Línea A",  colorHex: "#00AEEF"),
        SubteLine(routeId: "LineaB",   letra: "B", nombre: "Línea B",  colorHex: "#EE3124"),
        SubteLine(routeId: "LineaC",   letra: "C", nombre: "Línea C",  colorHex: "#0072BC"),
        SubteLine(routeId: "LineaD",   letra: "D", nombre: "Línea D",  colorHex: "#00A650"),
        SubteLine(routeId: "LineaE",   letra: "E", nombre: "Línea E",  colorHex: "#8E44AD"),
        SubteLine(routeId: "LineaH",   letra: "H", nombre: "Línea H",  colorHex: "#FFD200"),
        SubteLine(routeId: "Premetro", letra: "P", nombre: "Premetro", colorHex: "#00A19A"),
    ]

    static let unknown = SubteLine(routeId: "?", letra: "?", nombre: "Subte", colorHex: "#8A94A6")

    // Busca por routeId. Fallback: deriva la letra del sufijo ("LineaX" -> "X").
    static func line(routeId: String) -> SubteLine {
        if let match = all.first(where: { $0.routeId.caseInsensitiveCompare(routeId) == .orderedSame }) {
            return match
        }
        let suffix = routeId.replacingOccurrences(of: "Linea", with: "", options: .caseInsensitive)
        let letra = suffix.isEmpty ? "?" : String(suffix.prefix(1)).uppercased()
        return SubteLine(routeId: routeId, letra: letra, nombre: routeId, colorHex: "#8A94A6")
    }
}
