package com.alandaitch.anden.data.store

import android.content.Context
import android.content.SharedPreferences
import com.alandaitch.anden.AndenApp
import com.alandaitch.anden.data.catalog.StationCatalog
import com.alandaitch.anden.data.model.Station
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import java.time.Instant
import java.util.Calendar

enum class FavoriteRole { NONE, HOME, WORK }

@Serializable
data class FavoriteStation(
    val stationId: Int,
    var role: FavoriteRole = FavoriteRole.NONE,
    val addedAtEpoch: Long = Instant.now().epochSecond
) {
    val id: Int get() = stationId
}

// Favoritos con rol de contexto. Persiste en SharedPreferences (JSON).
// Expone StateFlow para que la UI Compose observe cambios.
class FavoritesStore(
    context: Context = AndenApp.appContext,
    private val catalog: StationCatalog = StationCatalog.shared
) {
    private val prefs: SharedPreferences =
        context.getSharedPreferences("anden.favorites", Context.MODE_PRIVATE)
    private val key = "favorites.v1"
    private val json = Json { ignoreUnknownKeys = true }

    private val _items = MutableStateFlow<List<FavoriteStation>>(emptyList())
    val itemsFlow: StateFlow<List<FavoriteStation>> = _items.asStateFlow()
    val items: List<FavoriteStation> get() = _items.value

    init {
        load()
    }

    private fun load() {
        val data = prefs.getString(key, null) ?: return
        runCatching { json.decodeFromString<List<FavoriteStation>>(data) }
            .getOrNull()?.let { _items.value = it }
    }

    private fun persist() {
        prefs.edit().putString(key, json.encodeToString(_items.value)).apply()
    }

    fun isFavorite(stationId: Int): Boolean = _items.value.any { it.stationId == stationId }

    fun toggle(stationId: Int) {
        val current = _items.value.toMutableList()
        val idx = current.indexOfFirst { it.stationId == stationId }
        if (idx >= 0) current.removeAt(idx)
        else current.add(FavoriteStation(stationId))
        _items.value = current
        persist()
    }

    fun setRole(role: FavoriteRole, stationId: Int) {
        val current = _items.value.toMutableList()
        val idx = current.indexOfFirst { it.stationId == stationId }
        if (idx >= 0) current[idx] = current[idx].copy(role = role)
        else current.add(FavoriteStation(stationId, role))
        _items.value = current
        persist()
    }

    fun role(stationId: Int): FavoriteRole =
        _items.value.firstOrNull { it.stationId == stationId }?.role ?: FavoriteRole.NONE

    // Estaciones resueltas contra el catálogo, en orden de agregado.
    val favorites: List<Station>
        get() = _items.value.mapNotNull { catalog.station(it.stationId) }

    // Home a la mañana (4-12), work a la tarde (12-22). Si no hay roles, el primero.
    fun contextualPrimary(now: Instant = Instant.now()): Station? {
        val cal = Calendar.getInstance().apply { timeInMillis = now.toEpochMilli() }
        val hour = cal.get(Calendar.HOUR_OF_DAY)
        val preferred = when {
            hour in 4..11 -> FavoriteRole.HOME
            hour in 12..21 -> FavoriteRole.WORK
            else -> FavoriteRole.NONE
        }
        if (preferred != FavoriteRole.NONE) {
            _items.value.firstOrNull { it.role == preferred }?.let { fav ->
                return catalog.station(fav.stationId)
            }
        }
        return favorites.firstOrNull()
    }

    companion object {
        val shared: FavoritesStore by lazy { FavoritesStore() }
    }
}
