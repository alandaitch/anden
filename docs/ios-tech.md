# Capacidades técnicas iOS — App de arribos de trenes sin servidor propio

Target: iOS 17+. SwiftUI. Xcode 26. Sin servidor propio.
Fuente de datos: solo la API REST pública de consulta.

Leyenda de veredictos:
- **HACER**: funciona bien sin servidor propio. Priorizar para el MVP.
- **HACER LUEGO**: funciona, pero con límites reales. No es crítico para el MVP.
- **NO SE PUEDE**: requiere servidor propio con push (APNs). Descartar la promesa.

---

## 1. Live Activities + Dynamic Island

### Qué se puede

Iniciar un Live Activity local, sin servidor:

```swift
let attributes = TrainActivityAttributes(stationName: "Retiro")
let content = ActivityContent(state: TrainActivityAttributes.ContentState(
    eta: etaDate
), staleDate: etaDate)

let activity = try Activity.request(
    attributes: attributes,
    content: content,
    pushType: nil // sin push
)
```

Actualizarlo localmente, con la app en foreground o en un background task:

```swift
await activity.update(content)
```

Para el countdown, usar `Text(timerInterval:)`. El sistema lo renderiza solo:

```swift
Text(timerInterval: Date.now...etaDate, countsDown: true)
```

Esto corre sin código propio. No gasta budget de actualizaciones. Actualiza cada segundo en pantalla.

### Qué NO se puede sin servidor push

- **Push-to-start**: iniciar el Live Activity con la app cerrada. Requiere `pushToStartToken` y APNs.
- **Actualizar el ETA en background de forma confiable**. La app debe correr para llamar `update()`. El disparador de background (`BGAppRefreshTask`) no tiene horario fijo.
- **Refresco en tiempo real de demoras detectadas por el servidor**. Sin servidor propio, no hay quien empuje el cambio.

### Límites reales

- Sin la entitlement de actualizaciones frecuentes, el sistema throttlea las actualizaciones en background para cuidar batería.
- `NSSupportsLiveActivitiesFrequentUpdates` es una clave de Info.plist. No requiere cuenta paga. Sube la frecuencia permitida.
- Desde iOS 18, las actualizaciones push llegan cada 5–15 segundos, no cada 1 segundo como en iOS 17.
- El `staleDate` marca cuándo el sistema debe mostrar el contenido como "viejo". Usarlo siempre.

### Patrón recomendado

1. El countdown visual usa `Text(timerInterval:)`. No necesita servidor.
2. El `endDate` del countdown se actualiza solo cuando la app corre (foreground o `BGAppRefreshTask`).
3. Si el tren se demora, la próxima vez que la app corra, se llama `update()` con el nuevo ETA.
4. El usuario ve un countdown fluido. El dato de fondo puede estar desactualizado por minutos.

### Veredicto

**HACER**: Live Activity local con countdown vía `Text(timerInterval:)`.
**NO SE PUEDE**: push-to-start ni actualización de demoras en tiempo real sin servidor propio.

---

## 2. Widgets (Home Screen + Lock Screen)

### Qué se puede

`TimelineProvider` genera entradas futuras. El sistema las muestra en su horario:

```swift
func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
    let entries = upcomingTrains.map { train in
        TrainEntry(date: train.departureDate, train: train)
    }
    let timeline = Timeline(entries: entries, policy: .atEnd)
    completion(timeline)
}
```

Para mostrar un countdown sin recargar el widget, usar estilos de fecha nativos:

```swift
Text(entry.train.departureDate, style: .relative)
```

Pedir una recarga manual, cuando la app corre:

```swift
WidgetCenter.shared.reloadTimelines(ofKind: "TrainWidget")
```

### Frecuencia real de refresco

- El sistema asigna un presupuesto diario. En la práctica: 40 a 70 recargas por día.
- Eso equivale a una recarga cada 15 a 60 minutos, según uso del usuario.
- El presupuesto se ajusta al comportamiento del usuario. No es fijo ni predecible.
- Con política `.never` y refresco solo por push, el límite baja a 72 recargas por día.
- El widget de Lock Screen sigue las mismas reglas de presupuesto.

