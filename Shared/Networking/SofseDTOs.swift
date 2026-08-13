import Foundation

// DTOs internos de decodificación. Cubren los dos esquemas de /arribos (vivo y horario)
// y las alertas embebidas en /infraestructura.

// Valor JSON de tipo desconocido. Solo sirve para detectar presencia (ej: cancelacion).
struct AnyJSON: Decodable {
    init(from decoder: Decoder) throws {
        if let c = try? decoder.singleValueContainer() { _ = c.decodeNil() }
    }
}

struct ArribosResponse: Decodable {
    let timestamp: Int?
    let results: [ResultDTO]?
    let total: Int?
}

struct ResultDTO: Decodable {
    let arribo: ArriboDTO?
    let servicio: ServicioDTO?
}

struct ArriboDTO: Decodable {
    let orden: Int?
    let nombre: String?
    let idElemento: Int?
    let segundos: Int?
    let anden: AndenDTO?
    let equipo: EquipoDTO?
    let llegada: TimingDTO?
    let salida: TimingDTO?
}

struct AndenDTO: Decodable {
    let id: Int?
    let nombre: String?
}

struct EquipoDTO: Decodable {
    let id: Int?
    let nombre: String?
    let esElectrico: Int?
    let gpss: [String]?
}

struct TimingDTO: Decodable {
    let programada: String?
    let estimada: String?
    let real: String?
    let latitud: Double?
    let longitud: Double?
}

struct LocationDTO: Decodable {
    let lat: Double?
    let long: Double?
}

struct GerenciaRefDTO: Decodable {
    let id: Int?
    let nombre: String?
}

struct EstadoDTO: Decodable {
    let id: Int?
    let nombre: String?
}

struct DesdeDTO: Decodable {
    let estado: EstadoDTO?
}

// Cabecera de ramal. Maneja nombreCorto (vivo) y nombre_corto (horario).
struct CabeceraDTO: Decodable {
    let id: Int?
    let nombre: String?
    let nombreCorto: String?

    enum K: String, CodingKey { case id, nombre, nombreCorto, nombre_corto }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: K.self)
        id = try? c.decodeIfPresent(Int.self, forKey: .id) ?? nil
        nombre = try? c.decodeIfPresent(String.self, forKey: .nombre) ?? nil
        let camel = (try? c.decodeIfPresent(String.self, forKey: .nombreCorto) ?? nil) ?? nil
        let snake = (try? c.decodeIfPresent(String.self, forKey: .nombre_corto) ?? nil) ?? nil
        nombreCorto = camel ?? snake
    }

    var display: String { nombreCorto ?? nombre ?? "" }
}

struct RamalRefDTO: Decodable {
    let id: Int?
    let nombre: String?
    let siglas: String?
    let tolerancia: Int?
    let cabeceraInicial: CabeceraDTO?
    let cabeceraFinal: CabeceraDTO?
}

struct EstacionRecorridoDTO: Decodable {
    let idElemento: Int?
    let nombre: String?
    let orden: Int?
    let anden: AndenDTO?
    let llegada: TimingDTO?
    let salida: TimingDTO?
}

struct ServicioDTO: Decodable {
    let id: String?
    let numero: Int?
    let sentido: Int?
    let cancelacion: AnyJSON?
    let location: LocationDTO?
    let gerencia: GerenciaRefDTO?
    let ramal: RamalRefDTO?
    let desde: DesdeDTO?
    let estaciones: [EstacionRecorridoDTO]?
}

// --- Alertas ---

struct GerenciaAlertDTO: Decodable {
    let id: Int?
    let alerta: [AlertaDTO]?
}

struct RamalAlertDTO: Decodable {
    let id: Int?
    let alerta: AlertaDTO?
}

struct AlertaDTO: Decodable {
    let id: Int?
    let linea_id: Int?
    let ramal_id: Int?
    let causa_gtfs: String?
    let efecto_gtfs: String?
    let contenido: String?
    let criticidad_orden: Int?
    let vigencia_desde: String?
    let vigencia_hasta: String?
}

extension ServiceAlert {
    init(dto: AlertaDTO) {
        self.init(
            id: dto.id ?? abs((dto.contenido ?? UUID().uuidString).hashValue),
            lineId: dto.linea_id,
            ramalId: dto.ramal_id,
            causeGTFS: dto.causa_gtfs ?? "OTHER_CAUSE",
            effectGTFS: dto.efecto_gtfs ?? "OTHER_EFFECT",
            content: dto.contenido ?? "",
            criticality: dto.criticidad_orden ?? 99,
            validFrom: SofseDate.alert(dto.vigencia_desde),
            validUntil: SofseDate.alert(dto.vigencia_hasta)
        )
    }
}
