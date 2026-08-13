package com.alandaitch.anden

import android.Manifest
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.Surface
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import com.alandaitch.anden.data.location.LocationProvider
import com.alandaitch.anden.data.store.AppSettings
import com.alandaitch.anden.ui.RootScreen
import com.alandaitch.anden.ui.onboarding.OnboardingScreen
import com.alandaitch.anden.ui.theme.AndenTheme
import com.alandaitch.anden.ui.theme.andenColors

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            AndenTheme {
                AppRoot()
            }
        }
    }
}

@Composable
private fun AppRoot() {
    val colors = andenColors()
    var onboardingDone by remember { mutableStateOf(AppSettings.shared.onboardingDone) }

    // Lanzador del permiso de ubicación. Al conceder, arranca el proveedor.
    val permissionLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.RequestMultiplePermissions(),
    ) { _ ->
        LocationProvider.shared.refreshPermission()
        if (LocationProvider.shared.computePermission()) {
            LocationProvider.shared.start()
        }
    }

    // Pide el permiso una vez, después del onboarding.
    LaunchedEffect(onboardingDone) {
        if (onboardingDone) {
            LocationProvider.shared.refreshPermission()
            if (LocationProvider.shared.computePermission()) {
                LocationProvider.shared.start()
            } else {
                permissionLauncher.launch(
                    arrayOf(
                        Manifest.permission.ACCESS_FINE_LOCATION,
                        Manifest.permission.ACCESS_COARSE_LOCATION,
                    ),
                )
            }
        }
    }

    Surface(modifier = Modifier.fillMaxSize(), color = colors.background) {
        if (!onboardingDone) {
            OnboardingScreen(onDone = { onboardingDone = true })
        } else {
            RootScreen()
        }
    }
}
