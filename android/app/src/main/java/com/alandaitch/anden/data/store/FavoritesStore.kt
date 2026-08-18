package com.alandaitch.anden.data.store

import android.content.Context
import android.content.SharedPreferences
import com.alandaitch.anden.AndenApp
import com.alandaitch.anden.data.catalog.StationCatalog
import com.alandaitch.anden.data.model.EcobiciStation
import com.alandaitch.anden.data.catalog.SubteStation
import com.alandaitch.anden.data.model.Station
import com.alandaitch.anden.util.GeoPoint
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import java.time.Instant
import java.util.Calendar

enum class FavoriteRole { NONE, HOME, WORK }

// Modo de transporte de un favorito.
enum class FavoriteMode { TREN, SUBTE, BONDI, BICI }

// Favorito de cualquier modo. Guarda todo lo necesario para mostrarlo y navegar,
// sin depender de catálogos (bondi y bici no tienen catálogo estático embebido).
@Serializable
data class FavoriteItem(
    val mode: FavoriteMode,
    val refId: String,
    val name: String,
    val lat: Double,
    val lng: Double,
    val lineLabel: String? = null,
    val lineColorHex: String? = null,
    val routeId: String? = null,
    var role: FavoriteRole = FavoriteRole.NONE,
    val addedAtEpoch: Long = Instant.now().epochSecond,
) {
    val id: String get() = "${mode.name}:$refId"
    val coordinate: GeoPoint get() = GeoPoint(lat, lng)

    companion object {
        fun train(s: Station) = FavoriteItem(
            FavoriteMode.TREN, s.id.toString(), s.nombre, s.lat, s.lng,
            s.line.shortCode, s.line.colorHex,
        )
        fun subte(s: SubteStation) = FavoriteItem(
            FavoriteMode.SUBTE, s.id, s.name, s.lat, s.lng,
            s.line.letra, s.line.colorHex, s.line.routeId,
        )
        fun bondi(stopId: String, name: String, point: GeoPoint) = FavoriteItem(
            FavoriteMode.BONDI, stopId, name, point.lat, point.lng,
        )
        fun bici(s: EcobiciStation) = FavoriteItem(
            FavoriteMode.BICI, s.id, s.displayName, s.lat, s.lng,
        )
    }
}

// Formato viejo (solo trenes) para migrar sin perder favoritos guardados.
@Serializable
private data class LegacyFavoriteStation(
    val stationId: Int,
    val role: FavoriteRole = FavoriteRole.NONE,
    val addedAtEpoch: Long = 0,
)

// Favoritos multi-modo con rol de contexto. Persiste en SharedPreferences (JSON).
class FavoritesStore(
    context: Context = AndenApp.appContext,
    private val catalog: StationCatalog = StationCatalog.shared,
) {
    private val prefs: SharedPreferences =
        context.getSharedPreferences("anden.favorites", Context.MODE_PRIVATE)
    private val key = "favorites.v2"
    private val legacyKey = "favorites.v1"
    private val json = Json { ignoreUnknownKeys = true }

    private val _items = MutableStateFlow<List<FavoriteItem>>(emptyList())
    val itemsFlow: StateFlow<List<FavoriteItem>> = _items.asStateFlow()
    val items: List<FavoriteItem> get() = _items.value

    init {
        load()
    }

    private fun load() {
        prefs.getString(key, null)?.let { data ->
            runCatching { json.decodeFromString<List<FavoriteItem>>(data) }
                .getOrNull()?.let { _items.value = it; return }
        }
        migrateLegacy()
    }

    // Migra los favoritos v1 (solo trenes) al modelo nuevo y persiste en v2.
    private fun migrateLegacy() {
        val data = prefs.getString(legacyKey, null) ?: return
        val old = runCatching { json.decodeFromString<List<LegacyFavoriteStation>>(data) }.getOrNull() ?: return
        val migrated = old.mapNotNull { legacy ->
            val st = catalog.station(legacy.stationId) ?: return@mapNotNull null
            FavoriteItem(
                FavoriteMode.TREN, legacy.stationId.toString(), st.nombre, st.lat, st.lng,
                st.line.shortCode, st.line.colorHex, role = legacy.role, addedAtEpoch = legacy.addedAtEpoch,
            )
        }
        if (migrated.isNotEmpty()) {
            _items.value = migrated
            persist()
        }
    }

    private fun persist() {
        prefs.edit().putString(key, json.encodeToString(_items.value)).apply()
    }

    fun isFavorite(mode: FavoriteMode, refId: String): Boolean =
        _items.value.any { it.mode == mode && it.refId == refId }

    fun toggle(item: FavoriteItem) {
        val current = _items.value.toMutableList()
        val idx = current.indexOfFirst { it.mode == item.mode && it.refId == item.refId }
        if (idx >= 0) current.removeAt(idx) else current.add(item)
        _items.value = current
        persist()
    }

    fun remove(mode: FavoriteMode, refId: String) {
        _items.value = _items.value.filterNot { it.mode == mode && it.refId == refId }
        persist()
    }

    fun setRole(role: FavoriteRole, mode: FavoriteMode, refId: String) {
        val current = _items.value.toMutableList()
        val idx = current.indexOfFirst { it.mode == mode && it.refId == refId }
        if (idx < 0) return
        current[idx] = current[idx].copy(role = role)
        _items.value = current
        persist()
    }

    fun role(mode: FavoriteMode, refId: String): FavoriteRole =
        _items.value.firstOrNull { it.mode == mode && it.refId == refId }?.role ?: FavoriteRole.NONE

    // Favorito "del momento": home a la mañana (4-12), work a la tarde (12-22).
    // Si no hay rol para la franja, el primero agregado.
    fun contextualPrimary(now: Instant = Instant.now()): FavoriteItem? {
        val cal = Calendar.getInstance().apply { timeInMillis = now.toEpochMilli() }
        val hour = cal.get(Calendar.HOUR_OF_DAY)
        val preferred = when {
            hour in 4..11 -> FavoriteRole.HOME
            hour in 12..21 -> FavoriteRole.WORK
            else -> FavoriteRole.NONE
        }
        if (preferred != FavoriteRole.NONE) {
            _items.value.firstOrNull { it.role == preferred }?.let { return it }
        }
        return _items.value.firstOrNull()
    }

    companion object {
        val shared: FavoritesStore by lazy { FavoritesStore() }
    }
}
