# Andén — Plan de producto y arquitectura

App iOS de arribos de trenes del AMBA en vivo. SwiftUI, iOS 17+, sin backend propio.
Nombre: **Andén**. Tagline: "Tu tren, en vivo."
Créditos: Alan Daitch + Claude (Anthropic).

## 1. Qué resuelve

Hoy no existe una app buena. La oficial son 4 apps separadas, la de iOS tiene 1.7★.
Nadie responde bien la única pregunta del pasajero: **cuántos minutos falta MI tren en MI estación**.
Andén responde eso en un toque, con demora real, andén, GPS del tren y alertas de la línea.

## 2. Fuente de datos (verificada 12-ago-2026)

- `/arribos/estacion/{id}?cantidad=N` — arribos en vivo. **Sin token.** Trae demora (`estimada-programada`), andén, GPS (`servicio.location`), recorrido completo.
- `/infraestructura/gerencias` + `/infraestructura/ramales` — alertas embebidas. **Con token** auto-generado (algoritmo del APK, JWT 24 h). Header `Authorization` con JWT crudo (sin `Bearer`).
- Catálogo de **360 estaciones con coordenadas** embebido (`estaciones.json`), no se pega a infraestructura en runtime.
- Modo horario (`fecha`+`hora` ISO) como fallback cuando no hay vivo.
- Detalle completo en `docs/api-reference.md`.

Límites honestos (de `docs/ios-tech.md`): sin servidor no hay push real. Countdown y widget = local. Notificación de demora = mejor esfuerzo. Belgrano Norte y Urquiza no están en la API (las opera Ferrovías/Metrovías): se muestran como "no disponible".

## 3. Features (MVP espectacular)

1. **Cercanas automáticas** — CoreLocation ordena estaciones por distancia. La más cercana arriba, con su próximo tren ya cargado.
2. **Tablero de estación** — próximos arribos, countdown grande, andén, demora con color (verde en horario / ámbar leve / rojo fuerte / gris sin dato), destino y ramal.
3. **Favoritos con contexto** — estrella una estación. La app prioriza "casa" a la mañana y "trabajo" a la tarde según hora. Haptics al marcar.
4. **Detalle de servicio + mapa en vivo** — recorrido completo, tren moviéndose por GPS en MapKit, paradas restantes, ETA por parada.
5. **Mapa de red en vivo** — todos los trenes de una línea moviéndose, con estado.
6. **Alertas** — por línea y por ramal, ordenadas por criticidad, con causa/efecto GTFS mapeados a íconos, dedup por contenido.
7. **Buscador** — por nombre (substring, sin acento), con chip de línea.
8. **Widget (home + lock) + StandBy** — próximos trenes de la favorita, countdown nativo.
9. **Live Activity + Dynamic Island** — "tu tren en X min" en pantalla bloqueada al seguir un servicio.
10. **Notificaciones de demora** — mejor esfuerzo vía BGAppRefreshTask, con el límite explicado.
11. **Onboarding** — priming de permiso de ubicación, TipKit para favoritos.
12. **Créditos** — Alan Daitch + Claude.

## 4. Diseño

Estética "departures board" moderna: fondo casi negro OLED, numerales redondeados grandes como héroe, identidad de línea por color + inicial en badge. Punto "en vivo" que pulsa. Haptics. Soporta claro y oscuro.

### Paleta de líneas (decisión editorial — la API no expone color)
- Mitre `#1E7FD4` · Sarmiento `#B83280` · Roca `#16A34A` · San Martín `#E0632B`
- Belgrano Sur `#EAB308` · Tren de la Costa `#0D9488` · Regionales/larga distancia `#7C5CFC`
- Belgrano Norte / Urquiza `#8A94A6` (no cubiertas por la API)

### Semántica
- En horario `#22C55E` · Demora leve `#F59E0B` · Demora fuerte/cancelado `#EF4444` · Sin dato `#8A94A6`
- Marca (chrome) indigo `#242C4F` (guiño al chrome real de Trenes Argentinos).
- Fondo oscuro `#0A0C10`, superficie `#151A22`, elevado `#1E242E`.

## 5. Arquitectura

SwiftUI + Observation (`@Observable`), iOS 17+. Dos targets que comparten `Shared/`.

```
Anden/            target app
  App/            AndenApp, RootView (TabView)
  Features/       Nearby, StationBoard, ServiceDetail, NetworkMap, Alerts, Favorites, Settings
  Onboarding/
  Components/     Countdown, LineBadge, DelayPill, LiveDot, cards
  Resources/      Assets.xcassets, estaciones.json, lineas.json
Shared/           compilado en app Y widget
  Models/         Codable + dominio (Arrival, Service, Station, Line, Alert, DelayStatus)
  Networking/     SofseClient, TokenProvider, endpoints, decoders (dos esquemas de fecha)
  Catalog/        StationCatalog (carga estaciones.json/lineas.json)
  Logic/          cálculo de demora, agrupación de arribos, formateo, distancia
  Store/          FavoritesStore (App Group), Settings
  Theme/          colores, paleta de línea, tipografía
  Activity/       TrainActivityAttributes (compartido con widget)
Widget/           target extensión
  AndenWidgetBundle, NextTrainWidget, TrainLiveActivity
```

Regla de datos: catálogo embebido al arrancar; arribos por polling directo sin token; alertas con token cacheado 24 h y respuesta 5 min; degradar a solo `/arribos` si falla la auth.

## 6. Firma e instalación

Apple Development personal (Team `2TBBTAN27Z`). Automatic signing. App Group `group.com.alandaitch.anden`. Sin Push Notifications capability (rompe la cuenta free). Válido 7 días; recompilar semanalmente. Instalar en iPhone 15 Pro pareado vía `devicectl`. Si la extensión bloquea el firmado del dispositivo, instalar app sola.

## 7. Plan de ejecución (agentes)

- **Foundation** (Opus): escribe `Shared/` completo + scaffold app. Fija los contratos de tipos. Compila stub.
- **Features** (Opus/Sonnet, paralelo): Nearby+Buscador, Tablero+Componentes, Detalle+Mapas, Alertas+Favoritos+Ajustes+Onboarding, Widget+LiveActivity. Cada uno solo su carpeta, contra el contrato fijo.
- **Integration** (Opus): ensambla RootView, regenera proyecto, compila para simulador, corrige hasta verde.
- Verificación en simulador (screenshots, flujos) e instalación en iPhone: las hago yo.
