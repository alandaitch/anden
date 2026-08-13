package com.alandaitch.anden.data.net

import com.alandaitch.anden.data.model.BusPosition
import com.alandaitch.anden.util.GeoPoint
import java.util.UUID

// Decoder manual de protobuf para GTFS-realtime (FeedMessage), sin librerías.
// Solo lee lo que la app usa: vehiclePositions. Ver docs/colectivos-data.md.
//
// Wire format: cada campo arranca con un tag = (field << 3) | wire.
// wire: 0=varint, 1=64bit LE, 2=length-delimited, 5=32bit LE.
// Se lee por tag y se saltan los desconocidos por su wire type.
object GtfsRealtime {

    // Un campo leído del stream. Solo se completa el payload de su wire type.
    private class Field(val number: Int, val wire: Int) {
        var varint: Long = 0
        var fixed32: Int = 0
        var fixed64: Long = 0
        var lenStart: Int = 0
        var lenEnd: Int = 0
    }

    // Cursor sobre un rango [pos, end) de bytes. Lee tags y payloads.
    private class Cursor(val bytes: ByteArray, var pos: Int, val end: Int) {

        // varint como Long (sin signo lógico). null si se corta.
        fun readVarint(): Long? {
            var result = 0L
            var shift = 0
            while (pos < end) {
                val b = bytes[pos].toInt() and 0xFF
                pos += 1
                result = result or ((b.toLong() and 0x7F) shl shift)
                if (b and 0x80 == 0) return result
                shift += 7
                if (shift >= 64) return null
            }
            return null
        }

        // Lee el próximo campo. Avanza aunque el caller lo ignore (salta desconocidos).
        // null = fin o dato corrupto.
        fun next(): Field? {
            if (pos >= end) return null
            val tag = readVarint() ?: return null
            val number = (tag ushr 3).toInt()
            val wire = (tag and 0x7).toInt()
            val f = Field(number, wire)
            when (wire) {
                0 -> {
                    val v = readVarint() ?: return null
                    f.varint = v
                }
                1 -> {
                    if (pos + 8 > end) return null
                    var v = 0L
                    for (i in 0 until 8) v = v or ((bytes[pos + i].toLong() and 0xFF) shl (8 * i))
                    pos += 8
                    f.fixed64 = v
                }
                2 -> {
                    val len = readVarint() ?: return null
                    val start = pos
                    val e = pos + len.toInt()
                    if (e > end || e < start) return null
                    f.lenStart = start
                    f.lenEnd = e
                    pos = e
                }
                5 -> {
                    if (pos + 4 > end) return null
                    var v = 0
                    for (i in 0 until 4) v = v or ((bytes[pos + i].toInt() and 0xFF) shl (8 * i))
                    pos += 4
                    f.fixed32 = v
                }
                else -> return null // wire type desconocido: no se puede continuar seguro
            }
            return f
        }
    }

    private fun protoString(bytes: ByteArray, start: Int, end: Int): String? {
        if (start > end || end > bytes.size) return null
        return try {
            String(bytes, start, end - start, Charsets.UTF_8)
        } catch (_: Exception) {
            null
        }
    }

    // Parsea un FeedMessage y devuelve las posiciones con coordenada válida.
    fun parseVehiclePositions(data: ByteArray): List<BusPosition> {
        val out = mutableListOf<BusPosition>()
        val cursor = Cursor(data, 0, data.size)
        // Top level: field 2 (0x12) LEN = FeedEntity (repetido).
        while (true) {
            val f = cursor.next() ?: break
            if (f.number == 2 && f.wire == 2) {
                parseFeedEntity(data, f.lenStart, f.lenEnd)?.let { out.add(it) }
            }
        }
        return out
    }