### StandBy

Un widget `systemSmall` aparece automático en StandBy. No hace falta código extra.

### Patrón recomendado

1. Cargar en la timeline los próximos 3 a 5 trenes de la estación favorita.
2. Mostrar el countdown con `style: .relative`, no con texto fijo.
3. Pedir recarga manual (`reloadTimelines`) cada vez que la app abre.
4. No prometer un refresco a horario fijo. El sistema decide cuándo recargar.

### Veredicto

**HACER**: widget con próximos horarios y countdown nativo.
**HACER LUEGO**: reflejar demoras casi en tiempo real. El presupuesto del sistema lo limita.

---

## 3. Notificaciones de demora sin servidor propio

### Qué se puede

Registrar y programar una tarea de background:

```swift
BGTaskScheduler.shared.register(
    forTaskWithIdentifier: "com.anden.refresh",
    using: nil
) { task in
    handleRefresh(task: task as! BGAppRefreshTask)
}

let request = BGAppRefreshTaskRequest(identifier: "com.anden.refresh")
request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
try BGTaskScheduler.shared.submit(request)
```

Dentro de la tarea, consultar la API pública y disparar una notificación local si hay demora:

```swift
let content = UNMutableNotificationContent()
content.title = "Tu tren se demora"
content.body = "Nuevo horario: 18:42"
let request = UNNotificationRequest(
    identifier: UUID().uuidString,
    content: content,
    trigger: nil // inmediata
)
try await UNUserNotificationCenter.current().add(request)
```

### Frecuencia real de background refresh

- No hay horario garantizado. iOS decide con un motor predictivo, según uso del usuario.
- En la práctica, developers reportan entre 15 minutos y 6 horas entre ejecuciones.
- `earliestBeginDate` es un piso, no una promesa. iOS puede tardar mucho más.
- Cada tarea tiene un tope de unos 30 segundos de ejecución.
- Con Modo de Bajo Consumo activo, el background refresh queda prácticamente desactivado.

### Estrategias para maximizar la frecuencia

1. Pedir background refresh cada vez que la app pasa a background, no una sola vez.
2. Mantener el uso frecuente de la app. iOS prioriza apps que el usuario abre seguido.
3. Combinar con `BGProcessingTask` solo si hace falta más tiempo de ejecución.
4. Usar notificaciones locales calculadas con el horario ya conocido, como respaldo del background refresh.

### Honestidad sobre los límites

Esto no es un sistema de alertas en tiempo real. Es mejor esfuerzo, sin garantía.
Una demora puede tardar horas en notificarse. O no notificarse nunca, si el usuario no abre la app.
No hay forma de emular push real sin servidor propio con APNs.

### Veredicto

**NO SE PUEDE** prometer notificación de demora en tiempo real sin servidor propio.
**HACER LUEGO**: notificación de mejor esfuerzo, con esa limitación explicada al usuario.

---

## 4. CoreLocation

### Estación más cercana

```swift
let manager = CLLocationManager()
manager.requestWhenInUseAuthorization()
```

Calcular distancia contra el dataset propio de estaciones:

```swift
let closest = stations.min {
    $0.location.distance(from: userLocation) < $1.location.distance(from: userLocation)
}
```

Alcanza con `requestWhenInUseAuthorization`. No hace falta `Always` para esto.

### Significant location change

Bajo consumo de batería. Notifica cambios de posición grandes, no continuos:

```swift
manager.startMonitoringSignificantLocationChanges()
```

Requiere autorización `Always`. Útil para refrescar la estación favorita en background.

### Geofencing por estación

```swift
let region = CLCircularRegion(
    center: station.coordinate,
    radius: 300,
    identifier: station.id
)
region.notifyOnEntry = true
manager.startMonitoring(for: region)
```

