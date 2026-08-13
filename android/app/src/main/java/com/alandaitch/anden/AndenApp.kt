package com.alandaitch.anden

import android.app.Application
import android.content.Context

// Application singleton. Da acceso a Context a catálogos, stores y token.
// Los singletons `.shared` lo usan de forma perezosa.
class AndenApp : Application() {
    override fun onCreate() {
        super.onCreate()
        instance = this
    }

    companion object {
        @Volatile
        lateinit var instance: AndenApp
            private set

        // Context de aplicación. Lanza si se usa antes de onCreate.
        val appContext: Context get() = instance.applicationContext
    }
}