    // FeedEntity: field 1 (0x0A) id; field 4 (0x22) VehiclePosition.
    private fun parseFeedEntity(bytes: ByteArray, start: Int, end: Int): BusPosition? {
        val c = Cursor(bytes, start, end)
        var entityId: String? = null
        var vpStart = -1
        var vpEnd = -1
        while (true) {
            val f = c.next() ?: break
            when {
                f.number == 1 && f.wire == 2 -> entityId = protoString(bytes, f.lenStart, f.lenEnd)
                f.number == 4 && f.wire == 2 -> { vpStart = f.lenStart; vpEnd = f.lenEnd }
            }
        }
        if (vpStart < 0) return null
        return parseVehiclePosition(bytes, vpStart, vpEnd, entityId)
    }

    // VehiclePosition: field 1 trip; field 2 position; field 8 vehicle descriptor.
    private fun parseVehiclePosition(bytes: ByteArray, start: Int, end: Int, entityId: String?): BusPosition? {
        val c = Cursor(bytes, start, end)
        var routeId: String? = null
        var lat: Double? = null
        var lng: Double? = null
        var bearing: Double? = null
        var interno: String? = null
        var patente: String? = null

        while (true) {
            val f = c.next() ?: break
            when {
                f.number == 1 && f.wire == 2 -> // TripDescriptor
                    routeId = parseTripRouteId(bytes, f.lenStart, f.lenEnd)
                f.number == 2 && f.wire == 2 -> { // Position
                    val p = parsePosition(bytes, f.lenStart, f.lenEnd)
                    lat = p.first; lng = p.second; bearing = p.third
                }
                f.number == 8 && f.wire == 2 -> { // VehicleDescriptor
                    val v = parseVehicleDescriptor(bytes, f.lenStart, f.lenEnd)
                    interno = v.first; patente = v.third
                }
            }
        }

        val la = lat ?: return null
        val ln = lng ?: return null
        val id = entityId ?: interno ?: UUID.randomUUID().toString()
        return BusPosition(
            id = id,
            coordinate = GeoPoint(la, ln),
            routeId = routeId,
            bearing = bearing,
            interno = interno,
            patente = patente
        )
    }

    // TripDescriptor: field 5 (0x2A) route_id.
    private fun parseTripRouteId(bytes: ByteArray, start: Int, end: Int): String? {
        val c = Cursor(bytes, start, end)
        var routeId: String? = null
        while (true) {
            val f = c.next() ?: break
            if (f.number == 5 && f.wire == 2) routeId = protoString(bytes, f.lenStart, f.lenEnd)
        }
        return routeId
    }

    // Position: field 1 lat, field 2 lng (fixed32 float LE); field 3 bearing (opcional);
    // field 4 odometer (64bit) se ignora.
    private fun parsePosition(bytes: ByteArray, start: Int, end: Int): Triple<Double?, Double?, Double?> {
        val c = Cursor(bytes, start, end)
        var lat: Double? = null
        var lng: Double? = null
        var bearing: Double? = null
        while (true) {
            val f = c.next() ?: break
            when {
                f.number == 1 && f.wire == 5 -> lat = Float.fromBits(f.fixed32).toDouble()
                f.number == 2 && f.wire == 5 -> lng = Float.fromBits(f.fixed32).toDouble()
                f.number == 3 && f.wire == 5 -> bearing = Float.fromBits(f.fixed32).toDouble()
            }
        }
        return Triple(lat, lng, bearing)
    }

    // VehicleDescriptor: field 1 id (interno); field 2 label; field 3 license_plate (patente).
    private fun parseVehicleDescriptor(bytes: ByteArray, start: Int, end: Int): Triple<String?, String?, String?> {
        val c = Cursor(bytes, start, end)
        var id: String? = null
        var label: String? = null
        var patente: String? = null
        while (true) {
            val f = c.next() ?: break
            when {
                f.number == 1 && f.wire == 2 -> id = protoString(bytes, f.lenStart, f.lenEnd)
                f.number == 2 && f.wire == 2 -> label = protoString(bytes, f.lenStart, f.lenEnd)
                f.number == 3 && f.wire == 2 -> patente = protoString(bytes, f.lenStart, f.lenEnd)
            }
        }
        return Triple(id, label, patente)
    }
}

// Función de conveniencia top-level (misma firma que iOS).
fun parseVehiclePositions(data: ByteArray): List<BusPosition> =
    GtfsRealtime.parseVehiclePositions(data)
