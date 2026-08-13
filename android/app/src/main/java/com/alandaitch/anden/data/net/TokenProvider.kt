package com.alandaitch.anden.data.net

import android.content.Context
import android.content.SharedPreferences
import com.alandaitch.anden.AndenApp
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONObject
import java.time.ZoneOffset
import java.time.ZonedDateTime
import java.util.Base64
import java.util.concurrent.TimeUnit

// Genera y cachea el JWT de SOFSE. Ver api-reference sección 2 y sofse_client.py.
// Devuelve el JWT crudo (SIN 'Bearer'). Cachea 24h en SharedPreferences.
class TokenProvider(
    context: Context = AndenApp.appContext,
    private val client: OkHttpClient = defaultClient()
) {
    private val base = "https://api-servicios.sofse.gob.ar/v1"
    private val prefs: SharedPreferences =
        context.getSharedPreferences("sofse.token", Context.MODE_PRIVATE)

    private val tokenKey = "sofse.jwt"
    private val expKey = "sofse.jwt.exp" // epoch segundos

    private val mutex = Mutex()
    @Volatile private var cachedToken: String? = null
    @Volatile private var cachedExp: Long = 0 // epoch segundos

    // Devuelve el JWT crudo. Regenera si force o si venció.
    suspend fun token(force: Boolean = false): String = mutex.withLock {
        if (!force) {
            validCached()?.let { return it }
        }
        refresh()
    }

    private fun validCached(): String? {
        val nowSec = System.currentTimeMillis() / 1000
        cachedToken?.let { t ->
            if (cachedExp - nowSec > 60) return t
        }
        val stored = prefs.getString(tokenKey, null)
        if (stored != null) {
            val exp = prefs.getLong(expKey, 0)
            if (exp - nowSec > 60) {
                cachedToken = stored
                cachedExp = exp
                return stored
            }
        }
        return null
    }

    private suspend fun refresh(): String = withContext(Dispatchers.IO) {
        val creds = generateCredentials()
        val bodyJson = JSONObject()
            .put("username", creds.username)
            .put("password", creds.password)
            .toString()
        val req = Request.Builder()
            .url("$base/auth/authorize")
            .post(bodyJson.toRequestBody("application/json".toMediaType()))
            .header("Content-Type", "application/json")
            .build()

        val (status, respBody) = try {
            client.newCall(req).execute().use { resp ->
                resp.code to (resp.body?.string() ?: "")
            }
        } catch (e: Exception) {
            throw ApiError.Transport(e)
        }
        if (status !in 200..299) throw ApiError.Http(status, respBody)

        val token = try {
            JSONObject(respBody).optString("token", "")
        } catch (e: Exception) {
            throw ApiError.Unauthorized
        }
        if (token.isEmpty()) throw ApiError.Unauthorized

        val exp = expiry(token) ?: (System.currentTimeMillis() / 1000 + 86400)
        cachedToken = token
        cachedExp = exp
        prefs.edit().putString(tokenKey, token).putLong(expKey, exp).apply()
        token
    }

    companion object {
        val shared: TokenProvider by lazy { TokenProvider() }

        private fun defaultClient(): OkHttpClient = OkHttpClient.Builder()
            .callTimeout(60, TimeUnit.SECONDS)
            .connectTimeout(60, TimeUnit.SECONDS)
            .readTimeout(60, TimeUnit.SECONDS)
            .build()

        // Tabla de cifrado (portada de sofse_client.py, verificada).
        private val cipherTable: List<Pair<String, List<String>>> = listOf(
            "a" to listOf("#t", "#j"), "e" to listOf("#x", "#p"), "i" to listOf("#f", "#w"),
            "o" to listOf("#l", "#8"), "u" to listOf("#7", "#0"), "=" to listOf("#g", "#v")
        )

        private fun b64(s: String): String =
            Base64.getEncoder().encodeToString(s.toByteArray(Charsets.UTF_8))

        private fun cipher(s: String, step: Int): String {
            var r = s
            for ((ch, out) in cipherTable) {
                r = r.replace(ch, out[step])
            }
            return r
        }

        // Réplica de urllib.parse.quote (safe='/'): sin codificar letras, dígitos, "_.-~/".
        private fun urlencode(s: String): String {
            val allowed = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_.-~/"
            val sb = StringBuilder()
            for (b in s.toByteArray(Charsets.UTF_8)) {
                val c = (b.toInt() and 0xFF).toChar()
                if (c in allowed) {
                    sb.append(c)
                } else {
                    sb.append('%')
                    sb.append("%02X".format(b.toInt() and 0xFF))
                }
            }
            return sb.toString()
        }

        // Genera username y password. Fecha en UTC. Réplica exacta de gen_creds().
        fun generateCredentials(now: ZonedDateTime = ZonedDateTime.now(ZoneOffset.UTC)): Credentials {
            val datestr = "%04d%02d%02dsofse".format(now.year, now.monthValue, now.dayOfMonth)
            val username = b64(datestr)
            var p = b64(username)
            p = cipher(p, 0)
            p = p.reversed()
            p = b64(p)
            p = cipher(p, 1)
            p = p.reversed()
            val password = urlencode(p)
            return Credentials(username, password)
        }

        // Lee exp (epoch segundos) del payload del JWT. null si no se puede.
        fun expiry(jwt: String): Long? {
            val parts = jwt.split(".")
            if (parts.size < 2) return null
            return try {
                var b64url = parts[1]
                    .replace('-', '+')
                    .replace('_', '/')
                while (b64url.length % 4 != 0) b64url += "="
                val data = Base64.getDecoder().decode(b64url)
                val obj = JSONObject(String(data, Charsets.UTF_8))
                if (obj.has("exp")) obj.getDouble("exp").toLong() else null
            } catch (_: Exception) {
                null
            }
        }
    }

    data class Credentials(val username: String, val password: String)
}