**Límite duro: 20 regiones monitoreadas por app, simultáneas.** Es un recurso compartido del sistema.
Estrategia: monitorear solo las estaciones cercanas a la posición actual. Actualizar la lista al moverse.

### Permisos de forma no invasiva

1. Mostrar primero una pantalla propia explicando el beneficio, antes del prompt del sistema.
2. Pedir `requestWhenInUseAuthorization` primero. Nunca pedir `Always` de entrada.
3. Pedir `requestAlwaysAuthorization` solo cuando el usuario activa geofencing o alertas de proximidad.
4. iOS exige el paso por `WhenInUse` antes de poder pedir `Always`.

### Veredicto

**HACER**: estación más cercana + significant location change.
**HACER LUEGO**: geofencing con alerta de proximidad. Límite de 20 regiones, permiso `Always` con más fricción.

---

## 5. MapKit en SwiftUI (iOS 17+)

### Mapa base con anotaciones

```swift
Map(position: $cameraPosition) {
    Annotation("Estación Retiro", coordinate: station.coordinate) {
        StationPin(train: nearestTrain)
    }
    MapPolyline(coordinates: routeCoordinates)
        .stroke(.blue, lineWidth: 3)
}
```

`MapContentBuilder` arma el contenido del mapa. `Marker` da un pin estándar. `Annotation` acepta una vista SwiftUI propia.

### Recorrido de la vía

`MapPolyline(coordinates:)` recibe un arreglo fijo de `CLLocationCoordinate2D`. No necesita red.
El recorrido puede vivir embebido en la app, como dataset propio (GeoJSON o array de coordenadas).

### Tren moviéndose

No existe una anotación animada nativa. Se interpola la posición a mano:

```swift
withAnimation(.linear(duration: pollingInterval)) {
    trainPosition = newCoordinateFromAPI
}
```

Para trayectos más suaves entre dos posiciones conocidas, usar `mapCameraKeyframeAnimator` (iOS 17+).

### Seguimiento de un tren

Actualizar `MapCameraPosition` con la posición interpolada del tren en cada consulta a la API.

```swift
cameraPosition = .region(MKCoordinateRegion(
    center: trainPosition,
    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
))
```

### Veredicto

**HACER**: todo el patrón funciona sin servidor propio. La animación es local. Los datos vienen de la API pública por consulta directa (polling).

---

## 6. Extras

### App Intents / Siri

```swift
struct NextTrainIntent: AppIntent {
    static var title: LocalizedStringResource = "Próximo tren"

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let train = try await fetchNextTrain()
        return .result(dialog: "El próximo tren llega en \(train.minutesAway) minutos")
    }
}

struct AndenShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: NextTrainIntent(),
            phrases: ["¿Cuándo viene el tren en \(.applicationName)?"],
            shortTitle: "Próximo tren",
            systemImageName: "tram.fill"
        )
    }
}
```

El intent llama a la API pública dentro de `perform()`. No necesita servidor propio.
**Veredicto: HACER LUEGO.** Suma valor, no es crítico para el MVP.

### Apple Watch companion

Desde iOS 18 / watchOS 11, el Live Activity aparece solo en el Smart Stack del reloj. Sin watch app. Sin código extra.
Una watch app dedicada no suma valor sobre esto para el MVP.
**Veredicto: NO SE PUEDE mejor gratis. NO hacer watch app dedicada.**

### StandBy mode

Automático si existe un widget `systemSmall`. Ya cubierto en la sección 2.
**Veredicto: HACER.** Costo cero, ya viene con el widget de home screen.

### TipKit

```swift
struct FavoriteStationTip: Tip {
    var title: Text { Text("Marcá tu estación") }
    var message: Text? { Text("Tocá la estrella para verla primero") }
}
```

Llamar `Tips.configure()` una vez, al arrancar la app.
**Veredicto: HACER LUEGO.** Útil para el onboarding de permisos y de estación favorita.

### Haptics

```swift
.sensoryFeedback(.success, trigger: favoriteAdded)
```

