# Publicar Andén en Google Play — guía

Todo lo pesado ya está hecho. Estos pasos los tenés que hacer vos porque requieren tu cuenta de Google y el pago. Tardás ~15 minutos (más la espera de la revisión).

## Lo que ya está listo (en esta carpeta `android/play/` y en el proyecto)
- **App Bundle firmado** para subir: `android/app/build/outputs/bundle/release/app-release.aab` (firmado con `anden-release.keystore`).
- **Ícono 512×512**: `icon-512.png`
- **Gráfico de funciones 1024×500**: `feature-graphic-1024x500.png`
- **Capturas de teléfono**: `01-cerca.png`, `02-mapa.png`, `03-alertas.png`, `04-onboarding.png`
- **Política de privacidad**: `docs/PRIVACY.md` — URL para el formulario:
  `https://raw.githubusercontent.com/alandaitch/anden/main/docs/PRIVACY.md`
- **Textos de la ficha**: `listing.md`

## Pasos en la Play Console
1. **Creá la cuenta de desarrollador**: https://play.google.com/console → pago único **US$25** + verificación de identidad (DNI). Es una sola vez.
2. **Create app**: nombre "Andén", idioma español (Argentina), tipo App, gratis.
3. **Store listing** (Ficha de Play): pegá el título, la descripción corta y la larga de `listing.md`. Subí `icon-512.png`, `feature-graphic-1024x500.png` y las 4 capturas. Categoría: **Mapas y navegación**.
4. **Privacy policy**: pegá la URL de arriba.
5. **Data safety** (Seguridad de los datos): 
   - ¿Recopila o comparte datos del usuario? **No** (la ubicación se usa solo en el dispositivo y no se envía a ningún servidor).
   - Declará que la app **accede a la ubicación** pero **no la recopila** (no sale del teléfono).
6. **Content rating**: completá el cuestionario → queda "Apta para todos".
7. **Target audience**: mayores de 13 (no dirigida a niños).
8. **Production → Create release**: subí `app-release.aab`. Play te va a ofrecer **Play App Signing** (aceptá; Play gestiona la clave de distribución, vos subís con tu clave de carga).
9. **Enviá a revisión**. Google revisa (horas a días). Cuando aprueba, queda pública.

## Avisos honestos
- **Costo**: US$25 una vez (no anual, a diferencia de Apple).
- **Riesgo de revisión**: es una app **no oficial** que usa APIs y marcas de terceros (Trenes Argentinos, SUBE, EcoBici). Play suele aceptar apps de transporte no oficiales, y el nombre "Andén" es genérico, pero puede haber observaciones. La ficha ya aclara "no oficial".
- **La key de la Ciudad va embebida en el AAB** (como en el APK). Si te preocupa, generá una key aparte para la versión de Play.
- **Actualizaciones**: para subir una nueva versión, incrementá `versionCode` en `android/app/build.gradle.kts` y volvé a `bundleRelease`.
