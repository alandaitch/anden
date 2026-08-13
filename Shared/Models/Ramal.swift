import Foundation

// Ramal de una línea (lineas.json -> ramales).
struct Ramal: Identifiable, Codable, Hashable {
    let id: Int
    let nombre: String?
    let siglas: String?
    let cabeceras: [String]
    let cabeceraInicialId: Int?
    let cabeceraFinalId: Int?
    let estaciones: Int?
    let esElectrico: Bool
    let operativo: Bool
    let toleranciaPuntualidadSegundos: Int?
    let tipoId: Int?

    var tolerancia: Int { toleranciaPuntualidadSegundos ?? DelayLogic.defaultTolerance }
    var displayName: String { nombre ?? cabeceras.joined(separator: "-") }
}
