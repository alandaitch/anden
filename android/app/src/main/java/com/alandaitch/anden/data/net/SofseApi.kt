package com.alandaitch.anden.data.net

import com.alandaitch.anden.data.model.Arrival
import com.alandaitch.anden.data.model.RouteStop
import com.alandaitch.anden.data.model.ServiceAlert
import com.alandaitch.anden.data.model.TrainLine
import com.alandaitch.anden.util.DelayLogic
import com.alandaitch.anden.util.GeoPoint
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import okhttp3.HttpUrl.Companion.toHttpUrl
import okhttp3.OkHttpClient
import okhttp3.Request
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale
import java.util.concurrent.TimeUnit

// Cliente de la API SOFSE. Arribos (sin token), alertas (con token).
class SofseApi(
    private val tokenProvider: TokenProvider = TokenProvider.shared,
    private val client: OkHttpClient = defaultClient()
) {
    private val base = "https://api-servicios.sofse.gob.ar/v1"
    private val json = Json { ignoreUnknownKeys = true }

    // MARK: - Arribos en vivo

    suspend fun arrivals(
        stationId: Int,
        limit: Int = 12,
        toStationId: Int? = null,
        ramalId: Int? = null
    ): List<Arrival> {
        val query = buildMap {
            put("cantidad", limit.toString())
            if (toStationId != null) put("hasta", toStationId.toString())
            if (ramalId != null) put("ramal", ramalId.toString())
        }
        val data = get("arribos/estacion/$stationId", query, auth = false)
        val wrapper = decode<ArribosResponse>(data)
        val serverNow = wrapper.timestamp?.let { Instant.ofEpochSecond(it) } ?: Instant.now()

        val out = mutableListOf<Arrival>()
        for (r in wrapper.results ?: emptyList()) {
            // Filtrar los que ya pasaron (tienen llegada.real).
            if (SofseDate.iso(r.arribo?.llegada?.real) != null) continue
            map(r, serverNow, live = true)?.let { out.add(it) }
        }
        return out.sortedBy { it.secondsUntil }
    }

    // MARK: - Arribos por horario (fallback)

    suspend fun scheduledArrivals(
        stationId: Int,
        date: Instant,
        time: String,
        toStationId: Int? = null,
        limit: Int = 12
    ): List<Arrival> {
        val query = buildMap {
            put("cantidad", limit.toString())
            put("fecha", isoDate(date))
            put("hora", time)
            if (toStationId != null) put("hasta", toStationId.toString())
        }
        val data = get("arribos/estacion/$stationId", query, auth = false)
        val wrapper = decode<ArribosResponse>(data)
        val serverNow = wrapper.timestamp?.let { Instant.ofEpochSecond(it) } ?: date

        val out = mutableListOf<Arrival>()
        for (r in wrapper.results ?: emptyList()) {
            map(r, serverNow, live = false)?.let { out.add(it) }
        }
        return out.sortedBy { it.secondsUntil }
    }

    // MARK: - Alertas

    suspend fun alerts(): List<ServiceAlert> {
        return try {
            coroutineScope {
                val gerencias = async { get("infraestructura/gerencias", emptyMap(), auth = true) }
                val ramales = async { get("infraestructura/ramales", emptyMap(), auth = true) }
                val gData = gerencias.await()
                val rData = ramales.await()

                val raw = mutableListOf<AlertaDTO>()
                runCatching { decode<List<GerenciaAlertDTO>>(gData) }.getOrNull()
                    ?.let { list -> raw += list.flatMap { it.alerta ?: emptyList() } }
                runCatching { decode<List<RamalAlertDTO>>(rData) }.getOrNull()
                    ?.let { list -> raw += list.mapNotNull { it.alerta } }

                val seen = HashSet<String>()
                val out = mutableListOf<ServiceAlert>()
                for (dto in raw) {
                    val content = dto.contenido
                    if (content.isNullOrEmpty()) continue
                    // Normalizar: colapsar espacios (incluye NBSP) para deduplicar.
                    val key = content
                        .replace("\u00A0", " ")
                        .split(Regex("\\s+"))
                        .filter { it.isNotEmpty() }
                        .joinToString(" ")
                        .lowercase()
                    if (seen.contains(key)) continue
                    seen.add(key)
                    out.add(dto.toServiceAlert())
                }
                out.sortedBy { it.criticality }
            }
        } catch (_: Exception) {
            // Degradar a vacío si la auth o la red fallan. No tirar el error a la UI.
            emptyList()
        }
    }

    // MARK: - Mapeo a dominio

    private fun map(r: ResultDTO, serverNow: Instant, live: Boolean): Arrival? {
        val s = r.servicio ?: return null
        val a = r.arribo ?: return null
        val lineId = s.gerencia?.id ?: -1
        val line = TrainLine.line(lineId)
        val sentido = s.sentido ?: 1
        val ini = s.ramal?.cabeceraInicial
        val fin = s.ramal?.cabeceraFinal
        // sentido 1 = hacia cabecera final; 2 = hacia cabecera inicial.
        val destCab = if (sentido == 2) ini else fin
        val origCab = if (sentido == 2) fin else ini

        val scheduled = SofseDate.iso(a.llegada?.programada)
        val estimated = SofseDate.iso(a.llegada?.estimada)
        val tolerance = s.ramal?.tolerancia ?: DelayLogic.DEFAULT_TOLERANCE
        val isCancelled = s.isCancelled
        val seconds = a.segundos ?: 0

        val delay = DelayLogic.status(
            scheduled = scheduled,
            estimated = estimated,
            secondsUntil = seconds,
            serverNow = serverNow,
            tolerance = tolerance,
            isCancelled = isCancelled
        )

        var trainLoc: GeoPoint? = null
        val lat = s.location?.lat
        val lon = s.location?.long
        if (lat != null && lon != null) trainLoc = GeoPoint(lat, lon)

        val route: List<RouteStop> = (s.estaciones ?: emptyList()).mapIndexed { idx, e ->
            RouteStop(
                stationId = e.idElemento ?: -1,
                name = e.nombre ?: "",
                order = e.orden ?: idx,
                scheduled = SofseDate.iso(e.llegada?.programada),
                estimated = SofseDate.iso(e.llegada?.estimada),
                trackName = e.anden?.nombre,
                hasPassed = SofseDate.iso(e.llegada?.real) != null
            )
        }

        val destName = destCab?.display ?: ""
        val sid = s.id
        val id = sid ?: "$lineId-$destName-${scheduled?.epochSecond ?: seconds.toLong()}"

        return Arrival(
            id = id,
            serviceId = sid,
            lineId = lineId,
            line = line,
            ramalName = s.ramal?.nombre ?: line.nombre,
            destinationName = destName,
            originName = origCab?.display ?: "",
            trackName = a.anden?.nombre,
            scheduled = scheduled,
            estimated = estimated,
            secondsUntil = seconds,
            delay = delay,
            trainLocation = trainLoc,
            equipmentName = a.equipo?.nombre,
            isElectric = (a.equipo?.esElectrico ?: 0) == 1,
            isCancelled = isCancelled,
            direction = sentido,
            stateName = s.desde?.estado?.nombre,
            route = route
        )
    }

    // MARK: - Red

    private suspend fun get(
        path: String,
        query: Map<String, String>,
        auth: Boolean,
        retried: Boolean = false
    ): String = withContext(Dispatchers.IO) {
        val urlBuilder = "$base/$path".toHttpUrl().newBuilder()
        for ((k, v) in query) urlBuilder.addQueryParameter(k, v)
        val builder = Request.Builder()
            .url(urlBuilder.build())
            .header("Content-Type", "application/json")
        if (auth) builder.header("Authorization", tokenProvider.token())

        val response = try {
            client.newCall(builder.build()).execute()
        } catch (e: Exception) {
            throw ApiError.Transport(e)
        }

        val code = response.code
        val body = response.body?.string() ?: ""
        response.close()

        // Reintento único ante 401/403: regenerar token y repetir.
        if (auth && !retried && (code == 401 || code == 403)) {
            tokenProvider.token(force = true)
            return@withContext get(path, query, auth, retried = true)
        }
        if (code !in 200..299) throw ApiError.Http(code, body)
        body
    }

    private inline fun <reified T> decode(data: String): T {
        return try {
            json.decodeFromString(data)
        } catch (e: Exception) {
            throw ApiError.Decoding(e)
        }
    }

    companion object {
        val shared: SofseApi by lazy { SofseApi() }

        private val baZone: ZoneId = ZoneId.of("America/Argentina/Buenos_Aires")
        private val dateFormatter: DateTimeFormatter =
            DateTimeFormatter.ofPattern("yyyy-MM-dd", Locale.US).withZone(baZone)

        private fun isoDate(instant: Instant): String = dateFormatter.format(instant)

        private fun defaultClient(): OkHttpClient = OkHttpClient.Builder()
            .callTimeout(60, TimeUnit.SECONDS)
            .connectTimeout(60, TimeUnit.SECONDS)
            .readTimeout(60, TimeUnit.SECONDS)
            .build()
    }
}
