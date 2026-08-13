import Foundation
import CoreLocation

// Decoder manual de protobuf para GTFS-realtime (FeedMessage), sin librerías.
// Solo lee lo que la app usa: vehiclePositions. Ver docs/colectivos-data.md.
//
// Wire format: cada campo arranca con un tag = (field << 3) | wire.
// wire: 0=varint, 1=64bit LE, 2=length-delimited, 5=32bit LE.
// Se lee por tag y se saltan los desconocidos por su wire type.

// Cursor sobre un rango [pos, end) de bytes. Lee tags y payloads.
private struct ProtoCursor {
    let bytes: [UInt8]
    var pos: Int
    let end: Int

    init(_ bytes: [UInt8], _ start: Int, _ end: Int) {
        self.bytes = bytes
        self.pos = start
        self.end = end
    }

    // Un campo leído del stream. Solo se completa el payload de su wire type.
    struct Field {
        let number: Int
        let wire: Int
        var varint: UInt64 = 0
        var fixed32: UInt32 = 0
        var fixed64: UInt64 = 0
        var lenStart: Int = 0
        var lenEnd: Int = 0
    }

    mutating func readVarint() -> UInt64? {
        var result: UInt64 = 0
        var shift: UInt64 = 0
        while pos < end {
            let b = bytes[pos]
            pos += 1
            result |= UInt64(b & 0x7F) << shift
            if b & 0x80 == 0 { return result }
            shift += 7
            if shift >= 64 { return nil }
        }
        return nil
    }

    // Lee el próximo campo. Avanza el cursor incluso si el caller lo ignora,
    // así se saltan los tags desconocidos. nil = fin o dato corrupto.
    mutating func next() -> Field? {
        guard pos < end, let tag = readVarint() else { return nil }
        let number = Int(tag >> 3)
        let wire = Int(tag & 0x7)
        var f = Field(number: number, wire: wire)
        switch wire {
        case 0:
            guard let v = readVarint() else { return nil }
            f.varint = v
        case 1:
            guard pos + 8 <= end else { return nil }
            var v: UInt64 = 0
            for i in 0..<8 { v |= UInt64(bytes[pos + i]) << (8 * i) }
            pos += 8
            f.fixed64 = v
        case 2:
            guard let len = readVarint() else { return nil }
            let start = pos
            let e = pos + Int(len)
            guard e <= end else { return nil }
            f.lenStart = start
            f.lenEnd = e
            pos = e
        case 5:
            guard pos + 4 <= end else { return nil }
            var v: UInt32 = 0
            for i in 0..<4 { v |= UInt32(bytes[pos + i]) << (8 * i) }
            pos += 4
            f.fixed32 = v
        default:
            return nil // wire type desconocido: no se puede continuar seguro
        }
        return f
    }
}

private func protoString(_ bytes: [UInt8], _ start: Int, _ end: Int) -> String? {
    guard start <= end, end <= bytes.count else { return nil }
    return String(bytes: bytes[start..<end], encoding: .utf8)
}

// Parsea un FeedMessage y devuelve las posiciones de vehículos con coordenada válida.
func parseVehiclePositions(_ data: Data) -> [BusPosition] {
    let bytes = [UInt8](data)
    var out: [BusPosition] = []
    var cursor = ProtoCursor(bytes, 0, bytes.count)
    // Top level: field 2 (0x12) LEN = FeedEntity (repetido).
    while let f = cursor.next() {
        if f.number == 2, f.wire == 2 {
            if let bp = parseFeedEntity(bytes, f.lenStart, f.lenEnd) {
                out.append(bp)
            }
        }
    }
    return out
}

// FeedEntity: field 1 (0x0A) id; field 4 (0x22) VehiclePosition.
private func parseFeedEntity(_ bytes: [UInt8], _ start: Int, _ end: Int) -> BusPosition? {
    var c = ProtoCursor(bytes, start, end)
    var entityId: String?
    var vpStart = -1
    var vpEnd = -1
    while let f = c.next() {
        switch (f.number, f.wire) {
        case (1, 2): entityId = protoString(bytes, f.lenStart, f.lenEnd)
        case (4, 2): vpStart = f.lenStart; vpEnd = f.lenEnd
        default: break
        }
    }
    guard vpStart >= 0 else { return nil }
    return parseVehiclePosition(bytes, vpStart, vpEnd, entityId: entityId)
}

// VehiclePosition: field 1 trip; field 2 position; field 8 vehicle descriptor.
private func parseVehiclePosition(_ bytes: [UInt8], _ start: Int, _ end: Int, entityId: String?) -> BusPosition? {
    var c = ProtoCursor(bytes, start, end)
    var routeId: String?
    var lat: Double?
    var lng: Double?
    var bearing: Double?
    var interno: String?
    var patente: String?

    while let f = c.next() {
        switch (f.number, f.wire) {
        case (1, 2): // TripDescriptor
            routeId = parseTripRouteId(bytes, f.lenStart, f.lenEnd)
        case (2, 2): // Position
            let p = parsePosition(bytes, f.lenStart, f.lenEnd)
            lat = p.lat; lng = p.lng; bearing = p.bearing
        case (8, 2): // VehicleDescriptor
            let v = parseVehicleDescriptor(bytes, f.lenStart, f.lenEnd)
            interno = v.id; patente = v.patente
        default:
            break
        }
    }

    guard let lat, let lng else { return nil }
    let id = entityId ?? interno ?? UUID().uuidString
    return BusPosition(
        id: id,
        coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng),
        routeId: routeId,
        bearing: bearing,
        interno: interno,
        patente: patente
    )
}

// TripDescriptor: field 5 (0x2A) route_id.
private func parseTripRouteId(_ bytes: [UInt8], _ start: Int, _ end: Int) -> String? {
    var c = ProtoCursor(bytes, start, end)
    var routeId: String?
    while let f = c.next() {
        if f.number == 5, f.wire == 2 {
            routeId = protoString(bytes, f.lenStart, f.lenEnd)
        }
    }
    return routeId
}

// Position: field 1 lat, field 2 lng (fixed32 float LE); field 3 bearing (opcional);
// field 4 odometer (64bit) se ignora.
private func parsePosition(_ bytes: [UInt8], _ start: Int, _ end: Int) -> (lat: Double?, lng: Double?, bearing: Double?) {
    var c = ProtoCursor(bytes, start, end)
    var lat: Double?
    var lng: Double?
    var bearing: Double?
    while let f = c.next() {
        switch (f.number, f.wire) {
        case (1, 5): lat = Double(Float(bitPattern: f.fixed32))
        case (2, 5): lng = Double(Float(bitPattern: f.fixed32))
        case (3, 5): bearing = Double(Float(bitPattern: f.fixed32))
        default: break
        }
    }
    return (lat, lng, bearing)
}

// VehicleDescriptor: field 1 id (interno); field 2 label; field 3 license_plate (patente).
private func parseVehicleDescriptor(_ bytes: [UInt8], _ start: Int, _ end: Int) -> (id: String?, label: String?, patente: String?) {
    var c = ProtoCursor(bytes, start, end)
    var id: String?
    var label: String?
    var patente: String?
    while let f = c.next() {
        switch (f.number, f.wire) {
        case (1, 2): id = protoString(bytes, f.lenStart, f.lenEnd)
        case (2, 2): label = protoString(bytes, f.lenStart, f.lenEnd)
        case (3, 2): patente = protoString(bytes, f.lenStart, f.lenEnd)
        default: break
        }
    }
    return (id, label, patente)
}
