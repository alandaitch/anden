package com.alandaitch.anden.data.store

import android.content.Context
import android.content.SharedPreferences
import com.alandaitch.anden.AndenApp

// Ajustes de la app. Persiste en SharedPreferences.
class AppSettings(context: Context = AndenApp.appContext) {

    private val prefs: SharedPreferences =
        context.getSharedPreferences("anden.settings", Context.MODE_PRIVATE)

    var notifDemorasEnabled: Boolean
        get() = prefs.getBoolean("settings.notifDemoras", false)
        set(value) { prefs.edit().putBoolean("settings.notifDemoras", value).apply() }

    var seguirServicioId: String?
        get() = prefs.getString("settings.seguirServicioId", null)
        set(value) { prefs.edit().putString("settings.seguirServicioId", value).apply() }

    var onboardingDone: Boolean
        get() = prefs.getBoolean("settings.onboardingDone", false)
        set(value) { prefs.edit().putBoolean("settings.onboardingDone", value).apply() }

    companion object {
        val shared: AppSettings by lazy { AppSettings() }
    }
}
