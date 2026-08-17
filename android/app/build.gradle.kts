import java.util.Properties

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.serialization")
}

// Lee la key de la API de la Ciudad desde local.properties (NO se commitea).
val localProps = Properties().apply {
    val f = rootProject.file("local.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}
fun prop(key: String): String = (localProps.getProperty(key) ?: "").trim()

android {
    namespace = "com.alandaitch.anden"
    compileSdk = 35

    defaultConfig {
        applicationId = "com.alandaitch.anden"
        minSdk = 26
        targetSdk = 35
        versionCode = 3
        versionName = "1.1"
        buildConfigField("String", "BA_CLIENT_ID", "\"${prop("BA_CLIENT_ID")}\"")
        buildConfigField("String", "BA_CLIENT_SECRET", "\"${prop("BA_CLIENT_SECRET")}\"")
    }

    signingConfigs {
        create("release") {
            val ks = rootProject.file("anden-release.keystore")
            if (ks.exists()) {
                storeFile = ks
                storePassword = prop("KEYSTORE_PASSWORD").ifEmpty { "andenanden" }
                keyAlias = prop("KEY_ALIAS").ifEmpty { "anden" }
                keyPassword = prop("KEY_PASSWORD").ifEmpty { "andenanden" }
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            val ks = rootProject.file("anden-release.keystore")
            if (ks.exists()) signingConfig = signingConfigs.getByName("release")
        }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = "17" }
    buildFeatures {
        compose = true
        buildConfig = true
    }
    composeOptions { kotlinCompilerExtensionVersion = "1.5.14" }
    packaging { resources { excludes += "/META-INF/{AL2.0,LGPL2.1}" } }
}

dependencies {
    implementation("androidx.core:core-ktx:1.13.1")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.8.3")
    implementation("androidx.activity:activity-compose:1.9.0")
    implementation(platform("androidx.compose:compose-bom:2024.06.00"))
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-graphics")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.material:material-icons-extended")
    implementation("com.google.android.material:material:1.12.0")
    implementation("androidx.navigation:navigation-compose:2.7.7")
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.6.3")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.8.1")
    implementation("com.squareup.okhttp3:okhttp:4.12.0")
    implementation("org.osmdroid:osmdroid-android:6.1.18")
}
