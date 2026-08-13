import SwiftUI

// Línea de tren. id == gerenciaId de la API SOFSE.
struct TrainLine: Identifiable, Hashable {
    let id: Int
    let nombre: String
    let shortCode: String
    let colorHex: String
    let covered: Bool

    var color: Color { Color(hex: colorHex) }
}

extension TrainLine {
    // Las 9 líneas de lineas.json + paleta del PLAN.
    static let all: [TrainLine] = [
        TrainLine(id: 1,   nombre: "Sarmiento",        shortCode: "SA", colorHex: "#B83280", covered: true),
        TrainLine(id: 5,   nombre: "Mitre",            shortCode: "MI", colorHex: "#1E7FD4", covered: true),
        TrainLine(id: 11,  nombre: "Roca",             shortCode: "RO", colorHex: "#16A34A", covered: true),
        TrainLine(id: 21,  nombre: "Belgrano Sur",     shortCode: "BS", colorHex: "#EAB308", covered: true),
        TrainLine(id: 31,  nombre: "San Martín",       shortCode: "SM", colorHex: "#E0632B", covered: true),
        TrainLine(id: 41,  nombre: "Tren de la Costa", shortCode: "TC", colorHex: "#0D9488", covered: true),
        TrainLine(id: 61,  nombre: "Belgrano Norte",   shortCode: "BN", colorHex: "#8A94A6", covered: false),
        TrainLine(id: 71,  nombre: "Urquiza",          shortCode: "UR", colorHex: "#8A94A6", covered: false),
        TrainLine(id: 501, nombre: "Regionales",       shortCode: "RG", colorHex: "#7C5CFC", covered: true),
    ]

    static let unknown = TrainLine(id: -1, nombre: "Sin línea", shortCode: "?", colorHex: "#8A94A6", covered: false)

    static func line(id: Int) -> TrainLine {
        all.first { $0.id == id } ?? .unknown
    }

    static func line(nombre: String?) -> TrainLine {
        guard let nombre else { return .unknown }
        let q = nombre.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "es"))
        return all.first {
            $0.nombre.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "es")) == q
        } ?? .unknown
    }
}