Modifier de SwiftUI, iOS 17+. Trivial de agregar en confirmaciones.
**Veredicto: HACER.** Costo mínimo, mejora la sensación de la app.

---

## 7. Firma con Apple Development personal (free team)

### Capabilities permitidas

- **App Groups**: sí, funciona. Necesario para compartir datos entre la app y el widget extension.
- **Live Activities locales**: sí, funcionan. No requieren entitlement de push.
- Background Modes básicos: disponibles, con el set reducido de la cuenta free.

### Capabilities bloqueadas

- **Push Notifications (APNs)**: no disponible. Sin esto, no hay push-to-start ni push updates.
- Sign in with Apple, iCloud, Apple Pay, Associated Domains: no disponibles.

### Límites de la cuenta free

- El perfil de provisioning expira a los **7 días**.
- Pasado ese plazo, la app deja de abrir en el iPhone físico.
- Hay que reconectar el dispositivo al Mac y recompilar cada semana.
- Hasta **10 App IDs** registrados por cuenta, en una ventana móvil de 7 días.
- Hasta **3 dispositivos de test** por plataforma.

Con app principal + widget extension, se usan 2 de los 10 App IDs disponibles. Sobra margen.

### Qué evitar para que la instalación no falle

1. No declarar la capability "Push Notifications" en ningún target. Rompe el signing en cuenta free.
2. No recrear el App ID de la app o del widget sin necesidad. Consume el cupo de 7 días.
3. No dejar pasar más de 7 días sin reconectar el dispositivo. La app deja de abrir.
4. Usar el mismo Team en el target de la app y en el del widget extension.
5. Usar el mismo App Group ID declarado en ambos targets, sin typos.

### Veredicto

**HACER**: firmar con cuenta free para desarrollo y pruebas propias.
**NO SE PUEDE**: usar push (APNs) de ningún tipo con esta cuenta.

---

## Resumen de veredictos

| Tema | Veredicto |
|---|---|
| Live Activity local, countdown con `Text(timerInterval:)` | HACER |
| Live Activity push-to-start / actualización remota | NO SE PUEDE |
| Widget con próximos trenes y countdown nativo | HACER |
| Widget reflejando demoras casi en tiempo real | HACER LUEGO |
| Notificación local de demora vía background refresh | HACER LUEGO (mejor esfuerzo) |
| Notificación de demora en tiempo real garantizada | NO SE PUEDE |
| Estación más cercana + significant location change | HACER |
| Geofencing por estación (alerta de proximidad) | HACER LUEGO |
| MapKit con tren animado y polyline de recorrido | HACER |
| App Intents / Siri ("¿cuándo viene el tren?") | HACER LUEGO |
| Apple Watch companion dedicada | NO HACER (ya viene gratis con Live Activity) |
| StandBy mode | HACER (automático) |
| TipKit para onboarding | HACER LUEGO |
| Haptics en confirmaciones | HACER |
| Firma con cuenta free (Personal Team) | HACER, con límite de 7 días |
| Push notifications con cuenta free | NO SE PUEDE |

---

## Riesgos: qué promesas NO hacer

1. **No prometer notificaciones push en tiempo real de demoras.** Sin servidor propio con APNs, es imposible.
2. **No prometer que el Live Activity se actualiza al segundo con datos frescos en background.** El countdown visual es fluido, pero el ETA de fondo puede estar viejo por minutos u horas.
3. **No prometer un refresco de widget a horario fijo.** El sistema decide, con un presupuesto de 40 a 70 recargas por día.
4. **No prometer una frecuencia fija de background refresh.** Es heurística de iOS. Se desactiva en Modo de Bajo Consumo.
5. **No prometer geofencing en más de 20 estaciones a la vez.** Es un límite duro del sistema.
6. **Avisar sobre el límite de 7 días de la cuenta free.** La app deja de abrir en el iPhone si no se reinstala a tiempo.
7. **Cualquier "tiempo real" en esta app depende de que el usuario abra la app, o de que iOS decida correr una tarea de background.** No hay garantía dura sin servidor propio.
