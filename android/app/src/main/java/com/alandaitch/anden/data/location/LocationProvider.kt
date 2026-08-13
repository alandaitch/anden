package com.alandaitch.anden.data.location

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Looper
import androidx.core.content.ContextCompat
import com.alandaitch.anden.AndenApp
import com.alandaitch.anden.util.GeoPoint
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

// Ubicación vía android.location.LocationManager (sin Google Play services, APK universal).
// Expone StateFlow<Location?> y el estado de permiso. La UI pide el permiso y llama start().
class LocationProvider(context: Context = AndenApp.appContext) {

    private val appContext = context.applicationContext
    private val manager =
        appContext.getSystemService(Context.LOCATION_SERVICE) as? LocationManager

    private val _location = MutableStateFlow<Location?>(null)
    val location: StateFlow<Location?> = _location.asStateFlow()

    private val _hasPermission = MutableStateFlow(computePermission())
    val hasPermission: StateFlow<Boolean> = _hasPermission.asStateFlow()

    // Último punto conocido como GeoPoint, para catálogos.
    val point: GeoPoint? get() = _location.value?.let { GeoPoint(it.latitude, it.longitude) }

    private val listener = LocationListener { loc -> _location.value = loc }

    // Verifica el permiso otorgado (fine o coarse).
    fun computePermission(): Boolean {
        val fine = ContextCompat.checkSelfPermission(
            appContext, Manifest.permission.ACCESS_FINE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED
        val coarse = ContextCompat.checkSelfPermission(
            appContext, Manifest.permission.ACCESS_COARSE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED
        return fine || coarse
    }

    // Refresca el estado de permiso (llamar tras el diálogo del sistema).
    fun refreshPermission() {
        _hasPermission.value = computePermission()
    }

    // Arranca updates y siembra con la última ubicación conocida. Requiere permiso.
    fun start(minTimeMs: Long = 5000L, minDistanceM: Float = 20f) {
        val mgr = manager ?: return
        if (!computePermission()) {
            _hasPermission.value = false
            return
        }
        _hasPermission.value = true
        try {
            lastKnown()?.let { _location.value = it }
            val providers = mutableListOf<String>()
            if (mgr.isProviderEnabled(LocationManager.GPS_PROVIDER)) providers.add(LocationManager.GPS_PROVIDER)
            if (mgr.isProviderEnabled(LocationManager.NETWORK_PROVIDER)) providers.add(LocationManager.NETWORK_PROVIDER)
            for (p in providers) {
                mgr.requestLocationUpdates(p, minTimeMs, minDistanceM, listener, Looper.getMainLooper())
            }
        } catch (_: SecurityException) {
            _hasPermission.value = false
        }
    }

    // Corta los updates.
    fun stop() {
        try {
            manager?.removeUpdates(listener)
        } catch (_: SecurityException) {
        }
    }

    // Última ubicación conocida de cualquier proveedor. null si no hay o falta permiso.
    fun lastKnown(): Location? {
        val mgr = manager ?: return null
        if (!computePermission()) return null
        return try {
            val gps = mgr.getLastKnownLocation(LocationManager.GPS_PROVIDER)
            val net = mgr.getLastKnownLocation(LocationManager.NETWORK_PROVIDER)
            when {
                gps != null && net != null -> if (gps.time >= net.time) gps else net
                else -> gps ?: net
            }
        } catch (_: SecurityException) {
            null
        }
    }

    companion object {
        val shared: LocationProvider by lazy { LocationProvider() }
    }
}
